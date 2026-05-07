do $$
begin
  if not exists (select 1 from pg_type where typname = 'investor_transaction_type') then
    create type public.investor_transaction_type as enum (
      'deposit',
      'withdrawal',
      'profit_payout'
    );
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'investor_payment_method') then
    create type public.investor_payment_method as enum (
      'cash',
      'bank',
      'mobile_banking',
      'other'
    );
  end if;
end $$;

do $$
begin
  if not exists (select 1 from pg_type where typname = 'shipment_investment_status') then
    create type public.shipment_investment_status as enum (
      'active',
      'closed',
      'cancelled'
    );
  end if;
end $$;

create table if not exists public.investors (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  name text not null,
  phone text null,
  email text null,
  address text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.investor_transactions (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  investor_id bigint not null references public.investors(id) on delete cascade,
  amount numeric(12,2) not null check (amount > 0),
  date date not null default current_date,
  method public.investor_payment_method not null,
  type public.investor_transaction_type not null,
  note text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.shipment_investments (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  shipment_id bigint not null references public.shipments(id) on delete cascade,
  investor_id bigint not null references public.investors(id) on delete cascade,
  invested_amount numeric(12,2) not null default 0 check (invested_amount >= 0),
  actual_profit numeric(12,2) not null default 0,
  status public.shipment_investment_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists investors_tenant_id_idx
  on public.investors (tenant_id);

create index if not exists investor_transactions_tenant_id_idx
  on public.investor_transactions (tenant_id);

create index if not exists investor_transactions_investor_id_idx
  on public.investor_transactions (investor_id);

create index if not exists shipment_investments_tenant_id_idx
  on public.shipment_investments (tenant_id);

create index if not exists shipment_investments_shipment_id_idx
  on public.shipment_investments (shipment_id);

create index if not exists shipment_investments_investor_id_idx
  on public.shipment_investments (investor_id);

drop trigger if exists trg_investors_set_updated_at on public.investors;
create trigger trg_investors_set_updated_at before update on public.investors
for each row execute function public.set_updated_at();

drop trigger if exists trg_investor_transactions_set_updated_at on public.investor_transactions;
create trigger trg_investor_transactions_set_updated_at before update on public.investor_transactions
for each row execute function public.set_updated_at();

drop trigger if exists trg_shipment_investments_set_updated_at on public.shipment_investments;
create trigger trg_shipment_investments_set_updated_at before update on public.shipment_investments
for each row execute function public.set_updated_at();

alter table public.investors enable row level security;
alter table public.investor_transactions enable row level security;
alter table public.shipment_investments enable row level security;

drop policy if exists investors_select on public.investors;
create policy investors_select on public.investors for select to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = investors.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists investors_insert on public.investors;
create policy investors_insert on public.investors for insert to authenticated with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = investors.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists investors_update on public.investors;
create policy investors_update on public.investors for update to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = investors.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
) with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = investors.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists investors_delete on public.investors;
create policy investors_delete on public.investors for delete to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = investors.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists investor_transactions_select on public.investor_transactions;
create policy investor_transactions_select on public.investor_transactions for select to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = investor_transactions.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists investor_transactions_insert on public.investor_transactions;
create policy investor_transactions_insert on public.investor_transactions for insert to authenticated with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = investor_transactions.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists investor_transactions_update on public.investor_transactions;
create policy investor_transactions_update on public.investor_transactions for update to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = investor_transactions.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
) with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = investor_transactions.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists investor_transactions_delete on public.investor_transactions;
create policy investor_transactions_delete on public.investor_transactions for delete to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = investor_transactions.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists shipment_investments_select on public.shipment_investments;
create policy shipment_investments_select on public.shipment_investments for select to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = shipment_investments.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists shipment_investments_insert on public.shipment_investments;
create policy shipment_investments_insert on public.shipment_investments for insert to authenticated with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = shipment_investments.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists shipment_investments_update on public.shipment_investments;
create policy shipment_investments_update on public.shipment_investments for update to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = shipment_investments.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
) with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = shipment_investments.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists shipment_investments_delete on public.shipment_investments;
create policy shipment_investments_delete on public.shipment_investments for delete to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = shipment_investments.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

insert into public.modules (
  key,
  name,
  description,
  is_active
)
values (
  'investor',
  'Investor',
  'Manage investor profiles and investor transaction records.',
  true
)
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;
