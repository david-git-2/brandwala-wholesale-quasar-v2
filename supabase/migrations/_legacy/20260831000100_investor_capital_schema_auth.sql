begin;

-- =========================================================
-- 1. Global shipment link (2a)
-- =========================================================
-- Add global_shipment_id to shipment_investments
alter table public.shipment_investments
  add column if not exists global_shipment_id bigint references public.global_shipments(id) on delete cascade;

-- Keep shipment_id nullable during transition
alter table public.shipment_investments
  alter column shipment_id drop not null;

-- Create index on global_shipment_id
create index if not exists shipment_investments_global_shipment_id_idx on public.shipment_investments(global_shipment_id);

-- Backfill: join shipments -> global_shipments via tenant_shipment_id
update public.shipment_investments si
set global_shipment_id = gs.id
from public.shipments s
join public.global_shipments gs
  on gs.parent_tenant_id = s.tenant_id
  and gs.tenant_shipment_id = s.tenant_shipment_id
where si.shipment_id = s.id
  and si.global_shipment_id is null;

-- =========================================================
-- 2. Investor profile fields (2b)
-- =========================================================
-- Add new fields to investors table if missing
alter table public.investors
  add column if not exists is_active boolean not null default true,
  add column if not exists currency_code text not null default 'BDT',
  add column if not exists notes text null;

-- Extend investor_transaction_type enum with target types
alter type public.investor_transaction_type add value if not exists 'capital_in';
alter type public.investor_transaction_type add value if not exists 'capital_adjustment';
alter type public.investor_transaction_type add value if not exists 'withdrawal_paid';
alter type public.investor_transaction_type add value if not exists 'profit_reinvest';
alter type public.investor_transaction_type add value if not exists 'manual_adjustment';

-- =========================================================
-- 3. Membership auth (2c)
-- =========================================================
-- Add investor_id to memberships
alter table public.memberships
  add column if not exists investor_id bigint references public.investors(id) on delete set null;

-- Migrate active investor_accounts rows -> memberships
insert into public.memberships (tenant_id, email, role, is_active, investor_id)
select ia.tenant_id, lower(trim(ia.email)), 'investor'::public.app_role, ia.is_active, ia.investor_id
from public.investor_accounts ia
on conflict ((lower(trim(email))), (coalesce(tenant_id, -1))) do update
set role = excluded.role,
    investor_id = excluded.investor_id,
    is_active = excluded.is_active;

-- =========================================================
-- 4. RLS helper & policy updates (2c)
-- =========================================================
create or replace function public.auth_investor_id()
returns bigint
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_investor_id bigint;
begin
  select investor_id into v_investor_id
  from public.memberships
  where lower(trim(email)) = public.current_user_email()
    and is_active = true
    and role = 'investor'::public.app_role
  limit 1;

  return v_investor_id;
end;
$$;

grant execute on function public.auth_investor_id() to authenticated;

-- Tighten SELECT policies for investors, transactions, and investments
drop policy if exists investors_select on public.investors;
create policy investors_select on public.investors for select to authenticated using (
  public.user_can_manage_parent_tenant(tenant_id)
  or (public.auth_investor_id() = id)
);

drop policy if exists investor_transactions_select on public.investor_transactions;
create policy investor_transactions_select on public.investor_transactions for select to authenticated using (
  public.user_can_manage_parent_tenant(tenant_id)
  or (public.auth_investor_id() = investor_id)
);

drop policy if exists shipment_investments_select on public.shipment_investments;
create policy shipment_investments_select on public.shipment_investments for select to authenticated using (
  public.user_can_manage_parent_tenant(tenant_id)
  or (public.auth_investor_id() = investor_id)
);

-- =========================================================
-- 5. Profit status enum alignment (2d)
-- =========================================================
-- Dynamically find and drop the old check constraint on profit_status
do $$
declare
  v_constraint_name text;
