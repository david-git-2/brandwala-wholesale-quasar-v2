CREATE FUNCTION public.advance_dropship_order_status (
  p_order_id       bigint,
  p_target_status  public.shop_order_status,
  p_remittance_ref text                     DEFAULT NULL::text,
  p_bank_trx_id    text                     DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders;
  v_invoice public.bills;
  v_current_status public.shop_order_status;
  v_is_valid boolean := false;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'Order is not a dropship order');
  end if;

  v_current_status := v_order.status;

  if v_current_status = p_target_status then
    return jsonb_build_object('success', true, 'message', 'Status unchanged', 'new_status', p_target_status);
  end if;

  if p_target_status in ('shipped'::public.shop_order_status, 'delivered'::public.shop_order_status) then
    return jsonb_build_object(
      'success', false,
      'error', format(
        'Use ship_dropship_order_and_issue_merchant_bill or mark_dropship_order_delivered instead of advance to %s',
        p_target_status
      )
    );
  end if;

  if v_current_status in ('submitted', 'draft', 'placed', 'confirmed')
     and p_target_status in ('processing', 'cancelled') then
    v_is_valid := true;
  elsif v_current_status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received') then
    if p_target_status in (
      'processing', 'ready_for_pickup', 'returned', 'payment_received', 'cancelled'
    ) then
      v_is_valid := true;
    end if;
  end if;

  if not v_is_valid then
    return jsonb_build_object(
      'success', false,
      'error', format(
        'Invalid status transition for dropship order from %s to %s',
        v_current_status,
        p_target_status
      )
    );
  end if;

  if p_target_status = 'processing' and v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id;
    if v_invoice.payment_status in ('paid', 'partially_paid') then
      return jsonb_build_object(
        'success', false,
        'error', 'Cannot rollback: merchant bill has payments allocated'
      );
    end if;
  end if;

  if p_target_status = 'processing'::public.shop_order_status
     and v_current_status = 'confirmed'::public.shop_order_status
     and v_order.recipient_verified_at is null then
    return jsonb_build_object(
      'success', false,
      'error', 'Recipient must confirm by phone before processing'
    );
  end if;

  update public.shop_orders
  set
    status = p_target_status,
    courier_remittance_ref = coalesce(p_remittance_ref, courier_remittance_ref),
    courier_bank_trx_id = coalesce(p_bank_trx_id, courier_bank_trx_id),
    updated_at = now()
  where id = p_order_id;

  select * into v_order from public.shop_orders where id = p_order_id;

  if p_target_status = 'cancelled' then
    perform public.release_dropship_order_stock(p_order_id, true);
  end if;

  if p_target_status = 'processing' and v_order.global_invoice_id is not null then
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

    update public.shop_orders
    set global_invoice_id = null, updated_at = now()
    where id = p_order_id;

    delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
    delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
    delete from public.bills where id = v_order.global_invoice_id;
  end if;

  if p_target_status = 'processing'::public.shop_order_status then
    perform public.apply_shop_auto_gift_items(p_order_id);
  end if;

  return jsonb_build_object('success', true, 'new_status', p_target_status);
end;
$function$;

GRANT ALL ON FUNCTION public.advance_dropship_order_status(bigint, public.shop_order_status, text, text) TO anon;

GRANT ALL ON FUNCTION public.advance_dropship_order_status(bigint, public.shop_order_status, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.advance_dropship_order_status(bigint, public.shop_order_status, text, text) TO service_role;