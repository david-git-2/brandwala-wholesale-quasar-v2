-- B6: investor cost_share, investor_accounts, cash circulation, portfolio RPCs
begin;

alter table public.shipment_investments
  add column if not exists cost_share_pct numeric(5,2) null check (cost_share_pct is null or (cost_share_pct >= 0 and cost_share_pct <= 100)),
  add column if not exists allocated_cost numeric(12,2) not null default 0,
  add column if not exists computed_profit numeric(12,2) not null default 0,
  add column if not exists profit_status text not null default 'pending'
    check (profit_status in ('pending', 'allocated', 'paid_out'));

create table if not exists public.investor_accounts (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  investor_id bigint not null references public.investors(id) on delete cascade,
  email text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint investor_accounts_investor_unique unique (investor_id)
);

create unique index if not exists investor_accounts_email_unique_idx
  on public.investor_accounts (lower(trim(email)));

create index if not exists investor_accounts_tenant_id_idx on public.investor_accounts (tenant_id);
create index if not exists investor_accounts_email_idx on public.investor_accounts (lower(trim(email)));

drop trigger if exists trg_investor_accounts_set_updated_at on public.investor_accounts;
create trigger trg_investor_accounts_set_updated_at
before update on public.investor_accounts
for each row execute function public.set_updated_at();

alter table public.investor_accounts enable row level security;

drop policy if exists investor_accounts_select on public.investor_accounts;
create policy investor_accounts_select on public.investor_accounts
for select to authenticated
using (
  public.user_can_manage_parent_tenant(tenant_id)
  or lower(trim(email)) = public.current_user_email()
);

drop policy if exists investor_accounts_write on public.investor_accounts;
create policy investor_accounts_write on public.investor_accounts
for all to authenticated
using (public.user_can_manage_parent_tenant(tenant_id))
with check (public.user_can_manage_parent_tenant(tenant_id));

create or replace function public.refresh_shipment_investor_profits(
  p_shipment_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shipment public.shipments;
  v_accounting public.global_shipment_accounting;
  v_buy numeric(12,2);
  v_profit numeric(12,2);
  v_updated integer := 0;
  v_inv record;
begin
  select * into v_shipment from public.shipments where id = p_shipment_id;
  if v_shipment.id is null then raise exception 'shipment not found'; end if;

  if not public.user_can_manage_parent_tenant(v_shipment.tenant_id) then
    raise exception 'not allowed';
  end if;

  perform public.refresh_global_shipment_accounting(v_shipment.tenant_id, p_shipment_id);

  select * into v_accounting
  from public.global_shipment_accounting
  where shipment_id = p_shipment_id;

  v_buy := coalesce(v_accounting.buy_cost_total, 0);
  v_profit := coalesce(v_accounting.gross_profit_total, 0);

  for v_inv in
    select * from public.shipment_investments
    where shipment_id = p_shipment_id
      and status = 'active'
      and cost_share_pct is not null
  loop
    update public.shipment_investments
    set
      allocated_cost = round(v_buy * v_inv.cost_share_pct / 100.0, 2),
      computed_profit = round(v_profit * v_inv.cost_share_pct / 100.0, 2),
      profit_status = 'allocated'
    where id = v_inv.id;

    v_updated := v_updated + 1;
  end loop;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'updated_count', v_updated,
    'buy_cost_total', v_buy,
    'gross_profit_total', v_profit
  );
end;
$$;

grant execute on function public.refresh_shipment_investor_profits(bigint) to authenticated;

