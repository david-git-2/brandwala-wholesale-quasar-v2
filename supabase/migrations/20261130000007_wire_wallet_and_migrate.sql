-- Migration: Wire unified billing profile wallet ledger RPCs and migrate existing data
-- Phase 4 of Unified Billing Profile Wallet Refactor

begin;

-- ============================================================================
-- 1. Helper function: Record entry into billing_profile_wallet_ledger
-- ============================================================================
create or replace function public.record_wallet_ledger_entry(
  p_tenant_id bigint,
  p_billing_profile_id bigint,
  p_transaction_type text,
  p_amount numeric,
  p_reference_id text default null,
  p_shop_order_id bigint default null,
  p_global_invoice_id bigint default null,
  p_reference_notes text default null,
  p_created_by uuid default null
)
returns public.billing_profile_wallet_ledger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_prev_balance numeric(12,2) := 0.00;
  v_new_balance numeric(12,2) := 0.00;
  v_entry public.billing_profile_wallet_ledger;
begin
  if p_tenant_id is null or p_billing_profile_id is null then
    raise exception 'Tenant ID and Billing Profile ID are required';
  end if;

  if coalesce(p_amount, 0) < 0 then
    raise exception 'Amount cannot be negative';
  end if;

  -- Lock latest ledger entry for running balance calculation
  select balance_after into v_prev_balance
  from public.billing_profile_wallet_ledger
  where tenant_id = p_tenant_id
    and billing_profile_id = p_billing_profile_id
  order by created_at desc, id desc
  limit 1
  for update;

  v_prev_balance := coalesce(v_prev_balance, 0.00);

  -- Calculate running balance based on transaction type
  case p_transaction_type
    when 'payment_received', 'dropship_profit' then
      v_new_balance := v_prev_balance + p_amount;
    when 'invoice_billed', 'dropship_return_fee', 'payout_paid' then
      v_new_balance := v_prev_balance - p_amount;
    when 'adjustment' then
      v_new_balance := v_prev_balance + p_amount;
    else
      raise exception 'Unknown transaction type %', p_transaction_type;
  end case;

  insert into public.billing_profile_wallet_ledger (
    tenant_id,
    billing_profile_id,
    transaction_type,
    amount,
    balance_after,
    reference_id,
    shop_order_id,
    global_invoice_id,
    reference_notes,
    created_by
  )
  values (
    p_tenant_id,
    p_billing_profile_id,
    p_transaction_type,
    p_amount,
    v_new_balance,
    p_reference_id,
    p_shop_order_id,
    p_global_invoice_id,
    p_reference_notes,
    p_created_by
  )
  returning * into v_entry;

  return v_entry;
end;
$$;

grant execute on function public.record_wallet_ledger_entry to authenticated;
grant execute on function public.record_wallet_ledger_entry to service_role;

-- ============================================================================
-- 2. create_bulk_wallet_payout RPC
-- Atomic RPC for payout creation with running balance calculation
-- ============================================================================
create or replace function public.create_bulk_wallet_payout(
  p_tenant_id bigint,
  p_billing_profile_id bigint,
  p_amount numeric,
  p_reference_notes text default 'Bulk wallet payout',
  p_created_by uuid default null
)
returns public.billing_profile_wallet_ledger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile record;
  v_entry public.billing_profile_wallet_ledger;
begin
  if p_tenant_id is null or p_billing_profile_id is null then
    raise exception 'Tenant ID and Billing Profile ID are required';
  end if;

  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Payout amount must be greater than zero';
  end if;

  select * into v_profile
  from public.billing_profiles
  where id = p_billing_profile_id and tenant_id = p_tenant_id;

  if v_profile.id is null then
    raise exception 'Billing profile not found';
  end if;

  v_entry := public.record_wallet_ledger_entry(
    p_tenant_id => p_tenant_id,
    p_billing_profile_id => p_billing_profile_id,
    p_transaction_type => 'payout_paid',
    p_amount => p_amount,
    p_reference_notes => coalesce(p_reference_notes, 'Bulk wallet payout'),
    p_created_by => coalesce(p_created_by, auth.uid())
  );

  return v_entry;
end;
$$;

grant execute on function public.create_bulk_wallet_payout to authenticated;
grant execute on function public.create_bulk_wallet_payout to service_role;

