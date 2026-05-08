alter table public.payments
  rename column customer_id to billing_profile_id;

drop index if exists payments_customer_id_idx;
create index if not exists payments_billing_profile_id_idx on public.payments(billing_profile_id);

alter table public.payments
  drop constraint if exists payments_customer_id_fkey;

alter table public.payments
  add constraint payments_billing_profile_id_fkey
  foreign key (billing_profile_id)
  references public.billing_profiles(id)
  on delete restrict;

drop function if exists public.create_customer_payment_with_allocations(
  bigint,
  bigint,
  numeric,
  date,
  text,
  text,
  text,
  jsonb
);

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
  v_invoice_id bigint;
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

  insert into public.payments (
    tenant_id,
    billing_profile_id,
    amount,
    payment_date,
    method,
    reference,
    note
  )
  values (
    p_tenant_id,
    p_billing_profile_id,
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
    v_invoice_id := nullif(v_alloc->>'invoice_id', '')::bigint;
    v_alloc_amount := coalesce((v_alloc->>'amount')::numeric, 0);

    if v_invoice_id is null or v_alloc_amount <= 0 then
      continue;
    end if;

    select id, tenant_id, billing_profile_id, total_amount, paid_amount
    into v_invoice
    from public.invoices
    where id = v_invoice_id
    for update;

    if not found then
      raise exception 'Invoice % not found.', v_invoice_id;
    end if;

    if v_invoice.tenant_id <> p_tenant_id then
      raise exception 'Invoice % does not belong to tenant.', v_invoice_id;
    end if;

    if coalesce(v_invoice.billing_profile_id, 0) <> p_billing_profile_id then
      raise exception 'Invoice % does not belong to selected billing profile.', v_invoice_id;
    end if;

    if (coalesce(v_invoice.total_amount, 0) - coalesce(v_invoice.paid_amount, 0)) < v_alloc_amount then
      raise exception 'Allocation for invoice % exceeds due amount.', v_invoice_id;
    end if;

    insert into public.payment_allocations (
      tenant_id,
      payment_id,
      invoice_id,
      amount
    )
    values (
      p_tenant_id,
      v_payment.id,
      v_invoice_id,
      v_alloc_amount
    );

    update public.invoices
    set paid_amount = coalesce(paid_amount, 0) + v_alloc_amount,
        updated_at = now()
    where id = v_invoice_id;

    perform public.recompute_invoice_payment_status(v_invoice_id);

    v_total_alloc := v_total_alloc + v_alloc_amount;
  end loop;

  if v_total_alloc > p_amount then
    raise exception 'Total allocation exceeds payment amount.';
  end if;

  return v_payment;
end;
$$;

grant execute on function public.create_billing_profile_payment_with_allocations(bigint, bigint, numeric, date, text, text, text, jsonb) to authenticated;
