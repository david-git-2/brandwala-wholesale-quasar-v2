CREATE FUNCTION public.fulfill_shop_order_to_invoice (
  p_order_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders;
  v_invoice_type public.global_invoice_type;
  v_retail_billing_mode public.retail_billing_mode;
  v_invoice_no text;
  v_item record;
  v_items jsonb := '[]'::jsonb;
  v_payload jsonb;
  v_result jsonb;
  v_invoice_id bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;

  if v_order.id is null then
    raise exception 'order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status = 'fulfilled' and v_order.global_invoice_id is not null then
    return;
  end if;

  if v_order.status <> 'confirmed' then
    raise exception 'only confirmed orders can be fulfilled to an invoice';
  end if;

  if v_order.shop_type_snapshot = 'vendor_catalog' then
    raise exception 'vendor catalog orders cannot be fulfilled to an invoice directly';
  end if;

  if v_order.shop_type_snapshot = 'fixed_price' then
    raise exception 'stock-backed catalog orders must close on Delivery paper (take / condition / return), not fulfill_shop_order_to_invoice';
  end if;

  if v_order.shop_type_snapshot = 'dropship' then
    raise exception 'dropship orders must use ship_dropship_order_and_issue_merchant_bill';
  end if;

  if exists (
    select 1
    from public.bills si
    where si.shop_order_id = p_order_id
  ) then
    raise exception 'order already has a linked sales invoice';
  end if;

  if v_order.order_mode_snapshot = 'checkout_wholesale' then
    v_invoice_type := 'wholesale'::public.global_invoice_type;
    v_retail_billing_mode := null;
    if v_order.profile_id is null then
      raise exception 'billing profile is required for wholesale shop orders';
    end if;
  else
    v_invoice_type := 'retail'::public.global_invoice_type;
    if v_order.profile_id is not null then
      v_retail_billing_mode := 'account'::public.retail_billing_mode;
    else
      v_retail_billing_mode := 'direct'::public.retail_billing_mode;
    end if;
  end if;

  v_invoice_no := 'INV-SO-' || v_order.order_no;

  for v_item in
    select *
    from public.shop_order_items
    where order_id = p_order_id
      and coalesce(is_fulfillment_unavailable, false) = false
      and quantity > 0
  loop
    if v_item.global_stock_id is null then
      raise exception 'item % is missing global_stock_id association', v_item.name;
    end if;

    v_items := v_items || jsonb_build_array(
      jsonb_build_object(
        'global_stock_id', v_item.global_stock_id,
        'quantity', v_item.quantity::numeric,
        'sell_price_amount', coalesce(
          v_item.final_price_amount,
          v_item.unit_sell_price_amount,
          v_item.unit_list_price_amount
        ),
        'line_discount_amount', 0,
        'line_meta', case
          when v_item.customer_sell_price_amount is not null then
            jsonb_build_object('resell_price_amount', v_item.customer_sell_price_amount)
          else '{}'::jsonb
        end
      )
    );
  end loop;

  if jsonb_array_length(v_items) = 0 then
    raise exception 'order has no fulfillable line items';
  end if;

  v_payload := jsonb_build_object(
    'invoice', jsonb_build_object(
      'invoice_no', v_invoice_no,
      'invoice_type', v_invoice_type,
      'profile_id', v_order.profile_id,
      'recipient_name', v_order.recipient_name,
      'recipient_phone', v_order.recipient_phone,
      'recipient_address', v_order.shipping_address,
      'retail_billing_mode', v_retail_billing_mode,
      'discount_amount', coalesce(v_order.discount_amount, 0),
      'shipping_charge', coalesce(v_order.delivery_charge_amount, 0),
      'print_charge', coalesce(v_order.print_charge_amount, 0),
      'wrapping_charge', coalesce(v_order.packing_charge_amount, 0),
      'note', coalesce(v_order.delivery_instructions, 'Fulfillment of Shop Order: ' || v_order.order_no)
    ),
    'items', v_items,
    'issue', true
  );

  v_result := public.create_sales_invoice_from_payload(v_order.tenant_id, v_payload);

  if coalesce(v_result->>'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_result->>'error', 'failed to fulfill shop order to invoice');
  end if;

  v_invoice_id := (v_result->>'invoice_id')::bigint;

  update public.bills
  set
    shop_order_id = p_order_id,
    collection_source = 'profile'::public.collection_source_type,
    updated_at = now()
  where id = v_invoice_id;

  update public.shop_orders
  set
    status = 'fulfilled',
    global_invoice_id = v_invoice_id,
    fulfilled_at = now(),
    updated_at = now()
  where id = p_order_id;
end;
$function$;

GRANT ALL ON FUNCTION public.fulfill_shop_order_to_invoice(bigint) TO anon;

GRANT ALL ON FUNCTION public.fulfill_shop_order_to_invoice(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.fulfill_shop_order_to_invoice(bigint) TO service_role;