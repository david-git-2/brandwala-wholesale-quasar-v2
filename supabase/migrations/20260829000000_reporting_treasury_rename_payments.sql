begin;

-- =========================================================
-- 1. Rename tables
-- =========================================================
alter table public.payments rename to global_payments;
alter table public.payment_allocations rename to invoice_payments;

-- =========================================================
-- 2. Add unallocated_amount column
-- =========================================================
alter table public.global_payments
  add column if not exists unallocated_amount numeric(12,2) not null default 0.00;

-- =========================================================
-- 3. Backfill unallocated_amount
-- =========================================================
update public.global_payments gp
set unallocated_amount = gp.amount - coalesce(
  (select sum(ip.amount) from public.invoice_payments ip where ip.payment_id = gp.id),
  0.00
);

-- =========================================================
-- 4. Redefine create_billing_profile_payment_with_allocations
-- =========================================================
drop function if exists public.create_billing_profile_payment_with_allocations(bigint, bigint, numeric, date, text, text, text, jsonb) cascade;

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

  return v_payment;
end;
$$;

grant execute on function public.create_billing_profile_payment_with_allocations(bigint, bigint, numeric, date, text, text, text, jsonb) to authenticated;

-- =========================================================
-- 5. Redefine create_middle_man_payout
-- =========================================================
create or replace function public.create_middle_man_payout(
  p_tenant_id bigint,
  p_billing_profile_id bigint,
  p_global_invoice_id bigint,
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
  v_paid numeric(12,2) := 0.00;
  v_outstanding numeric(12,2);
begin
  select * into v_invoice from public.global_invoices where id = p_global_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_type <> 'dropship'::public.global_invoice_type then
    raise exception 'Not a dropship invoice.';
  end if;
  if v_invoice.billing_profile_id <> p_billing_profile_id then
    raise exception 'Billing profile mismatch.';
  end if;
  if coalesce(p_amount, 0.00) <= 0.00 then raise exception 'Amount must be positive.'; end if;

  select coalesce(sum(amount), 0.00) into v_paid
  from public.global_payments
  where tenant_id = p_tenant_id
    and billing_profile_id = p_billing_profile_id
    and note like ('middle_man_payout:' || p_global_invoice_id::text || '%');

  v_outstanding := greatest(coalesce(v_invoice.middle_man_payout_amount, 0.00) - v_paid, 0.00);
  if p_amount > v_outstanding then
    raise exception 'Payout exceeds outstanding middle-man amount.';
  end if;

  insert into public.global_payments (tenant_id, billing_profile_id, amount, unallocated_amount, payment_date, method, note)
  values (
    p_tenant_id,
    p_billing_profile_id,
    p_amount,
    0.00,
    current_date,
    'payout',
    'middle_man_payout:' || p_global_invoice_id::text || coalesce(' ' || nullif(trim(p_note), ''), '')
  );

  update public.global_invoices
  set
    middle_man_payout_status = case
      when (v_paid + p_amount) >= coalesce(middle_man_payout_amount, 0.00) then 'paid'
      else 'pending'
    end,
    updated_at = now()
  where id = p_global_invoice_id
  returning * into v_invoice;

  return v_invoice;
end;
$$;

grant execute on function public.create_middle_man_payout(bigint, bigint, bigint, numeric, text) to authenticated;

-- =========================================================
-- 6. create allocate_payment_to_global_invoice
-- =========================================================
create or replace function public.allocate_payment_to_global_invoice(
  p_tenant_id bigint,
  p_payment_id bigint,
  p_global_invoice_id bigint,
  p_amount numeric
)
returns public.invoice_payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment public.global_payments;
  v_invoice public.global_invoices;
  v_row public.invoice_payments;
begin
  if p_tenant_id is null or p_payment_id is null or p_global_invoice_id is null then
    raise exception 'Tenant, payment and invoice are required.';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Allocation amount must be greater than zero.';
  end if;

  -- Lock payment
  select * into v_payment from public.global_payments where id = p_payment_id for update;
  if not found then raise exception 'Payment not found.'; end if;
  if v_payment.tenant_id <> p_tenant_id then raise exception 'Payment tenant mismatch.'; end if;

  -- Lock invoice
  select * into v_invoice from public.global_invoices where id = p_global_invoice_id for update;
  if not found then raise exception 'Invoice not found.'; end if;
  if v_invoice.tenant_id <> p_tenant_id then raise exception 'Invoice tenant mismatch.'; end if;

  -- Validate same billing profile
  if coalesce(v_invoice.billing_profile_id, 0) <> coalesce(v_payment.billing_profile_id, 0) then
    raise exception 'Invoice and payment billing profile mismatch.';
  end if;

  -- Check payment unallocated amount
  if p_amount > v_payment.unallocated_amount then
    raise exception 'Allocation amount % exceeds payment unallocated amount %.', p_amount, v_payment.unallocated_amount;
  end if;

  -- Check invoice remaining due balance
  if p_amount > v_invoice.due_amount then
    raise exception 'Allocation amount % exceeds invoice remaining due balance %.', p_amount, v_invoice.due_amount;
  end if;

  -- Insert allocation record
  insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
  values (p_tenant_id, p_payment_id, p_global_invoice_id, p_amount)
  returning * into v_row;

  -- Update payment unallocated amount
  update public.global_payments
  set unallocated_amount = unallocated_amount - p_amount
  where id = p_payment_id;

  -- Update invoice paid amount
  update public.global_invoices
  set paid_amount = coalesce(paid_amount, 0.00) + p_amount, updated_at = now()
  where id = p_global_invoice_id;

  -- Recompute invoice payment status and due_amount
  perform public.recompute_global_invoice_payment_status(p_global_invoice_id);

  return v_row;
end;
$$;

grant execute on function public.allocate_payment_to_global_invoice(bigint, bigint, bigint, numeric) to authenticated;
grant execute on function public.allocate_payment_to_global_invoice(bigint, bigint, bigint, numeric) to anon;
grant execute on function public.allocate_payment_to_global_invoice(bigint, bigint, bigint, numeric) to service_role;

commit;
