-- Dropship recipient confirmation call (US-4)

alter table public.shop_orders
  add column if not exists recipient_call_attempt_count integer not null default 0,
  add column if not exists recipient_verified_at timestamp with time zone,
  add column if not exists cancel_reason text;

-- advance_dropship_order_status: gate confirmed -> processing
create or replace function public.advance_dropship_order_status(
  p_order_id bigint,
  p_target_status public.shop_order_status,
  p_remittance_ref text default null,
  p_bank_trx_id text default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
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

  return jsonb_build_object('success', true, 'new_status', p_target_status);
end;
$function$;

create or replace function public.record_dropship_recipient_call_no_answer(p_order_id bigint)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_order public.shop_orders%rowtype;
  v_new_count integer;
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

  if v_order.status <> 'confirmed'::public.shop_order_status then
    return jsonb_build_object(
      'success', false,
      'error', format('order must be confirmed to log a call attempt (current: %s)', v_order.status)
    );
  end if;

  update public.shop_orders
  set
    recipient_call_attempt_count = coalesce(recipient_call_attempt_count, 0) + 1,
    updated_at = now()
  where id = p_order_id
  returning recipient_call_attempt_count into v_new_count;

  return jsonb_build_object(
    'success', true,
    'recipient_call_attempt_count', v_new_count
  );
end;
$function$;

create or replace function public.confirm_dropship_recipient_call(p_order_id bigint)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_order public.shop_orders%rowtype;
  v_advance jsonb;
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

  if v_order.status <> 'confirmed'::public.shop_order_status then
    return jsonb_build_object(
      'success', false,
      'error', format('order must be confirmed to verify recipient (current: %s)', v_order.status)
    );
  end if;

  if v_order.recipient_verified_at is not null then
    v_advance := public.advance_dropship_order_status(p_order_id, 'processing'::public.shop_order_status);
    return v_advance;
  end if;

  update public.shop_orders
  set recipient_verified_at = now(), updated_at = now()
  where id = p_order_id;

  v_advance := public.advance_dropship_order_status(p_order_id, 'processing'::public.shop_order_status);
  return v_advance;
end;
$function$;

grant execute on function public.record_dropship_recipient_call_no_answer(bigint) to authenticated;
grant execute on function public.confirm_dropship_recipient_call(bigint) to authenticated;

-- cancel_shop_order_dropship: persist cancel_reason
create or replace function public.cancel_shop_order_dropship(p_order_id bigint, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
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
