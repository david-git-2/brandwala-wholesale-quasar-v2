CREATE FUNCTION public.add_dropship_order_gift_item (
  p_order_id               bigint,
  p_product_id             bigint,
  p_quantity               integer,
  p_gift_source            text,
  p_gift_cost_amount       numeric DEFAULT 0,
  p_gift_cost_charged_to   text    DEFAULT NULL::text,
  p_gift_added_by          text    DEFAULT 'manual'::text,
  p_shop_customer_stock_id bigint  DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders%rowtype;
  v_product public.products%rowtype;
  v_cust_stock public.shop_customer_stocks%rowtype;
  v_item_id bigint;
  v_cost numeric(12,4);
  v_charged_to text;
  v_item_name text;
  v_item_image text;
begin
  if p_quantity is null or p_quantity <= 0 then
    return jsonb_build_object('success', false, 'error', 'quantity must be positive');
  end if;

  if p_gift_source not in ('stock', 'customer_stock') then
    return jsonb_build_object('success', false, 'error', 'invalid gift_source');
  end if;

  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'not a dropship order');
  end if;

  if v_order.status <> 'processing'::public.shop_order_status then
    return jsonb_build_object('success', false, 'error', 'gifts can only be added while processing');
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  v_cost := coalesce(p_gift_cost_amount, 0);
  v_charged_to := p_gift_cost_charged_to;

  if p_gift_source = 'customer_stock' then
    v_cost := 0;
    v_charged_to := null;

    if p_shop_customer_stock_id is not null then
      select * into v_cust_stock
      from public.shop_customer_stocks
      where id = p_shop_customer_stock_id
        and shop_id = v_order.shop_id
      for update;
    else
      if p_product_id is null then
        return jsonb_build_object('success', false, 'error', 'product_id or shop_customer_stock_id required');
      end if;

      select * into v_product from public.products where id = p_product_id;
      if v_product.id is null then
        return jsonb_build_object('success', false, 'error', 'product not found');
      end if;

      select * into v_cust_stock
      from public.shop_customer_stocks
      where shop_id = v_order.shop_id
        and customer_group_id = v_order.customer_group_id
        and product_id = p_product_id
      for update;
    end if;

    if v_cust_stock.id is null or v_cust_stock.quantity_on_hand < p_quantity then
      return jsonb_build_object('success', false, 'error', 'insufficient customer stock for this product');
    end if;

    if v_cust_stock.customer_group_id is distinct from v_order.customer_group_id then
      return jsonb_build_object('success', false, 'error', 'customer stock does not belong to this order reseller');
    end if;

    update public.shop_customer_stocks
    set quantity_on_hand = quantity_on_hand - p_quantity, updated_at = now()
    where id = v_cust_stock.id;

    if v_cust_stock.product_id is not null then
      select * into v_product from public.products where id = v_cust_stock.product_id;
      v_item_name := v_product.name;
      v_item_image := v_product.image_url;
    else
      v_item_name := coalesce(v_cust_stock.item_label, 'Gift item');
      v_item_image := null;
    end if;

    insert into public.shop_order_items (
      order_id, product_id, name, image_url, quantity,
      unit_sell_price_amount, final_price_amount, customer_sell_price_amount,
      is_gift, gift_source, gift_cost_amount, gift_cost_charged_to,
      shop_customer_stock_id, gift_added_by, confirmed_quantity
    )
    values (
      p_order_id, v_cust_stock.product_id, v_item_name, v_item_image, p_quantity,
      0, 0, 0,
      true, 'customer_stock', 0, null,
      v_cust_stock.id, coalesce(p_gift_added_by, 'manual'), p_quantity
    )
    returning id into v_item_id;

  else
    select * into v_product from public.products where id = p_product_id;
    if v_product.id is null then
      return jsonb_build_object('success', false, 'error', 'product not found');
    end if;

    if v_cost > 0 and v_charged_to is null then
      return jsonb_build_object('success', false, 'error', 'gift_cost_charged_to required when cost > 0');
    end if;
    if v_cost <= 0 then
      v_charged_to := null;
    end if;
    if v_charged_to is not null and v_charged_to not in ('reseller', 'tenant') then
      return jsonb_build_object('success', false, 'error', 'invalid gift_cost_charged_to');
    end if;

    insert into public.shop_order_items (
      order_id, product_id, name, image_url, quantity,
      unit_sell_price_amount, final_price_amount, customer_sell_price_amount,
      is_gift, gift_source, gift_cost_amount, gift_cost_charged_to,
      shop_customer_stock_id, gift_added_by, confirmed_quantity
    )
    values (
      p_order_id, p_product_id, v_product.name, v_product.image_url, p_quantity,
      0, 0, 0,
      true, 'stock', v_cost, v_charged_to,
      null, coalesce(p_gift_added_by, 'manual'), 0
    )
    returning id into v_item_id;
  end if;

  perform public.recompute_dropship_cod_collect_amount(v_order.id);

  return jsonb_build_object('success', true, 'order_item_id', v_item_id);
end;
$function$;

GRANT ALL ON FUNCTION public.add_dropship_order_gift_item(bigint, bigint, integer, text, numeric, text, text, bigint) TO anon;

GRANT ALL ON FUNCTION public.add_dropship_order_gift_item(bigint, bigint, integer, text, numeric, text, text, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.add_dropship_order_gift_item(bigint, bigint, integer, text, numeric, text, text, bigint) TO service_role;