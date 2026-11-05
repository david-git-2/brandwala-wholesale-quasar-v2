CREATE FUNCTION public.receive_shop_customer_stock (
  p_shop_id           bigint,
  p_customer_group_id bigint,
  p_quantity          integer,
  p_product_id        bigint  DEFAULT NULL::bigint,
  p_item_label        text    DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_shop public.shops%rowtype;
  v_row public.shop_customer_stocks%rowtype;
  v_label text;
  v_product_id bigint;
begin
  if p_quantity is null or p_quantity <= 0 then
    return jsonb_build_object('success', false, 'error', 'quantity must be positive');
  end if;

  if p_customer_group_id is null then
    return jsonb_build_object('success', false, 'error', 'customer_group_id required');
  end if;

  if p_product_id is null and (p_item_label is null or length(trim(p_item_label)) = 0) then
    return jsonb_build_object('success', false, 'error', 'product or item name required');
  end if;

  select * into v_shop from public.shops where id = p_shop_id for update;
  if v_shop.id is null then
    return jsonb_build_object('success', false, 'error', 'shop not found');
  end if;

  if not public.is_tenant_staff(v_shop.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  if not exists (
    select 1
    from public.shop_customer_group_access scga
    where scga.shop_id = p_shop_id
      and scga.customer_group_id = p_customer_group_id
  ) then
    return jsonb_build_object('success', false, 'error', 'customer does not have shop access');
  end if;

  v_product_id := p_product_id;
  v_label := nullif(trim(p_item_label), '');

  if v_product_id is not null then
    if not exists (select 1 from public.products where id = v_product_id) then
      return jsonb_build_object('success', false, 'error', 'product not found');
    end if;

    select * into v_row
    from public.shop_customer_stocks
    where shop_id = p_shop_id
      and customer_group_id = p_customer_group_id
      and product_id = v_product_id
    for update;

    if v_row.id is null then
      insert into public.shop_customer_stocks (
        tenant_id, shop_id, customer_group_id, product_id, item_label, quantity_on_hand
      )
      values (v_shop.tenant_id, p_shop_id, p_customer_group_id, v_product_id, null, p_quantity)
      returning * into v_row;
    else
      update public.shop_customer_stocks
      set
        quantity_on_hand = v_row.quantity_on_hand + p_quantity,
        updated_at = now()
      where id = v_row.id
      returning * into v_row;
    end if;
  else
    select * into v_row
    from public.shop_customer_stocks
    where shop_id = p_shop_id
      and customer_group_id = p_customer_group_id
      and product_id is null
      and lower(trim(item_label)) = lower(v_label)
    for update;

    if v_row.id is null then
      insert into public.shop_customer_stocks (
        tenant_id, shop_id, customer_group_id, product_id, item_label, quantity_on_hand
      )
      values (v_shop.tenant_id, p_shop_id, p_customer_group_id, null, v_label, p_quantity)
      returning * into v_row;
    else
      update public.shop_customer_stocks
      set
        quantity_on_hand = v_row.quantity_on_hand + p_quantity,
        updated_at = now()
      where id = v_row.id
      returning * into v_row;
    end if;
  end if;

  return jsonb_build_object(
    'success', true,
    'row', jsonb_build_object(
      'id', v_row.id,
      'product_id', v_row.product_id,
      'item_label', v_row.item_label,
      'quantity_on_hand', v_row.quantity_on_hand
    )
  );
end;
$function$;

GRANT ALL ON FUNCTION public.receive_shop_customer_stock(bigint, bigint, integer, bigint, text) TO anon;

GRANT ALL ON FUNCTION public.receive_shop_customer_stock(bigint, bigint, integer, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.receive_shop_customer_stock(bigint, bigint, integer, bigint, text) TO service_role;