-- ============================================================================
-- 3. Redefine post_global_invoice to book 'invoice_billed' debit to wallet
-- ============================================================================
create or replace function public.post_global_invoice(
  p_invoice_id bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_item public.global_invoice_items%rowtype;
  v_unit_cost numeric;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'only draft invoices can be posted';
  end if;

  if not exists (select 1 from public.global_invoice_items where invoice_id = p_invoice_id) then
    raise exception 'cannot post an empty invoice';
  end if;

  -- Validate required fields and profiles per invoice type
  if v_invoice.invoice_type = 'wholesale'::public.global_invoice_type then
    if v_invoice.billing_profile_id is null then
      raise exception 'billing profile is required for wholesale invoices';
    end if;
    if v_invoice.cod_charge > 0 or v_invoice.wrapping_charge > 0 or v_invoice.print_charge > 0 then
      raise exception 'wholesale invoices only support shipping charges';
    end if;
  elsif v_invoice.invoice_type = 'retail'::public.global_invoice_type then
    if v_invoice.retail_billing_mode = 'account'::public.retail_billing_mode then
      if v_invoice.billing_profile_id is null then
        raise exception 'billing profile is required for retail account invoices';
      end if;
    elsif v_invoice.retail_billing_mode = 'direct'::public.retail_billing_mode then
      if v_invoice.billing_profile_id is not null then
        raise exception 'billing profile must be null for retail direct invoices';
      end if;
    end if;
    if nullif(trim(v_invoice.recipient_name), '') is null or
       nullif(trim(v_invoice.recipient_phone), '') is null or
       nullif(trim(v_invoice.recipient_address), '') is null then
      raise exception 'recipient name, phone, and address are required for retail invoices';
    end if;
  elsif v_invoice.invoice_type = 'dropship'::public.global_invoice_type then
    if v_invoice.billing_profile_id is null then
      raise exception 'billing profile is required for dropship invoices';
    end if;
    if nullif(trim(v_invoice.recipient_name), '') is null or
       nullif(trim(v_invoice.recipient_phone), '') is null or
       nullif(trim(v_invoice.recipient_address), '') is null then
      raise exception 'recipient name, phone, and address are required for dropship invoices';
    end if;
  end if;

  -- Process line items: snapshot unit cost only
  for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
    v_unit_cost := public.calculate_landed_unit_cost(v_item.shipment_item_id);
    
    update public.global_invoice_items
    set unit_cost_price = v_unit_cost
    where id = v_item.id;
  end loop;

  -- Mark invoice as posted
  update public.global_invoices
  set invoice_status = 'posted'::public.global_invoice_status
  where id = p_invoice_id;

  -- Record wallet ledger entry (invoice_billed debit) if attached to a billing profile
  if v_invoice.billing_profile_id is not null and v_invoice.total_amount > 0 then
    if not exists (
      select 1 from public.billing_profile_wallet_ledger
      where global_invoice_id = p_invoice_id
        and transaction_type = 'invoice_billed'
    ) then
      perform public.record_wallet_ledger_entry(
        p_tenant_id => v_invoice.tenant_id,
        p_billing_profile_id => v_invoice.billing_profile_id,
        p_transaction_type => 'invoice_billed',
        p_amount => v_invoice.total_amount,
        p_reference_id => v_invoice.invoice_no,
        p_global_invoice_id => v_invoice.id,
        p_reference_notes => 'Invoice billed: ' || v_invoice.invoice_no
      );
    end if;
  end if;
end;
$$;

grant execute on function public.post_global_invoice(bigint) to authenticated;

-- ============================================================================
-- 4. Redefine create_billing_profile_payment_with_allocations to book 'payment_received' credit
-- ============================================================================
create or replace function public.create_billing_profile_payment_with_allocations(
  p_tenant_id bigint,
  p_billing_profile_id bigint,
  p_amount numeric,
  p_payment_date date,
  p_method text,
  p_reference text,
  p_note text,
  p_allocations jsonb
)
returns public.global_payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment public.global_payments;
  v_alloc jsonb;
  v_global_invoice_id bigint;
  v_commerce_invoice_id bigint;
  v_legacy_invoice_id bigint;
  v_alloc_amount numeric(12,2);
  v_total_alloc numeric(12,2) := 0;
  v_invoice record;
begin
  if p_tenant_id is null or p_billing_profile_id is null then
    raise exception 'Tenant and billing profile are required.';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Payment amount must be greater than zero.';
  end if;

  insert into public.global_payments (
    tenant_id,
    billing_profile_id,
    amount,
    unallocated_amount,
    payment_date,
    method,
    reference,
    note
  )
  values (
    p_tenant_id,
    p_billing_profile_id,
    p_amount,
    p_amount,
    coalesce(p_payment_date, current_date),
    p_method,
    p_reference,
    p_note
  )
  returning * into v_payment;

  if jsonb_typeof(coalesce(p_allocations, '[]'::jsonb)) <> 'array' then
    raise exception 'Allocations must be an array.';
  end if;

  for v_alloc in select * from jsonb_array_elements(coalesce(p_allocations, '[]'::jsonb))
  loop
    v_global_invoice_id := nullif(v_alloc->>'global_invoice_id', '')::bigint;
    v_commerce_invoice_id := nullif(v_alloc->>'commerce_invoice_id', '')::bigint;
    v_legacy_invoice_id := nullif(v_alloc->>'invoice_id', '')::bigint;
    v_alloc_amount := coalesce((v_alloc->>'amount')::numeric, 0.00);

    if v_alloc_amount <= 0.00 then continue; end if;

    if v_global_invoice_id is not null then
      select id, tenant_id, billing_profile_id, total_amount, paid_amount, collection_source
      into v_invoice
      from public.global_invoices where id = v_global_invoice_id for update;

      if not found then raise exception 'Global invoice % not found.', v_global_invoice_id; end if;
      if v_invoice.tenant_id <> p_tenant_id then raise exception 'Invoice tenant mismatch.'; end if;
      if coalesce(v_invoice.billing_profile_id, 0) <> p_billing_profile_id then
        raise exception 'Invoice does not belong to billing profile.';
      end if;
      if v_invoice.collection_source = 'recipient'::public.collection_source_type then
        raise exception 'Dropship/Retail Direct invoices use recipient collection, not billing profile payment.';
      end if;

      insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
      values (p_tenant_id, v_payment.id, v_global_invoice_id, v_alloc_amount);

      update public.global_invoices
      set paid_amount = coalesce(paid_amount, 0.00) + v_alloc_amount, updated_at = now()
      where id = v_global_invoice_id;

      perform public.recompute_global_invoice_payment_status(v_global_invoice_id);

    elsif v_commerce_invoice_id is not null then
      select id, tenant_id, billing_profile_id, total_amount, amount_paid as paid_amount
      into v_invoice
      from public.commerce_invoices where id = v_commerce_invoice_id for update;

      if not found then raise exception 'Commerce invoice % not found.', v_commerce_invoice_id; end if;
      if v_invoice.tenant_id <> p_tenant_id then raise exception 'Invoice tenant mismatch.'; end if;
      if coalesce(v_invoice.billing_profile_id, 0) <> p_billing_profile_id then
        raise exception 'Invoice does not belong to billing profile.';
      end if;

      insert into public.invoice_payments (tenant_id, payment_id, commerce_invoice_id, amount)
      values (p_tenant_id, v_payment.id, v_commerce_invoice_id, v_alloc_amount);

      update public.commerce_invoices
      set amount_paid = coalesce(amount_paid, 0.00) + v_alloc_amount, updated_at = now()
      where id = v_commerce_invoice_id;

    elsif v_legacy_invoice_id is not null then
      select id, tenant_id, billing_profile_id, total_amount, paid_amount
      into v_invoice
      from public.invoices where id = v_legacy_invoice_id for update;

      if not found then raise exception 'Legacy invoice % not found.', v_legacy_invoice_id; end if;
      if v_invoice.tenant_id <> p_tenant_id then raise exception 'Invoice tenant mismatch.'; end if;
      if coalesce(v_invoice.billing_profile_id, 0) <> p_billing_profile_id then
        raise exception 'Invoice does not belong to billing profile.';
      end if;

      insert into public.invoice_payments (tenant_id, payment_id, invoice_id, amount)
      values (p_tenant_id, v_payment.id, v_legacy_invoice_id, v_alloc_amount);

      update public.invoices
      set paid_amount = coalesce(paid_amount, 0.00) + v_alloc_amount, updated_at = now()
      where id = v_legacy_invoice_id;

      perform public.recompute_invoice_payment_status(v_legacy_invoice_id);
    end if;

    v_total_alloc := v_total_alloc + v_alloc_amount;
  end loop;

  if v_total_alloc > p_amount then
    raise exception 'Total allocation exceeds payment amount.';
  end if;

  update public.global_payments
  set unallocated_amount = p_amount - v_total_alloc
  where id = v_payment.id
  returning * into v_payment;

  -- Record payment_received credit into billing_profile_wallet_ledger
  perform public.record_wallet_ledger_entry(
    p_tenant_id => p_tenant_id,
    p_billing_profile_id => p_billing_profile_id,
    p_transaction_type => 'payment_received',
    p_amount => p_amount,
    p_reference_id => p_reference,
    p_reference_notes => coalesce(p_note, 'Payment received: ' || coalesce(p_reference, ''))
  );

  return v_payment;
end;
$$;

grant execute on function public.create_billing_profile_payment_with_allocations to authenticated;

-- ============================================================================
-- 5. Redefine dropship order fulfillment & status advance to write 'dropship_profit' credit
-- ============================================================================
create or replace function public.advance_dropship_order_status(
  p_order_id bigint,
  p_target_status public.shop_order_status,
  p_remittance_ref text default null,
  p_bank_trx_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_invoice public.global_invoices;
  v_current_status public.shop_order_status;
  v_is_valid boolean := false;
  v_billing_profile_id bigint;
  v_profit numeric(12,2) := 0.00;
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

  -- Status transition rules
  if v_current_status = 'pending' and p_target_status in ('processing', 'cancelled') then
    v_is_valid := true;
  elsif v_current_status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received') then
    if p_target_status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received', 'cancelled') then
      v_is_valid := true;
    end if;
  end if;

  if not v_is_valid then
    return jsonb_build_object(
      'success', false,
      'error', format('Invalid status transition for dropship order from %s to %s', v_current_status, p_target_status)
    );
  end if;

  update public.shop_orders
  set
    status = p_target_status,
    delivered_at = case when p_target_status = 'delivered' then now() else delivered_at end,
    courier_remittance_ref = coalesce(p_remittance_ref, courier_remittance_ref),
    courier_bank_trx_id = coalesce(p_bank_trx_id, courier_bank_trx_id),
    updated_at = now()
  where id = p_order_id;

  select * into v_order from public.shop_orders where id = p_order_id;

  if p_target_status in ('ready_for_pickup', 'shipped', 'delivered', 'payment_received') then
    if v_order.global_invoice_id is null then
      perform public.create_dual_invoice_from_dropship_order(p_order_id);
    else
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
      if v_invoice.invoice_status = 'draft'::public.global_invoice_status then
        perform public.post_global_invoice(v_order.global_invoice_id);
      end if;
    end if;

    -- Book dropship_profit credit to Billing Profile Wallet if not already recorded
    v_billing_profile_id := v_order.billing_profile_id;
    if v_billing_profile_id is null and v_order.customer_group_id is not null then
      select id into v_billing_profile_id
      from public.billing_profiles
      where tenant_id = v_order.tenant_id
        and customer_group_id = v_order.customer_group_id
      order by is_default desc, created_at asc
      limit 1;
    end if;

    select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
    v_profit := coalesce(v_invoice.middle_man_payout_amount, 0.00);

    if v_billing_profile_id is not null and v_profit > 0 then
      if not exists (
        select 1 from public.billing_profile_wallet_ledger
        where shop_order_id = p_order_id and transaction_type = 'dropship_profit'
      ) then
        perform public.record_wallet_ledger_entry(
          p_tenant_id => v_order.tenant_id,
          p_billing_profile_id => v_billing_profile_id,
          p_transaction_type => 'dropship_profit',
          p_amount => v_profit,
          p_reference_id => v_order.order_no,
          p_shop_order_id => v_order.id,
          p_global_invoice_id => v_order.global_invoice_id,
          p_reference_notes => 'Dropship profit from order #' || v_order.order_no
        );
      end if;
    end if;

  elsif p_target_status = 'processing' then
    if v_order.global_invoice_id is not null then
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
      if v_invoice.invoice_status = 'posted'::public.global_invoice_status then
        perform public.unpost_global_invoice(v_order.global_invoice_id);
      end if;

      -- Remove wallet profit entry if order is rolled back to processing
      delete from public.billing_profile_wallet_ledger
      where shop_order_id = p_order_id and transaction_type = 'dropship_profit';

      -- Disconnect from order
      update public.shop_orders 
      set global_invoice_id = null 
      where id = p_order_id;

      -- Hard delete draft invoice and lines
      delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoices where id = v_order.global_invoice_id;
    end if;
  end if;

  return jsonb_build_object('success', true, 'new_status', p_target_status);
end;
$$;

grant execute on function public.advance_dropship_order_status(bigint, public.shop_order_status, text, text) to authenticated;

-- ============================================================================
-- 6. Data Migration: Wire existing posted global invoices, global payments, & dropship profits into billing_profile_wallet_ledger
-- ============================================================================

-- 6a. Migrate existing posted global invoices (invoice_billed)
do $$
declare
  r record;
begin
  for r in
    select gi.id, gi.tenant_id, gi.billing_profile_id, gi.total_amount, gi.invoice_no, gi.created_at
    from public.global_invoices gi
    where gi.invoice_status = 'posted'::public.global_invoice_status
      and gi.billing_profile_id is not null
      and gi.total_amount > 0
      and not exists (
        select 1 from public.billing_profile_wallet_ledger
        where global_invoice_id = gi.id and transaction_type = 'invoice_billed'
      )
    order by gi.created_at asc
  loop
    perform public.record_wallet_ledger_entry(
      p_tenant_id => r.tenant_id,
      p_billing_profile_id => r.billing_profile_id,
      p_transaction_type => 'invoice_billed',
      p_amount => r.total_amount,
      p_reference_id => r.invoice_no,
      p_global_invoice_id => r.id,
      p_reference_notes => 'Migrated invoice: ' || r.invoice_no
    );
  end loop;
end;
$$;

-- 6b. Migrate existing global payments (payment_received)
do $$
declare
  r record;
begin
  for r in
    select gp.id, gp.tenant_id, gp.billing_profile_id, gp.amount, gp.reference, gp.note, gp.created_at
    from public.global_payments gp
    where gp.billing_profile_id is not null
      and gp.amount > 0
      and not exists (
        select 1 from public.billing_profile_wallet_ledger
        where reference_id = gp.reference and transaction_type = 'payment_received'
      )
    order by gp.created_at asc
  loop
    perform public.record_wallet_ledger_entry(
      p_tenant_id => r.tenant_id,
      p_billing_profile_id => r.billing_profile_id,
      p_transaction_type => 'payment_received',
      p_amount => r.amount,
      p_reference_id => r.reference,
      p_reference_notes => coalesce(r.note, 'Migrated payment')
    );
  end loop;
end;
$$;

-- 6c. Migrate existing dropship profits from legacy middle_man_payout_ledger if table exists
do $$
begin
  if exists (select 1 from information_schema.tables where table_name = 'middle_man_payout_ledger') then
    execute $mig$
      insert into public.billing_profile_wallet_ledger (
        tenant_id,
        billing_profile_id,
        transaction_type,
        amount,
        balance_after,
        reference_id,
        shop_order_id,
        global_invoice_id,
        reference_notes,
        created_at
      )
      select
        mpl.tenant_id,
        coalesce(so.billing_profile_id, bp.id) as billing_profile_id,
        case mpl.entry_type
          when 'profit_credit' then 'dropship_profit'
          when 'payout_debit' then 'payout_paid'
          else 'adjustment'
        end as transaction_type,
        mpl.amount,
        mpl.balance_after,
        coalesce(so.order_no, mpl.global_invoice_id::text) as reference_id,
        mpl.shop_order_id,
        mpl.global_invoice_id,
        'Migrated from middle_man_payout_ledger',
        mpl.created_at
      from public.middle_man_payout_ledger mpl
      left join public.shop_orders so on so.id = mpl.shop_order_id
      left join public.customer_group_members cgm on cgm.id = mpl.customer_group_member_id
      left join public.billing_profiles bp on bp.tenant_id = mpl.tenant_id and bp.customer_group_id = cgm.customer_group_id
      where coalesce(so.billing_profile_id, bp.id) is not null
        and not exists (
          select 1 from public.billing_profile_wallet_ledger bwl
          where bwl.shop_order_id = mpl.shop_order_id and bwl.transaction_type = 'dropship_profit'
        );
    $mig$;
  end if;
end;
$$;

commit;
