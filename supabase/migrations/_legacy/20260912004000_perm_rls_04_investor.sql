begin;

-- =========================================================
-- Investor capital domain: RLS + admin RPC guards
-- =========================================================

drop policy if exists investors_select on public.investors;
create policy investors_select on public.investors
for select to authenticated
using (
  public.investor_tenant_can_view(tenant_id)
  or public.auth_investor_id() = id
);

drop policy if exists investor_transactions_select on public.investor_transactions;
create policy investor_transactions_select on public.investor_transactions
for select to authenticated
using (
  public.investor_tenant_can_view(tenant_id)
  or public.auth_investor_id() = investor_id
);

drop policy if exists shipment_investments_select on public.shipment_investments;
create policy shipment_investments_select on public.shipment_investments
for select to authenticated
using (
  public.investor_tenant_can_view(tenant_id)
  or public.auth_investor_id() = investor_id
);

-- Patch admin RPC guards only (bodies unchanged from 20260831000300)
create or replace function public.list_investor_profiles(
  p_tenant_id bigint,
  p_limit int default 50,
  p_offset int default 0,
  p_search text default null
)
returns table (
  id bigint,
  tenant_id bigint,
  name text,
  phone text,
  email text,
  address text,
  is_active boolean,
  currency_code text,
  notes text,
  created_at timestamptz,
  updated_at timestamptz,
  total_capital_in numeric,
  total_withdrawn numeric,
  deployed_capital numeric,
  available_balance numeric,
  total_count bigint
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_total_count bigint;
begin
  if not public.membership_has_module_action(p_tenant_id, 'investor_profiles', 'view') then
    raise exception 'not allowed';
  end if;

  select count(*) into v_total_count
  from public.investors i
  where i.tenant_id = p_tenant_id
    and (p_search is null or i.name ilike '%' || p_search || '%' or i.email ilike '%' || p_search || '%');

  return query
  select
    i.id,
    i.tenant_id,
    i.name,
    i.phone,
    i.email,
    i.address,
    i.is_active,
    i.currency_code,
    i.notes,
    i.created_at,
    i.updated_at,
    coalesce((
      select sum(amount) from public.investor_transactions tx
      where tx.investor_id = i.id
        and tx.type in ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment')
    ), 0.00)::numeric as total_capital_in,
    coalesce((
      select sum(amount) from public.investor_transactions tx
      where tx.investor_id = i.id
        and tx.type in ('withdrawal', 'withdrawal_paid', 'profit_payout')
    ), 0.00)::numeric as total_withdrawn,
    coalesce((
      select sum(allocated_cost) from public.shipment_investments si
      where si.investor_id = i.id and si.status = 'active'
    ), 0.00)::numeric as deployed_capital,
    (
      coalesce((select sum(amount) from public.investor_transactions tx where tx.investor_id = i.id and tx.type in ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment')), 0.00) -
      coalesce((select sum(amount) from public.investor_transactions tx where tx.investor_id = i.id and tx.type in ('withdrawal', 'withdrawal_paid', 'profit_payout')), 0.00) -
      coalesce((select sum(allocated_cost) from public.shipment_investments si where si.investor_id = i.id and si.status = 'active'), 0.00)
    )::numeric as available_balance,
    v_total_count
  from public.investors i
  where i.tenant_id = p_tenant_id
    and (p_search is null or i.name ilike '%' || p_search || '%' or i.email ilike '%' || p_search || '%')
  order by i.name asc
  limit p_limit
  offset p_offset;
end;
$$;

create or replace function public.upsert_investor_profile(
  p_id bigint,
  p_tenant_id bigint,
  p_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_is_active boolean,
  p_currency_code text,
  p_notes text
)
returns public.investors
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.investors;
  v_action text;
begin
  v_action := case when p_id is null then 'create' else 'edit' end;
  if not public.membership_has_module_action(p_tenant_id, 'investor_profiles', v_action) then
    raise exception 'not allowed';
  end if;

  if p_id is not null then
    update public.investors
    set
      name = p_name,
      phone = p_phone,
      email = p_email,
      address = p_address,
      is_active = p_is_active,
      currency_code = p_currency_code,
      notes = p_notes,
      updated_at = now()
    where id = p_id and tenant_id = p_tenant_id
    returning * into v_row;
  else
    insert into public.investors (
      tenant_id, name, phone, email, address, is_active, currency_code, notes
    ) values (
      p_tenant_id, p_name, p_phone, p_email, p_address, p_is_active, p_currency_code, p_notes
    )
    returning * into v_row;
  end if;

  return v_row;
end;
$$;

create or replace function public.record_investor_capital_in(
  p_tenant_id bigint,
  p_investor_id bigint,
  p_amount numeric,
  p_date date,
  p_method public.investor_payment_method,
  p_note text
)
returns public.investor_transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.investor_transactions;
begin
  if not public.membership_has_module_action(p_tenant_id, 'investor_capital_ledger', 'create') then
    raise exception 'not allowed';
  end if;

  insert into public.investor_transactions (
    tenant_id, investor_id, amount, date, method, type, note
  ) values (
    p_tenant_id, p_investor_id, p_amount, p_date, p_method, 'capital_in'::public.investor_transaction_type, p_note
  )
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.record_investor_withdrawal_paid(
  p_tenant_id bigint,
  p_investor_id bigint,
  p_amount numeric,
  p_date date,
  p_method public.investor_payment_method,
  p_note text
)
returns public.investor_transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.investor_transactions;
begin
  if not public.membership_has_module_action(p_tenant_id, 'investor_capital_ledger', 'create') then
    raise exception 'not allowed';
  end if;

  insert into public.investor_transactions (
    tenant_id, investor_id, amount, date, method, type, note
  ) values (
    p_tenant_id, p_investor_id, p_amount, p_date, p_method, 'withdrawal_paid'::public.investor_transaction_type, p_note
  )
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.record_investor_capital_adjustment(
  p_tenant_id bigint,
  p_investor_id bigint,
  p_amount numeric,
  p_date date,
  p_method public.investor_payment_method,
  p_note text
)
returns public.investor_transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.investor_transactions;
begin
  if not public.membership_has_module_action(p_tenant_id, 'investor_capital_ledger', 'edit') then
    raise exception 'not allowed';
  end if;

  insert into public.investor_transactions (
    tenant_id, investor_id, amount, date, method, type, note
  ) values (
    p_tenant_id, p_investor_id, p_amount, p_date, p_method, 'capital_adjustment'::public.investor_transaction_type, p_note
  )
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.upsert_shipment_investment(
  p_id bigint,
  p_tenant_id bigint,
  p_global_shipment_id bigint,
  p_investor_id bigint,
  p_cost_share_pct numeric
)
returns public.shipment_investments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total_cost_share numeric;
  v_row public.shipment_investments;
  v_action text;
begin
  v_action := case when p_id is null then 'create' else 'edit' end;
  if not public.membership_has_module_action(p_tenant_id, 'investor_shipment_share', v_action) then
    raise exception 'not allowed';
  end if;

  if p_cost_share_pct < 0 or p_cost_share_pct > 100 then
    raise exception 'cost share percentage must be between 0 and 100';
  end if;

  select coalesce(sum(cost_share_pct), 0) into v_total_cost_share
  from public.shipment_investments
  where global_shipment_id = p_global_shipment_id
    and status = 'active'
    and (p_id is null or id <> p_id);

  if v_total_cost_share + p_cost_share_pct > 100 then
    raise exception 'total cost share percentage cannot exceed 100%%';
  end if;

  if p_id is not null then
    update public.shipment_investments
    set
      cost_share_pct = p_cost_share_pct,
      updated_at = now()
    where id = p_id and tenant_id = p_tenant_id
    returning * into v_row;
  else
    insert into public.shipment_investments (
      tenant_id, global_shipment_id, investor_id, cost_share_pct, status
    ) values (
      p_tenant_id, p_global_shipment_id, p_investor_id, p_cost_share_pct, 'active'
    )
    returning * into v_row;
  end if;

  perform public.refresh_shipment_investor_profits(p_global_shipment_id);

  select * into v_row from public.shipment_investments where id = v_row.id;

  return v_row;
end;
$$;

create or replace function public.get_investor_capital_report(
  p_tenant_id bigint,
  p_investor_id bigint,
  p_start_date date,
  p_end_date date
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
  v_profit numeric(12,2);
  v_starting_balance numeric(12,2);
  v_ending_balance numeric(12,2);
  v_starting_deposits numeric(12,2);
  v_starting_withdrawals numeric(12,2);
  v_starting_profit numeric(12,2);
begin
  if not (
    public.membership_has_module_action(p_tenant_id, 'investor_reports', 'view')
    or (public.auth_investor_id() = p_investor_id)
  ) then
    raise exception 'not allowed';
  end if;

  select coalesce(sum(amount), 0) into v_deposits
  from public.investor_transactions
  where investor_id = p_investor_id
    and type in ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment')
    and date >= p_start_date and date <= p_end_date;

  select coalesce(sum(amount), 0) into v_withdrawals
  from public.investor_transactions
  where investor_id = p_investor_id
    and type in ('withdrawal', 'withdrawal_paid', 'profit_payout')
    and date >= p_start_date and date <= p_end_date;

  select coalesce(sum(computed_profit), 0) into v_profit
  from public.shipment_investments
  where investor_id = p_investor_id
    and status = 'active'
    and profit_status = 'realized'
    and updated_at::date >= p_start_date and updated_at::date <= p_end_date;

  select coalesce(sum(amount), 0) into v_starting_deposits
  from public.investor_transactions
  where investor_id = p_investor_id
    and type in ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment')
    and date < p_start_date;

  select coalesce(sum(amount), 0) into v_starting_withdrawals
  from public.investor_transactions
  where investor_id = p_investor_id
    and type in ('withdrawal', 'withdrawal_paid', 'profit_payout')
    and date < p_start_date;

  select coalesce(sum(computed_profit), 0) into v_starting_profit
  from public.shipment_investments
  where investor_id = p_investor_id
    and status = 'active'
    and profit_status = 'realized'
    and updated_at::date < p_start_date;

  v_starting_balance := v_starting_deposits + v_starting_profit - v_starting_withdrawals;
  v_ending_balance := v_starting_balance + v_deposits + v_profit - v_withdrawals;

  return jsonb_build_object(
    'investor_id', p_investor_id,
    'start_date', p_start_date,
    'end_date', p_end_date,
    'starting_balance', v_starting_balance,
    'deposits_sum', v_deposits,
    'withdrawals_sum', v_withdrawals,
    'profit_earned_sum', v_profit,
    'ending_balance', v_ending_balance
  );
end;
$$;

commit;
