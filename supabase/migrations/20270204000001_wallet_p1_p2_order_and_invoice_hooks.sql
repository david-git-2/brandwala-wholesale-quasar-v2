-- Migration: 20270204000001_wallet_p1_p2_order_and_invoice_hooks.sql
-- Goal: Phase 1 & Phase 2 Universal Wallet integration
-- 1. Extend invoice_billed AR debit entries in post_global_invoice to all billing profile invoices (wholesale & retail account).
-- 2. Update create_billing_profile_payment_with_allocations to record cash credit (tenant) & AR reduction credit (customer).
-- 3. Update record_recipient_invoice_collection to record tenant cash credit for direct non-dropship invoice collections.
-- 4. Update apply_global_invoice_settlement_discount to record tenant settlement discount debit.

begin;

-- ============================================================================
-- 1. Redefine post_global_invoice to support wholesale/retail AR billing
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

  -- Validate required fields per invoice type
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

  -- Snapshot unit costs on line items
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

  -- Universal wallet: invoice_billed debit for any account/billing_profile invoice (wholesale, dropship, retail account)
  if v_invoice.billing_profile_id is not null
     and coalesce(v_invoice.total_amount, 0) > 0
  then
    if not exists (
      select 1 from public.universal_wallet_ledger
      where source_type = 'sales_invoice'
        and source_id = p_invoice_id::text
        and entity_type = 'customer'
        and entity_id = v_invoice.billing_profile_id
        and metadata->>'transaction_type' = 'invoice_billed'
    ) then
      perform public.record_ledger_transaction(
        p_tenant_id => v_invoice.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.billing_profile_id,
        p_type => 'debit',
        p_amount => v_invoice.total_amount,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'sales_invoice',
        p_source_id => p_invoice_id::text,
        p_metadata => jsonb_build_object(
          'section', 'invoices',
          'purpose', 'invoice_billed',
          'transaction_type', 'invoice_billed',
          'label', 'Invoice Billed',
          'invoice_no', v_invoice.invoice_no,
          'invoice_id', v_invoice.id,
          'invoice_type', v_invoice.invoice_type
        )
      );
    end if;
  end if;
end;
$$;

grant execute on function public.post_global_invoice(bigint) to authenticated;
grant execute on function public.post_global_invoice(bigint) to service_role;


-- ============================================================================
-- 2. Redefine create_billing_profile_payment_with_allocations to write UWL
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

  -- Universal Wallet 1: Credit Tenant Cash Available (money received)
  perform public.record_ledger_transaction(
    p_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => p_tenant_id,
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'sales_invoice',
    p_source_id => v_payment.id::text,
    p_metadata => jsonb_build_object(
      'section', 'payments',
      'purpose', 'tenant_payment_received',
      'transaction_type', 'payment_received',
      'label', 'Payment Received',
      'payment_id', v_payment.id,
      'billing_profile_id', p_billing_profile_id,
      'reference', p_reference
    )
  );

  -- Universal Wallet 2: Credit Customer Available (reduces Accounts Receivable)
  perform public.record_ledger_transaction(
    p_tenant_id => p_tenant_id,
    p_entity_type => 'customer',
    p_entity_id => p_billing_profile_id,
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'sales_invoice',
    p_source_id => v_payment.id::text,
    p_metadata => jsonb_build_object(
      'section', 'payments',
      'purpose', 'customer_ar_reduction',
      'transaction_type', 'payment_received',
      'label', 'Payment Applied',
      'payment_id', v_payment.id,
      'reference', p_reference
    )
  );

  return v_payment;
end;
$$;

grant execute on function public.create_billing_profile_payment_with_allocations to authenticated;
grant execute on function public.create_billing_profile_payment_with_allocations to service_role;


