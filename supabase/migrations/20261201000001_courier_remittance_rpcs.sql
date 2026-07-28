-- Migration: Courier Bulk Remittance Database RPCs
-- Creates RPCs for creating/updating batch drafts and processing multi-order bulk remittance settlement atomically.

begin;

-- 1. Function to create or update courier remittance batch and sync items
create or replace function public.create_or_update_courier_remittance_batch(
  p_batch_id bigint default null,
  p_tenant_id bigint default null,
  p_courier_service_id uuid default null,
  p_batch_no text default null,
  p_bank_trx_id text default null,
  p_payment_date date default null,
  p_gross_cod_amount numeric default 0.00,
  p_courier_charges_amount numeric default 0.00,
  p_net_deposited_amount numeric default 0.00,
  p_note text default null,
  p_items jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_batch_id bigint;
  v_tenant_id bigint;
  v_courier_id uuid;
  v_batch_no text;
  v_item jsonb;
  v_order_id bigint;
  v_invoice_id bigint;
  v_tracking text;
  v_awb text;
  v_cod numeric(12,2);
  v_charge numeric(12,2);
  v_net numeric(12,2);
  v_tot_allocated numeric(12,2) := 0.00;
  v_tot_cod numeric(12,2) := 0.00;
  v_tot_charge numeric(12,2) := 0.00;
  v_item_status text;
  v_error_msg text;
  v_batch_status text;
begin
  -- Resolve batch or new parameters
  if p_batch_id is not null then
    select tenant_id, courier_service_id, batch_no, status
      into v_tenant_id, v_courier_id, v_batch_no, v_batch_status
    from public.courier_remittance_batches
    where id = p_batch_id for update;

    if v_tenant_id is null then
      raise exception 'Remittance batch #% not found', p_batch_id;
    end if;

    if v_batch_status <> 'draft' then
      raise exception 'Cannot modify a remittance batch that is already %', v_batch_status;
    end if;
  else
    v_tenant_id := p_tenant_id;
    v_courier_id := p_courier_service_id;
    v_batch_no := nullif(trim(p_batch_no), '');
  end if;

  if v_tenant_id is null or v_courier_id is null or v_batch_no is null then
    raise exception 'Tenant ID, Courier Service ID, and Batch Number are required';
  end if;

  -- Verify permissions
  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Staff or Admin role required for tenant %', v_tenant_id;
  end if;

  -- Create or update batch header
  if p_batch_id is null then
    insert into public.courier_remittance_batches (
      tenant_id,
      courier_service_id,
      batch_no,
      bank_trx_id,
      payment_date,
      gross_cod_amount,
      courier_charges_amount,
      net_deposited_amount,
      allocated_amount,
      variance_amount,
      status,
      note,
      created_by
    )
    values (
      v_tenant_id,
      v_courier_id,
      v_batch_no,
      nullif(trim(p_bank_trx_id), ''),
      coalesce(p_payment_date, current_date),
      coalesce(p_gross_cod_amount, 0.00),
      coalesce(p_courier_charges_amount, 0.00),
      coalesce(p_net_deposited_amount, 0.00),
      0.00,
      coalesce(p_net_deposited_amount, 0.00),
      'draft',
      nullif(trim(p_note), ''),
      auth.uid()
    )
    returning id into v_batch_id;
  else
    v_batch_id := p_batch_id;
    update public.courier_remittance_batches
    set
      courier_service_id = coalesce(p_courier_service_id, courier_service_id),
      batch_no = coalesce(nullif(trim(p_batch_no), ''), batch_no),
      bank_trx_id = nullif(trim(p_bank_trx_id), ''),
      payment_date = coalesce(p_payment_date, payment_date),
      gross_cod_amount = coalesce(p_gross_cod_amount, gross_cod_amount),
      courier_charges_amount = coalesce(p_courier_charges_amount, courier_charges_amount),
      net_deposited_amount = coalesce(p_net_deposited_amount, net_deposited_amount),
      note = nullif(trim(p_note), ''),
      updated_at = now()
    where id = v_batch_id;

    -- Clear existing draft items for resync
    delete from public.courier_remittance_items where batch_id = v_batch_id;
  end if;

  -- Process line items array
  if p_items is not null and jsonb_array_length(p_items) > 0 then
    for v_item in select * from jsonb_array_elements(p_items)
    loop
      v_order_id := (v_item->>'shop_order_id')::bigint;
      v_invoice_id := (v_item->>'global_invoice_id')::bigint;
      v_tracking := nullif(trim(v_item->>'tracking_number'), '');
      v_awb := nullif(trim(v_item->>'awb_number'), '');
      v_cod := coalesce((v_item->>'cod_collected_amount')::numeric, 0.00);
      v_charge := coalesce((v_item->>'courier_charge_amount')::numeric, 0.00);
      v_net := coalesce((v_item->>'net_remitted_amount')::numeric, (v_cod - v_charge));

      v_item_status := 'matched';
      v_error_msg := null;

      -- Validate order if provided
      if v_order_id is not null then
        select global_invoice_id, tracking_number, awb_number
          into v_invoice_id, v_tracking, v_awb
        from public.shop_orders
        where id = v_order_id and tenant_id = v_tenant_id;

        if not found then
          v_item_status := 'unmatched';
          v_error_msg := 'Order not found in tenant';
        end if;
      end if;

      insert into public.courier_remittance_items (
        tenant_id,
        batch_id,
        shop_order_id,
        global_invoice_id,
        tracking_number,
        awb_number,
        cod_collected_amount,
        courier_charge_amount,
        net_remitted_amount,
        status,
        error_message
      )
      values (
        v_tenant_id,
        v_batch_id,
        v_order_id,
        v_invoice_id,
        v_tracking,
        v_awb,
        v_cod,
        v_charge,
        v_net,
        v_item_status,
        v_error_msg
      );

      v_tot_allocated := v_tot_allocated + v_net;
      v_tot_cod := v_tot_cod + v_cod;
      v_tot_charge := v_tot_charge + v_charge;
    end loop;
  end if;

  -- Recalculate batch totals and variance
  update public.courier_remittance_batches
  set
    allocated_amount = v_tot_allocated,
    gross_cod_amount = case when p_gross_cod_amount = 0 and v_tot_cod > 0 then v_tot_cod else gross_cod_amount end,
    courier_charges_amount = case when p_courier_charges_amount = 0 and v_tot_charge > 0 then v_tot_charge else courier_charges_amount end,
    variance_amount = net_deposited_amount - v_tot_allocated,
    updated_at = now()
  where id = v_batch_id;

  return jsonb_build_object(
    'success', true,
    'batch_id', v_batch_id,
    'allocated_amount', v_tot_allocated,
    'variance_amount', (coalesce(p_net_deposited_amount, 0.00) - v_tot_allocated)
  );
end;
$$;

grant execute on function public.create_or_update_courier_remittance_batch(
  bigint, bigint, uuid, text, text, date, numeric, numeric, numeric, text, jsonb
) to authenticated;


-- 2. Function to process and execute bulk remittance settlement atomically
create or replace function public.process_courier_bulk_remittance_batch(
  p_batch_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
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
    select * into v_invoice from public.global_invoices
    where id = v_order.global_invoice_id for update;

    if v_invoice.id is null then
      update public.courier_remittance_items
      set status = 'error', error_message = 'Global invoice not found'
      where id = v_item.id;
      v_error_count := v_error_count + 1;
      continue;
    end if;

    -- Create global payment record
    insert into public.global_payments (
      tenant_id,
      billing_profile_id,
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
      v_invoice.billing_profile_id,
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
    insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
    values (v_batch.tenant_id, v_payment_id, v_order.global_invoice_id, v_net_remitted);

    -- Update invoice paid amount
    update public.global_invoices
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
$$;

grant execute on function public.process_courier_bulk_remittance_batch(bigint) to authenticated;

commit;
