-- Step 5: payment allocations for global + commerce invoices
begin;

alter table public.payment_allocations
  add column if not exists global_invoice_id bigint null references public.global_invoices(id) on delete cascade,
  add column if not exists commerce_invoice_id bigint null references public.commerce_invoices(id) on delete cascade;

alter table public.payment_allocations
  drop constraint if exists payment_allocations_invoice_id_fkey;

alter table public.payment_allocations
  alter column invoice_id drop not null;

create index if not exists payment_allocations_global_invoice_id_idx
  on public.payment_allocations (global_invoice_id);

create index if not exists payment_allocations_commerce_invoice_id_idx
  on public.payment_allocations (commerce_invoice_id);

create or replace function public.recompute_global_invoice_payment_status(p_global_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total numeric(12,2);
  v_paid numeric(12,2);
begin
  select total_amount, coalesce(paid_amount, 0)
  into v_total, v_paid
  from public.global_invoices
  where id = p_global_invoice_id;

  if not found then return; end if;

  update public.global_invoices
  set
    payment_status = case
      when coalesce(v_paid, 0) <= 0 then 'due'
      when v_paid >= coalesce(v_total, 0) then 'paid'
      else 'partially_paid'
    end,
    due_amount = greatest(coalesce(v_total, 0) - coalesce(v_paid, 0), 0),
    updated_at = now()
  where id = p_global_invoice_id;
end;
$$;

grant execute on function public.recompute_global_invoice_payment_status(bigint) to authenticated;

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
returns public.payments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment public.payments;
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

  insert into public.payments (tenant_id, billing_profile_id, amount, payment_date, method, reference, note)
  values (p_tenant_id, p_billing_profile_id, p_amount, coalesce(p_payment_date, current_date), p_method, p_reference, p_note)
  returning * into v_payment;

  for v_alloc in select * from jsonb_array_elements(coalesce(p_allocations, '[]'::jsonb))
  loop
    v_global_invoice_id := nullif(v_alloc->>'global_invoice_id', '')::bigint;
    v_commerce_invoice_id := nullif(v_alloc->>'commerce_invoice_id', '')::bigint;
    v_legacy_invoice_id := nullif(v_alloc->>'invoice_id', '')::bigint;
    v_alloc_amount := coalesce((v_alloc->>'amount')::numeric, 0);

    if v_alloc_amount <= 0 then continue; end if;

    if v_global_invoice_id is not null then
      select id, tenant_id, billing_profile_id, total_amount, paid_amount, collection_source
      into v_invoice
      from public.global_invoices where id = v_global_invoice_id for update;

      if not found then raise exception 'Global invoice % not found.', v_global_invoice_id; end if;
      if v_invoice.tenant_id <> p_tenant_id then raise exception 'Invoice tenant mismatch.'; end if;
      if coalesce(v_invoice.billing_profile_id, 0) <> p_billing_profile_id then
        raise exception 'Invoice does not belong to billing profile.';
      end if;
      if v_invoice.collection_source = 'recipient' then
        raise exception 'Dropship invoices use recipient collection, not billing profile payment.';
      end if;

      insert into public.payment_allocations (tenant_id, payment_id, global_invoice_id, amount)
      values (p_tenant_id, v_payment.id, v_global_invoice_id, v_alloc_amount);

      update public.global_invoices
      set paid_amount = coalesce(paid_amount, 0) + v_alloc_amount, updated_at = now()
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

      insert into public.payment_allocations (tenant_id, payment_id, commerce_invoice_id, amount)
      values (p_tenant_id, v_payment.id, v_commerce_invoice_id, v_alloc_amount);

      update public.commerce_invoices
      set amount_paid = coalesce(amount_paid, 0) + v_alloc_amount, updated_at = now()
      where id = v_commerce_invoice_id;

    elsif v_legacy_invoice_id is not null then
      insert into public.payment_allocations (tenant_id, payment_id, invoice_id, amount)
      values (p_tenant_id, v_payment.id, v_legacy_invoice_id, v_alloc_amount);
    end if;

    v_total_alloc := v_total_alloc + v_alloc_amount;
  end loop;

  if v_total_alloc > p_amount then
    raise exception 'Total allocation exceeds payment amount.';
  end if;

  return v_payment;
end;
$$;

create or replace function public.record_recipient_invoice_collection(
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
begin
  select * into v_invoice from public.global_invoices where id = p_global_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.collection_source <> 'recipient' then
    raise exception 'This invoice does not collect from recipient.';
  end if;
  if coalesce(p_amount, 0) <= 0 then raise exception 'Amount must be positive.'; end if;

  update public.global_invoices
  set
    paid_amount = coalesce(paid_amount, 0) + p_amount,
    note = coalesce(nullif(trim(p_note), ''), note),
    updated_at = now()
  where id = p_global_invoice_id
  returning * into v_invoice;

  perform public.recompute_global_invoice_payment_status(p_global_invoice_id);
  return v_invoice;
end;
$$;

grant execute on function public.record_recipient_invoice_collection(bigint, numeric, text) to authenticated;

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
  v_paid numeric(12,2) := 0;
  v_outstanding numeric(12,2);
begin
  select * into v_invoice from public.global_invoices where id = p_global_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_type <> 'dropship' then raise exception 'Not a dropship invoice.'; end if;
  if v_invoice.billing_profile_id <> p_billing_profile_id then raise exception 'Billing profile mismatch.'; end if;
  if coalesce(p_amount, 0) <= 0 then raise exception 'Amount must be positive.'; end if;

  select coalesce(sum(amount), 0) into v_paid
  from public.payments
  where tenant_id = p_tenant_id
    and billing_profile_id = p_billing_profile_id
    and note like ('middle_man_payout:' || p_global_invoice_id::text || '%');

  v_outstanding := greatest(coalesce(v_invoice.middle_man_payout_amount, 0) - v_paid, 0);
  if p_amount > v_outstanding then
    raise exception 'Payout exceeds outstanding middle-man amount.';
  end if;

  insert into public.payments (tenant_id, billing_profile_id, amount, payment_date, method, note)
  values (p_tenant_id, p_billing_profile_id, p_amount, current_date, 'payout', 'middle_man_payout:' || p_global_invoice_id::text || coalesce(' ' || nullif(trim(p_note), ''), ''));

  update public.global_invoices
  set
    middle_man_payout_status = case
      when (v_paid + p_amount) >= coalesce(middle_man_payout_amount, 0) then 'paid'
      when (v_paid + p_amount) > 0 then 'partially_paid'
      else 'due'
    end,
    updated_at = now()
  where id = p_global_invoice_id
  returning * into v_invoice;

  return v_invoice;
end;
$$;

grant execute on function public.create_middle_man_payout(bigint, bigint, bigint, numeric, text) to authenticated;

commit;
