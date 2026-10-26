create table if not exists public.payments (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  customer_id bigint not null references public.customer_groups(id) on delete restrict,
  amount numeric(12,2) not null check (amount > 0),
  payment_date date not null default current_date,
  method text null check (method in ('cash', 'bank', 'mobile_banking', 'other') or method is null),
  reference text null,
  note text null,
  created_at timestamptz not null default now()
);

create table if not exists public.payment_allocations (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  payment_id bigint not null references public.payments(id) on delete cascade,
  invoice_id bigint not null references public.invoices(id) on delete restrict,
  amount numeric(12,2) not null check (amount > 0),
  created_at timestamptz not null default now()
);

create index if not exists payments_tenant_id_idx on public.payments(tenant_id);
create index if not exists payments_customer_id_idx on public.payments(customer_id);
create index if not exists payments_payment_date_idx on public.payments(payment_date);
create index if not exists payment_allocations_tenant_id_idx on public.payment_allocations(tenant_id);
create index if not exists payment_allocations_payment_id_idx on public.payment_allocations(payment_id);
create index if not exists payment_allocations_invoice_id_idx on public.payment_allocations(invoice_id);

create or replace function public.recompute_invoice_payment_status(p_invoice_id bigint)
returns void
language plpgsql
as $$
declare
  v_total numeric(12,2);
  v_paid numeric(12,2);
begin
  select total_amount, coalesce(paid_amount, 0)
  into v_total, v_paid
  from public.invoices
  where id = p_invoice_id;

  if not found then
    return;
  end if;

  update public.invoices
  set payment_status =
    case
      when coalesce(v_paid, 0) <= 0 then 'due'
      when coalesce(v_paid, 0) >= coalesce(v_total, 0) then 'paid'
      else 'partially_paid'
    end,
    status =
    case
      when coalesce(v_paid, 0) <= 0 then status
      when coalesce(v_paid, 0) >= coalesce(v_total, 0) then 'paid'
      else 'partially_paid'
    end,
    updated_at = now()
  where id = p_invoice_id;
end;
$$;

create or replace function public.create_customer_payment_with_allocations(
  p_tenant_id bigint,
  p_customer_id bigint,
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
  if p_tenant_id is null or p_customer_id is null then
    raise exception 'Tenant and customer are required.';
  end if;

  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Payment amount must be greater than zero.';
  end if;

  insert into public.payments (
    tenant_id,
    customer_id,
    amount,
    payment_date,
    method,
    reference,
    note
  )
  values (
    p_tenant_id,
    p_customer_id,
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

    select id, tenant_id, customer_group_id, total_amount, paid_amount
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

    if coalesce(v_invoice.customer_group_id, 0) <> p_customer_id then
      raise exception 'Invoice % does not belong to selected customer.', v_invoice_id;
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

alter table public.payments enable row level security;
alter table public.payment_allocations enable row level security;

drop policy if exists payments_select on public.payments;
create policy payments_select on public.payments for select to authenticated using (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = payments.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists payments_insert on public.payments;
create policy payments_insert on public.payments for insert to authenticated with check (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = payments.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists payments_update on public.payments;
create policy payments_update on public.payments for update to authenticated using (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = payments.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
) with check (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = payments.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists payments_delete on public.payments;
create policy payments_delete on public.payments for delete to authenticated using (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = payments.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists payment_allocations_select on public.payment_allocations;
create policy payment_allocations_select on public.payment_allocations for select to authenticated using (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = payment_allocations.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists payment_allocations_insert on public.payment_allocations;
create policy payment_allocations_insert on public.payment_allocations for insert to authenticated with check (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = payment_allocations.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists payment_allocations_update on public.payment_allocations;
create policy payment_allocations_update on public.payment_allocations for update to authenticated using (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = payment_allocations.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
) with check (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = payment_allocations.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists payment_allocations_delete on public.payment_allocations;
create policy payment_allocations_delete on public.payment_allocations for delete to authenticated using (
  exists (
    select 1 from public.memberships m
    where m.tenant_id = payment_allocations.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

grant select, insert, update, delete on table public.payments to authenticated;
grant select, insert, update, delete on table public.payment_allocations to authenticated;
grant usage, select on sequence public.payments_id_seq to authenticated;
grant usage, select on sequence public.payment_allocations_id_seq to authenticated;
grant execute on function public.create_customer_payment_with_allocations(bigint, bigint, numeric, date, text, text, text, jsonb) to authenticated;
