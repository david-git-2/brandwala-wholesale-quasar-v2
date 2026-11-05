CREATE FUNCTION public.cancel_shop_order_dropship (
  p_order_id bigint,
  p_reason   text   DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders%rowtype;
  v_invoice public.bills%rowtype;
  v_allowed boolean := false;
  v_pick_count integer := 0;
  v_released_picks integer := 0;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'not a dropship order');
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  v_allowed := v_order.status in (
    'submitted', 'draft', 'placed', 'confirmed', 'processing', 'ready_for_pickup'
  );

  if not v_allowed then
    return jsonb_build_object(
      'success', false,
      'error', format('cannot cancel order in status %s', v_order.status)
    );
  end if;

  select count(*) into v_pick_count
  from public.shop_order_item_stock_picks where order_id = p_order_id;

  if v_order.status = 'ready_for_pickup' and v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id;
    if v_invoice.invoice_status = 'issued'::public.global_invoice_status then
      perform public.unpost_global_invoice(v_order.global_invoice_id);
    end if;

    delete from public.cashbook_entries
    where source_type = 'shop_order'
      and (
        source_id = p_order_id::text
        or source_id = v_order.order_no
        or source_id = v_invoice.invoice_no
      )
      and tenant_id = v_order.tenant_id;

    delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
    delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
    delete from public.bills where id = v_order.global_invoice_id;

    update public.shop_orders
    set global_invoice_id = null, updated_at = now()
    where id = p_order_id;
  elsif v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id;
    if v_invoice.invoice_status in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
      delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
      delete from public.bills where id = v_order.global_invoice_id;
      update public.shop_orders set global_invoice_id = null, updated_at = now() where id = p_order_id;
    end if;
  end if;

  perform public.release_dropship_order_stock(p_order_id, true);
  v_released_picks := v_pick_count;

  delete from public.shop_order_item_stock_picks where order_id = p_order_id;

  update public.shop_order_items
  set
    is_fulfillment_unavailable = false,
    unavailable_reason = null,
    unavailable_at = null,
    unavailable_by_email = null,
    confirmed_quantity = 0,
    global_stock_id = null,
    updated_at = now()
  where order_id = p_order_id;

  update public.shop_orders
  set
    status = 'cancelled'::public.shop_order_status,
    cancel_reason = nullif(trim(p_reason), ''),
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'new_status', 'cancelled',
    'cancel_reason', nullif(trim(p_reason), ''),
    'restock_summary', jsonb_build_object(
      'pick_rows_released', v_released_picks,
      'reason', nullif(trim(p_reason), '')
    )
  );
end;
$function$;

GRANT ALL ON FUNCTION public.cancel_shop_order_dropship(bigint, text) TO anon;

GRANT ALL ON FUNCTION public.cancel_shop_order_dropship(bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.cancel_shop_order_dropship(bigint, text) TO service_role;