-- ============================================================================
-- 3. Redefine record_recipient_invoice_collection to write UWL tenant credit
-- ============================================================================
create or replace function public.record_recipient_invoice_collection(
  p_global_invoice_id bigint,
  p_amount numeric,
  p_payment_date date default null,
  p_method text default 'cash',
  p_reference text default null,
  p_note text default null
)
returns public.global_invoices
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_payment_id bigint;
begin
  select * into v_invoice from public.global_invoices where id = p_global_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.collection_source <> 'recipient'::public.collection_source_type then
    raise exception 'This invoice does not collect from recipient.';
  end if;
  if coalesce(p_amount, 0.00) <= 0.00 then raise exception 'Amount must be positive.'; end if;

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
    v_invoice.tenant_id,
    null,
    'recipient'::public.collection_source_type,
    p_amount,
    0.00,
    coalesce(p_payment_date, current_date),
    p_method,
    p_reference,
    nullif(trim(p_note), '')
  )
  returning id into v_payment_id;

  insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
  values (v_invoice.tenant_id, v_payment_id, p_global_invoice_id, p_amount);

  update public.global_invoices
  set
    paid_amount = coalesce(paid_amount, 0.00) + p_amount,
    note = coalesce(nullif(trim(p_note), ''), note),
    updated_at = now()
  where id = p_global_invoice_id
  returning * into v_invoice;

  perform public.recompute_global_invoice_payment_status(p_global_invoice_id);

  -- Record Tenant Cash Credit for direct cash collection
  perform public.record_ledger_transaction(
    p_tenant_id => v_invoice.tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_invoice.tenant_id,
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'sales_invoice',
    p_source_id => p_global_invoice_id::text,
    p_metadata => jsonb_build_object(
      'section', 'payments',
      'purpose', 'recipient_cash_collection',
      'transaction_type', 'cash_collected',
      'label', 'Direct Cash Collection',
      'payment_id', v_payment_id,
      'invoice_id', p_global_invoice_id,
      'invoice_no', v_invoice.invoice_no
    )
  );

  return v_invoice;
end;
$$;

grant execute on function public.record_recipient_invoice_collection(bigint, numeric, date, text, text, text) to authenticated;
grant execute on function public.record_recipient_invoice_collection(bigint, numeric, date, text, text, text) to service_role;


-- ============================================================================
-- 4. Redefine apply_global_invoice_settlement_discount to write UWL write-off
-- ============================================================================
create or replace function public.apply_global_invoice_settlement_discount(
  p_invoice_id bigint,
  p_amount numeric,
  p_note text default null
)
returns public.global_invoices
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'posted'::public.global_invoice_status then
    raise exception 'cannot settle a non-posted invoice';
  end if;
  if coalesce(p_amount, 0.00) < 0.00 then
    raise exception 'settlement amount must be 0 or greater';
  end if;
  if coalesce(p_amount, 0.00) > coalesce(v_invoice.due_amount, 0.00) then
    raise exception 'settlement amount exceeds outstanding due';
  end if;

  update public.global_invoices
  set
    settlement_discount_amount = coalesce(settlement_discount_amount, 0.00) + p_amount,
    note = coalesce(nullif(trim(p_note), ''), note),
    updated_at = now()
  where id = p_invoice_id;

  perform public.recompute_global_invoice_totals(p_invoice_id);

  select * into v_invoice from public.global_invoices where id = p_invoice_id;

  -- Record Tenant Revenue Write-Off for settlement discount
  if p_amount > 0 then
    perform public.record_ledger_transaction(
      p_tenant_id => v_invoice.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_invoice.tenant_id,
      p_type => 'debit',
      p_amount => p_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => p_invoice_id::text,
      p_metadata => jsonb_build_object(
        'section', 'settlement_discount',
        'purpose', 'settlement_discount_write_off',
        'transaction_type', 'settlement_discount',
        'label', 'Settlement Discount',
        'invoice_id', p_invoice_id,
        'invoice_no', v_invoice.invoice_no
      )
    );
  end if;

  return v_invoice;
end;
$$;

grant execute on function public.apply_global_invoice_settlement_discount(bigint, numeric, text) to authenticated;
grant execute on function public.apply_global_invoice_settlement_discount(bigint, numeric, text) to service_role;

commit;