begin
  select con.conname into v_constraint_name
  from pg_constraint con
  join pg_class rel on rel.oid = con.conrelid
  join pg_namespace nsp on nsp.oid = rel.relnamespace
  where nsp.nspname = 'public'
    and rel.relname = 'shipment_investments'
    and con.contype = 'c'
    and pg_get_constraintdef(con.oid) like '%profit_status%';

  if v_constraint_name is not null then
    execute format('alter table public.shipment_investments drop constraint %I', v_constraint_name);
  end if;
end $$;

-- Migrate existing profit_status values
update public.shipment_investments
set profit_status = case
  when profit_status = 'pending' then 'open'
  when profit_status = 'allocated' then 'partial'
  when profit_status = 'paid_out' then 'realized'
  else 'open'
end;

-- Set column default
alter table public.shipment_investments alter column profit_status set default 'open';

-- Add new check constraint
alter table public.shipment_investments
  add constraint shipment_investments_profit_status_check
  check (profit_status in ('open', 'partial', 'realized'));

-- =========================================================
-- 6. Rewrite/Tighten portal RPCs (2c)
-- =========================================================
create or replace function public.get_investor_portfolio_summary(
  p_investor_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_investor public.investors;
  v_deposits numeric(12,2);
  v_withdrawals numeric(12,2);
  v_deployed numeric(12,2);
  v_payouts numeric(12,2);
begin
  select * into v_investor from public.investors where id = p_investor_id;
  if v_investor.id is null then raise exception 'investor not found'; end if;

  if not (
    public.user_can_manage_parent_tenant(v_investor.tenant_id)
    or (public.auth_investor_id() = p_investor_id)
  ) then
    raise exception 'not allowed';
  end if;

  select
    coalesce(sum(case when type in ('deposit', 'capital_in') then amount else 0 end), 0),
    coalesce(sum(case when type in ('withdrawal', 'withdrawal_paid') then amount else 0 end), 0),
    coalesce(sum(case when type = 'profit_payout' then amount else 0 end), 0)
  into v_deposits, v_withdrawals, v_payouts
  from public.investor_transactions
  where investor_id = p_investor_id;

  select coalesce(sum(invested_amount), 0) into v_deployed
  from public.shipment_investments
  where investor_id = p_investor_id and status = 'active';

  return jsonb_build_object(
    'investor', row_to_json(v_investor),
    'balances', jsonb_build_object(
      'deposits', v_deposits,
      'withdrawals', v_withdrawals,
      'deployed', v_deployed,
      'available', v_deposits - v_withdrawals - v_deployed,
      'payouts', v_payouts
    ),
    'active_investments', (
      select coalesce(jsonb_agg(to_jsonb(si.*)), '[]'::jsonb)
      from public.shipment_investments si
      where si.investor_id = p_investor_id and si.status = 'active'
    )
  );
end;
$$;

grant execute on function public.get_investor_portfolio_summary(bigint) to authenticated;

create or replace function public.get_investor_bootstrap_context(
  p_tenant_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_membership public.memberships;
  v_tenant public.tenants;
begin
  select * into v_tenant from public.tenants where id = p_tenant_id;
  if v_tenant.id is null then raise exception 'tenant not found'; end if;

  select * into v_membership
  from public.memberships m
  where m.tenant_id = p_tenant_id
    and lower(trim(m.email)) = public.current_user_email()
    and m.is_active = true
    and m.role = 'investor'::public.app_role
  limit 1;

  if v_membership.id is null then
    return jsonb_build_object('authenticated', false, 'tenant', row_to_json(v_tenant));
  end if;

  return jsonb_build_object(
    'authenticated', true,
    'tenant', row_to_json(v_tenant),
    'investor_account', row_to_json(v_membership),
    'portfolio', public.get_investor_portfolio_summary(v_membership.investor_id),
    'module_keys', (
      select coalesce(jsonb_agg(tm.module_key), '[]'::jsonb)
      from public.tenant_modules tm
      where tm.tenant_id = p_tenant_id
        and tm.is_active = true
        and tm.module_key = 'investor_portal'
    )
  );
end;
$$;

grant execute on function public.get_investor_bootstrap_context(bigint) to authenticated;

commit;
