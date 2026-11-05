CREATE FUNCTION public.process_courier_bulk_remittance_batch (
  p_batch_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_batch record;
  v_item record;
  v_order record;
  v_invoice record;
  v_payment_id bigint;
  v_processed_count integer := 0;
  v_error_count integer := 0;
  v_net_remitted numeric(12,2);
  v_total_allocated numeric(12,2) := 0.00;
begin
  -- Lock batch record
  select * into v_batch
  from public.courier_remittance_batches
  where id = p_batch_id for update;

  if v_batch.id is null then
    raise exception 'Remittance batch #% not found', p_batch_id;
  end if;

  if v_batch.status <> 'draft' then
    raise exception 'Batch #% is already %', v_batch.batch_no, v_batch.status;
  end if;

  -- Permission check
  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_batch.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Staff or Admin role required for tenant %', v_batch.tenant_id;
  end if;

  -- Process line items sequentially
  for v_item in
    select * from public.courier_remittance_items
    where batch_id = p_batch_id
    for update
  loop
    v_net_remitted := v_item.net_remitted_amount;

    -- Validate order
    if v_item.shop_order_id is null then
      update public.courier_remittance_items
      set status = 'error', error_message = 'Missing linked order'
      where id = v_item.id;
      v_error_count := v_error_count + 1;
      continue;
    end if;

    select * into v_order from public.shop_orders
    where id = v_item.shop_order_id for update;

    if v_order.id is null then
      update public.courier_remittance_items
      set status = 'error', error_message = 'Shop order record not found'
      where id = v_item.id;
      v_error_count := v_error_count + 1;
      continue;
    end if;

    if v_order.status <> 'delivered' then
      update public.courier_remittance_items
      set status = 'error', error_message = 'Order is not in delivered status (current: ' || v_order.status || ')'
      where id = v_item.id;
      v_error_count := v_error_count + 1;
      continue;
    end if;

    if v_order.global_invoice_id is null then
      update public.courier_remittance_items
      set status = 'error', error_message = 'Missing accounting global invoice'
      where id = v_item.id;
      v_error_count := v_error_count + 1;
      continue;
    end if;

    -- Lock & validate global invoice
    select * into v_invoice from public.bills
    where id = v_order.global_invoice_id for update;

    if v_invoice.id is null then
      update public.courier_remittance_items
      set status = 'error', error_message = 'Global invoice not found'
      where id = v_item.id;
      v_error_count := v_error_count + 1;
      continue;
    end if;

    -- Create global payment record
    insert into public.pays (
      tenant_id,
      profile_id,
      collection_source,
      amount,
      unallocated_amount,
      payment_date,
      method,
      reference,
      note
    )
    values (
      v_batch.tenant_id,
      v_invoice.profile_id,
      v_invoice.collection_source,
      v_net_remitted,
      0.00,
      coalesce(v_batch.payment_date, current_date),
      'bank_transfer',
      v_batch.batch_no,
      'Courier remittance batch #' || v_batch.batch_no || ' order #' || v_order.order_no
    )
    returning id into v_payment_id;

    -- Insert invoice payment allocation
    insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, amount)
    values (v_batch.tenant_id, v_payment_id, v_order.global_invoice_id, v_net_remitted);

    -- Update invoice paid amount
    update public.bills
    set
      paid_amount = coalesce(paid_amount, 0.00) + v_net_remitted,
      updated_at = now()
    where id = v_order.global_invoice_id;

    -- Recompute payment status
    perform public.recompute_global_invoice_payment_status(v_order.global_invoice_id);

    -- Update order status to payment_received & stamp references
    update public.shop_orders
    set
      status = 'payment_received'::public.shop_order_status,
      courier_remittance_ref = v_batch.batch_no,
      courier_bank_trx_id = coalesce(v_batch.bank_trx_id, courier_bank_trx_id),
      updated_at = now()
    where id = v_order.id;

    -- Mark item as processed
    update public.courier_remittance_items
    set
      status = 'processed',
      error_message = null,
      global_invoice_id = v_order.global_invoice_id
    where id = v_item.id;

    v_processed_count := v_processed_count + 1;
    v_total_allocated := v_total_allocated + v_net_remitted;
  end loop;

  -- Mark batch header as posted if no fatal block
  update public.courier_remittance_batches
  set
    status = 'posted',
    allocated_amount = v_total_allocated,
    variance_amount = net_deposited_amount - v_total_allocated,
    posted_at = now(),
    posted_by = auth.uid(),
    updated_at = now()
  where id = p_batch_id;

  return jsonb_build_object(
    'success', true,
    'batch_id', p_batch_id,
    'processed_count', v_processed_count,
    'error_count', v_error_count,
    'allocated_amount', v_total_allocated,
    'status', 'posted'
  );
end;
$function$;

GRANT ALL ON FUNCTION public.process_courier_bulk_remittance_batch(bigint) TO anon;

GRANT ALL ON FUNCTION public.process_courier_bulk_remittance_batch(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.process_courier_bulk_remittance_batch(bigint) TO service_role;