create or replace function public.get_parent_cash_circulation(
  p_parent_tenant_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_deposits numeric(12,2);
  v_withdrawals numeric(12,2);
  v_deployed numeric(12,2);
  v_ar_due numeric(12,2);
  v_ar_paid numeric(12,2);
  v_stock_cost numeric(12,2);
  v_profit_mtd numeric(12,2);
  v_payouts numeric(12,2);
begin
  if not public.user_can_manage_parent_tenant(p_parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  select
    coalesce(sum(case when type = 'deposit' then amount else 0 end), 0),
    coalesce(sum(case when type = 'withdrawal' then amount else 0 end), 0)
  into v_deposits, v_withdrawals
  from public.investor_transactions it
  where it.tenant_id = p_parent_tenant_id;

  select coalesce(sum(invested_amount), 0) into v_deployed
  from public.shipment_investments
  where tenant_id = p_parent_tenant_id and status = 'active';

  select
    coalesce(sum(due_amount), 0),
    coalesce(sum(paid_amount), 0)
  into v_ar_due, v_ar_paid
  from public.global_invoices
  where parent_tenant_id = p_parent_tenant_id;

  select coalesce(sum(gs.cost * q.quantity), 0) into v_stock_cost
  from public.global_stocks gs
  inner join public.global_stock_quantities q on q.stock_id = gs.id
  where gs.parent_tenant_id = p_parent_tenant_id
    and q.status in ('excellent', 'box_less');

  select coalesce(sum(gross_profit_amount), 0) into v_profit_mtd
  from public.global_accounting_ledger
  where parent_tenant_id = p_parent_tenant_id
    and entry_date >= date_trunc('month', current_date)::date;

  select coalesce(sum(amount), 0) into v_payouts
  from public.investor_transactions
  where tenant_id = p_parent_tenant_id and type = 'profit_payout';

  return jsonb_build_object(
    'investor_capital_in', v_deposits,
    'investor_capital_withdrawn', v_withdrawals,
    'investor_capital_deployed', v_deployed,
    'investor_capital_available', v_deposits - v_withdrawals - v_deployed,
    'customer_ar_due', v_ar_due,
    'customer_ar_paid', v_ar_paid,
    'stock_cost_in_circulation', v_stock_cost,
    'realized_profit_mtd', v_profit_mtd,
    'profit_distributed', v_payouts
  );
end;
$$;

grant execute on function public.get_parent_cash_circulation(bigint) to authenticated;

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
    or exists (
      select 1 from public.investor_accounts ia
      where ia.investor_id = p_investor_id
        and lower(trim(ia.email)) = public.current_user_email()
        and ia.is_active = true
    )
  ) then
    raise exception 'not allowed';
  end if;

  select
    coalesce(sum(case when type = 'deposit' then amount else 0 end), 0),
    coalesce(sum(case when type = 'withdrawal' then amount else 0 end), 0),
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
  v_account public.investor_accounts;
  v_tenant public.tenants;
begin
  select * into v_tenant from public.tenants where id = p_tenant_id;
  if v_tenant.id is null then raise exception 'tenant not found'; end if;

  select * into v_account
  from public.investor_accounts ia
  where ia.tenant_id = p_tenant_id
    and lower(trim(ia.email)) = public.current_user_email()
    and ia.is_active = true
  limit 1;

  if v_account.id is null then
    return jsonb_build_object('authenticated', false, 'tenant', row_to_json(v_tenant));
  end if;

  return jsonb_build_object(
    'authenticated', true,
    'tenant', row_to_json(v_tenant),
    'investor_account', row_to_json(v_account),
    'portfolio', public.get_investor_portfolio_summary(v_account.investor_id),
    'module_keys', (
      select coalesce(jsonb_agg(m.key), '[]'::jsonb)
      from public.tenant_modules tm
      inner join public.modules m on m.id = tm.module_id
      where tm.tenant_id = p_tenant_id
        and tm.is_active = true
        and m.key = 'investor_portal'
    )
  );
end;
$$;

grant execute on function public.get_investor_bootstrap_context(bigint) to authenticated;

create or replace function public.update_shipment_investment_cost_share(
  p_shipment_investment_id bigint,
  p_cost_share_pct numeric
)
returns public.shipment_investments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.shipment_investments;
  v_total numeric(5,2);
begin
  select * into v_row from public.shipment_investments where id = p_shipment_investment_id;
  if v_row.id is null then raise exception 'investment not found'; end if;

  if not public.user_can_manage_parent_tenant(v_row.tenant_id) then
    raise exception 'not allowed';
  end if;

  if p_cost_share_pct < 0 or p_cost_share_pct > 100 then
    raise exception 'cost_share_pct must be between 0 and 100';
  end if;

  select coalesce(sum(cost_share_pct), 0) into v_total
  from public.shipment_investments
  where shipment_id = v_row.shipment_id
    and id <> p_shipment_investment_id
    and cost_share_pct is not null;

  if v_total + p_cost_share_pct > 100 then
    raise exception 'total cost_share_pct cannot exceed 100';
  end if;

  update public.shipment_investments
  set cost_share_pct = p_cost_share_pct
  where id = p_shipment_investment_id
  returning * into v_row;

  perform public.refresh_shipment_investor_profits(v_row.shipment_id);

  return v_row;
end;
$$;

grant execute on function public.update_shipment_investment_cost_share(bigint, numeric) to authenticated;

commit;
