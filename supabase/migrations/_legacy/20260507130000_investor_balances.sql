create table if not exists public.investor_balances (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  investor_id bigint not null references public.investors(id) on delete cascade,
  total_deposit numeric(12,2) not null default 0 check (total_deposit >= 0),
  total_withdrawal numeric(12,2) not null default 0 check (total_withdrawal >= 0),
  total_profit_payout numeric(12,2) not null default 0 check (total_profit_payout >= 0),
  total_invested_active numeric(12,2) not null default 0 check (total_invested_active >= 0),
  available_balance numeric(12,2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, investor_id)
);

create index if not exists investor_balances_tenant_id_idx
  on public.investor_balances (tenant_id);

create index if not exists investor_balances_investor_id_idx
  on public.investor_balances (investor_id);

create or replace function public.refresh_investor_balance(
  p_tenant_id bigint,
  p_investor_id bigint
)
returns void
language plpgsql
as $$
declare
  v_total_deposit numeric(12,2);
  v_total_withdrawal numeric(12,2);
  v_total_profit_payout numeric(12,2);
  v_total_invested_active numeric(12,2);
begin
  select coalesce(sum(it.amount), 0)
  into v_total_deposit
  from public.investor_transactions it
  where it.tenant_id = p_tenant_id
    and it.investor_id = p_investor_id
    and it.type = 'deposit';

  select coalesce(sum(it.amount), 0)
  into v_total_withdrawal
  from public.investor_transactions it
  where it.tenant_id = p_tenant_id
    and it.investor_id = p_investor_id
    and it.type = 'withdrawal';

  select coalesce(sum(it.amount), 0)
  into v_total_profit_payout
  from public.investor_transactions it
  where it.tenant_id = p_tenant_id
    and it.investor_id = p_investor_id
    and it.type = 'profit_payout';

  select coalesce(sum(si.invested_amount), 0)
  into v_total_invested_active
  from public.shipment_investments si
  where si.tenant_id = p_tenant_id
    and si.investor_id = p_investor_id
    and si.status = 'active';

  insert into public.investor_balances (
    tenant_id,
    investor_id,
    total_deposit,
    total_withdrawal,
    total_profit_payout,
    total_invested_active,
    available_balance
  )
  values (
    p_tenant_id,
    p_investor_id,
    v_total_deposit,
    v_total_withdrawal,
    v_total_profit_payout,
    v_total_invested_active,
    (v_total_deposit - v_total_withdrawal - v_total_profit_payout - v_total_invested_active)
  )
  on conflict (tenant_id, investor_id)
  do update set
    total_deposit = excluded.total_deposit,
    total_withdrawal = excluded.total_withdrawal,
    total_profit_payout = excluded.total_profit_payout,
    total_invested_active = excluded.total_invested_active,
    available_balance = excluded.available_balance,
    updated_at = now();
end;
$$;

create or replace function public.sync_investor_balance_from_transactions()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_investor_balance(old.tenant_id, old.investor_id);
    return old;
  end if;

  if tg_op = 'UPDATE' and (old.tenant_id <> new.tenant_id or old.investor_id <> new.investor_id) then
    perform public.refresh_investor_balance(old.tenant_id, old.investor_id);
  end if;

  perform public.refresh_investor_balance(new.tenant_id, new.investor_id);
  return new;
end;
$$;

create or replace function public.sync_investor_balance_from_shipment_investments()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_investor_balance(old.tenant_id, old.investor_id);
    return old;
  end if;

  if tg_op = 'UPDATE' and (old.tenant_id <> new.tenant_id or old.investor_id <> new.investor_id) then
    perform public.refresh_investor_balance(old.tenant_id, old.investor_id);
  end if;

  perform public.refresh_investor_balance(new.tenant_id, new.investor_id);
  return new;
end;
$$;

create or replace function public.sync_investor_balance_from_investors()
returns trigger
language plpgsql
as $$
begin
  perform public.refresh_investor_balance(new.tenant_id, new.id);
  return new;
end;
$$;

drop trigger if exists trg_investor_balances_set_updated_at on public.investor_balances;
create trigger trg_investor_balances_set_updated_at before update on public.investor_balances
for each row execute function public.set_updated_at();

drop trigger if exists trg_sync_investor_balance_transactions on public.investor_transactions;
create trigger trg_sync_investor_balance_transactions
after insert or update or delete on public.investor_transactions
for each row execute function public.sync_investor_balance_from_transactions();

drop trigger if exists trg_sync_investor_balance_shipments on public.shipment_investments;
create trigger trg_sync_investor_balance_shipments
after insert or update or delete on public.shipment_investments
for each row execute function public.sync_investor_balance_from_shipment_investments();

drop trigger if exists trg_sync_investor_balance_investors on public.investors;
create trigger trg_sync_investor_balance_investors
after insert on public.investors
for each row execute function public.sync_investor_balance_from_investors();

do $$
declare
  v_investor record;
begin
  for v_investor in
    select i.tenant_id, i.id as investor_id
    from public.investors i
  loop
    perform public.refresh_investor_balance(v_investor.tenant_id, v_investor.investor_id);
  end loop;
end $$;

alter table public.investor_balances enable row level security;

drop policy if exists investor_balances_select on public.investor_balances;
create policy investor_balances_select on public.investor_balances for select to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = investor_balances.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists investor_balances_insert on public.investor_balances;
create policy investor_balances_insert on public.investor_balances for insert to authenticated with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = investor_balances.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists investor_balances_update on public.investor_balances;
create policy investor_balances_update on public.investor_balances for update to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = investor_balances.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
) with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = investor_balances.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists investor_balances_delete on public.investor_balances;
create policy investor_balances_delete on public.investor_balances for delete to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = investor_balances.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

grant select, insert, update, delete on table public.investor_balances to authenticated;
grant usage, select on sequence public.investor_balances_id_seq to authenticated;
