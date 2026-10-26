-- Retire investor_transactions + investor_balances; wallet is cash source of truth.
-- Drop shipment_investments.shipment_id (legacy shipments FK).

begin;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.investor_uwl_flow_total(
  p_tenant_id bigint,
  p_investor_id bigint,
  p_flow text
)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(abs(uwl.amount)), 0)::numeric(12,2)
  from public.universal_wallet_ledger uwl
  inner join public.investors i on i.id = uwl.entity_id
  where i.tenant_id = p_tenant_id
    and uwl.entity_type = 'investor'
    and (p_investor_id is null or uwl.entity_id = p_investor_id)
    and coalesce(uwl.metadata->>'section', '') = 'investor_capital'
    and (
      (
        p_flow = 'in'
        and uwl.type = 'credit'
        and coalesce(uwl.metadata->>'transaction_type', '') in (
          'capital_in', 'capital_adjustment', 'manual_adjustment', 'deposit'
        )
      )
      or (
        p_flow = 'out'
        and uwl.type = 'debit'
        and coalesce(uwl.metadata->>'transaction_type', '') in (
          'withdrawal_paid', 'withdrawal', 'profit_payout'
        )
      )
    );
$$;

create or replace function public.investor_uwl_flow_total_range(
  p_tenant_id bigint,
  p_investor_id bigint,
  p_flow text,
  p_start_date date,
  p_end_date date
)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(abs(uwl.amount)), 0)::numeric(12,2)
  from public.universal_wallet_ledger uwl
  inner join public.investors i on i.id = uwl.entity_id
  where i.tenant_id = p_tenant_id
    and uwl.entity_id = p_investor_id
    and uwl.entity_type = 'investor'
    and coalesce(uwl.metadata->>'section', '') = 'investor_capital'
    and uwl.created_at::date >= p_start_date
    and uwl.created_at::date <= p_end_date
    and (
      (
        p_flow = 'in'
        and uwl.type = 'credit'
        and coalesce(uwl.metadata->>'transaction_type', '') in (
          'capital_in', 'capital_adjustment', 'manual_adjustment', 'deposit'
        )
      )
      or (
        p_flow = 'out'
        and uwl.type = 'debit'
        and coalesce(uwl.metadata->>'transaction_type', '') in (
          'withdrawal_paid', 'withdrawal', 'profit_payout'
        )
      )
    );
$$;

-- ---------------------------------------------------------------------------
-- Write RPCs (jsonb; wallet only)
-- ---------------------------------------------------------------------------
drop function if exists public.record_investor_capital_in(
  bigint, bigint, numeric, date, public.investor_payment_method, text
);
drop function if exists public.record_investor_withdrawal_paid(
  bigint, bigint, numeric, date, public.investor_payment_method, text
);
drop function if exists public.record_investor_capital_adjustment(
  bigint, bigint, numeric, date, public.investor_payment_method, text
);

create or replace function public.record_investor_capital_in(
  p_tenant_id bigint,
  p_investor_id bigint,
  p_amount numeric,
  p_date date,
  p_method public.investor_payment_method,
  p_note text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source_id text := gen_random_uuid()::text;
  v_currency text := 'BDT';
begin
  if not public.membership_has_module_action(p_tenant_id, 'investor_capital_ledger', 'create') then
    raise exception 'not allowed';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'amount must be positive';
  end if;

  select coalesce(i.currency_code, 'BDT') into v_currency
  from public.investors i
  where i.id = p_investor_id and i.tenant_id = p_tenant_id;

  if not found then
    raise exception 'investor not found';
  end if;

  perform public.record_ledger_transaction(
    p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => p_tenant_id,
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => v_currency,
    p_exchange_rate => 1.000000,
    p_source_type => 'adjustment',
    p_source_id => v_source_id,
    p_metadata => jsonb_build_object(
      'section', 'investor_capital',
      'purpose', 'capital_in_tenant_cash',
      'transaction_type', 'capital_in',
      'label', 'Capital In Deposit',
      'investor_id', p_investor_id,
      'method', p_method,
      'date', p_date,
      'notes', p_note
    )
  );

  perform public.record_ledger_transaction(
    p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'investor',
    p_entity_id => p_investor_id,
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => v_currency,
    p_exchange_rate => 1.000000,
    p_source_type => 'adjustment',
    p_source_id => v_source_id,
    p_metadata => jsonb_build_object(
      'section', 'investor_capital',
      'purpose', 'capital_in_investor_liability',
      'transaction_type', 'capital_in',
      'label', 'Capital Injected',
      'method', p_method,
      'date', p_date,
      'notes', p_note
    )
  );

  return jsonb_build_object(
    'ok', true,
    'source_id', v_source_id,
    'tenant_id', p_tenant_id,
    'investor_id', p_investor_id,
    'amount', p_amount,
    'date', p_date,
    'method', p_method,
    'transaction_type', 'capital_in',
    'note', p_note
  );
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
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source_id text := gen_random_uuid()::text;
  v_currency text := 'BDT';
begin
  if not public.membership_has_module_action(p_tenant_id, 'investor_capital_ledger', 'create') then
    raise exception 'not allowed';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'amount must be positive';
  end if;

  select coalesce(i.currency_code, 'BDT') into v_currency
  from public.investors i
  where i.id = p_investor_id and i.tenant_id = p_tenant_id;

  if not found then
    raise exception 'investor not found';
  end if;

  perform public.record_ledger_transaction(
    p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'investor',
    p_entity_id => p_investor_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => v_currency,
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_source_id,
    p_metadata => jsonb_build_object(
      'section', 'investor_capital',
      'purpose', 'investor_withdrawal_debit',
      'transaction_type', 'withdrawal_paid',
      'label', 'Capital Withdrawal Paid',
      'method', p_method,
      'date', p_date,
      'notes', p_note
    )
  );

  perform public.record_ledger_transaction(
    p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => p_tenant_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => v_currency,
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_source_id,
    p_metadata => jsonb_build_object(
      'section', 'investor_capital',
      'purpose', 'tenant_investor_cash_outflow',
      'transaction_type', 'withdrawal_paid',
      'label', 'Investor Withdrawal Outflow',
      'investor_id', p_investor_id,
      'method', p_method,
      'date', p_date,
      'notes', p_note
    )
  );

  return jsonb_build_object(
    'ok', true,
    'source_id', v_source_id,
    'tenant_id', p_tenant_id,
    'investor_id', p_investor_id,
    'amount', p_amount,
    'date', p_date,
    'method', p_method,
    'transaction_type', 'withdrawal_paid',
    'note', p_note
  );
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
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_source_id text := gen_random_uuid()::text;
  v_currency text := 'BDT';
  v_abs numeric(12,2);
begin
  if not public.membership_has_module_action(p_tenant_id, 'investor_capital_ledger', 'edit') then
    raise exception 'not allowed';
  end if;

  if p_amount is null or p_amount = 0 then
    raise exception 'amount must be non-zero';
  end if;

  v_abs := abs(p_amount);

  select coalesce(i.currency_code, 'BDT') into v_currency
  from public.investors i
  where i.id = p_investor_id and i.tenant_id = p_tenant_id;

  if not found then
    raise exception 'investor not found';
  end if;

  if p_amount > 0 then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'investor',
      p_entity_id => p_investor_id,
      p_type => 'credit',
      p_amount => v_abs,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'adjustment',
      p_source_id => v_source_id,
      p_metadata => jsonb_build_object(
        'section', 'investor_capital',
        'transaction_type', 'capital_adjustment',
        'method', p_method,
        'date', p_date,
        'notes', p_note
      )
    );
  else
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'investor',
      p_entity_id => p_investor_id,
      p_type => 'debit',
      p_amount => v_abs,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'adjustment',
      p_source_id => v_source_id,
      p_metadata => jsonb_build_object(
        'section', 'investor_capital',
        'transaction_type', 'capital_adjustment',
        'method', p_method,
        'date', p_date,
        'notes', p_note
      )
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'source_id', v_source_id,
    'tenant_id', p_tenant_id,
    'investor_id', p_investor_id,
    'amount', p_amount,
    'date', p_date,
    'method', p_method,
    'transaction_type', 'capital_adjustment',
    'note', p_note
  );
end;
$$;

grant execute on function public.record_investor_capital_in(
  bigint, bigint, numeric, date, public.investor_payment_method, text
) to authenticated, service_role;
grant execute on function public.record_investor_withdrawal_paid(
  bigint, bigint, numeric, date, public.investor_payment_method, text
) to authenticated, service_role;
grant execute on function public.record_investor_capital_adjustment(
  bigint, bigint, numeric, date, public.investor_payment_method, text
) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Read / aggregate RPCs
-- ---------------------------------------------------------------------------
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
    public.investor_uwl_flow_total(p_tenant_id, i.id, 'in') as total_capital_in,
    public.investor_uwl_flow_total(p_tenant_id, i.id, 'out') as total_withdrawn,
    coalesce((
      select sum(si.allocated_cost)
      from public.shipment_investments si
      where si.investor_id = i.id and si.status = 'active'
    ), 0.00)::numeric as deployed_capital,
    (
      coalesce((
        public.get_wallet_account_balances(p_tenant_id, 'investor', i.id, i.currency_code)
          ->> 'available_balance'
      )::numeric, 0.00)
      - coalesce((
        select sum(si.allocated_cost)
        from public.shipment_investments si
        where si.investor_id = i.id and si.status = 'active'
      ), 0.00)
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

create or replace function public.get_investor_dashboard_summary(
  p_tenant_id bigint,
  p_investor_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_total_capital_in numeric(12,2) := 0;
  v_total_withdrawn numeric(12,2) := 0;
  v_deployed_capital numeric(12,2) := 0;
  v_realized_profit numeric(12,2) := 0;
  v_unrealized_profit numeric(12,2) := 0;
  v_wallet_available numeric(12,2) := 0;
begin
  if not (
    public.user_can_manage_parent_tenant(p_tenant_id)
    or (public.auth_investor_id() = p_investor_id)
  ) then
    raise exception 'not allowed';
  end if;

  v_total_capital_in := public.investor_uwl_flow_total(p_tenant_id, p_investor_id, 'in');
  v_total_withdrawn := public.investor_uwl_flow_total(p_tenant_id, p_investor_id, 'out');

  select coalesce(sum(si.allocated_cost), 0) into v_deployed_capital
  from public.shipment_investments si
  where si.investor_id = p_investor_id and si.status = 'active';

  select
    coalesce(sum(case when si.profit_status = 'realized' then si.computed_profit else 0 end), 0),
    coalesce(sum(case when si.profit_status in ('open', 'partial') then si.computed_profit else 0 end), 0)
  into v_realized_profit, v_unrealized_profit
  from public.shipment_investments si
  where si.investor_id = p_investor_id and si.status = 'active';

  select coalesce((
    public.get_wallet_account_balances(p_tenant_id, 'investor', p_investor_id, 'BDT')
      ->> 'available_balance'
  )::numeric, 0) into v_wallet_available;

  return jsonb_build_object(
    'total_capital_in', v_total_capital_in,
    'deployed_capital', v_deployed_capital,
    'unallocated_cash', v_wallet_available - v_deployed_capital,
    'realized_profit', v_realized_profit,
    'unrealized_profit', v_unrealized_profit,
    'withdrawable_balance', v_realized_profit - v_total_withdrawn,
    'total_withdrawn', v_total_withdrawn
  );
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

  v_deposits := public.investor_uwl_flow_total_range(p_tenant_id, p_investor_id, 'in', p_start_date, p_end_date);
  v_withdrawals := public.investor_uwl_flow_total_range(p_tenant_id, p_investor_id, 'out', p_start_date, p_end_date);

  select coalesce(sum(si.computed_profit), 0) into v_profit
  from public.shipment_investments si
  where si.investor_id = p_investor_id
    and si.status = 'active'
    and si.profit_status = 'realized'
    and si.updated_at::date >= p_start_date and si.updated_at::date <= p_end_date;

  v_starting_deposits := public.investor_uwl_flow_total_range(
    p_tenant_id, p_investor_id, 'in', '1970-01-01'::date, p_start_date - 1
  );
  v_starting_withdrawals := public.investor_uwl_flow_total_range(
    p_tenant_id, p_investor_id, 'out', '1970-01-01'::date, p_start_date - 1
  );

  select coalesce(sum(si.computed_profit), 0) into v_starting_profit
  from public.shipment_investments si
  where si.investor_id = p_investor_id
    and si.status = 'active'
    and si.profit_status = 'realized'
    and si.updated_at::date < p_start_date;

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

drop function if exists public.list_investor_transactions(bigint, bigint, int, int);

create or replace function public.list_investor_wallet_activity(
  p_tenant_id bigint,
  p_investor_id bigint,
  p_limit int default 50,
  p_offset int default 0
)
returns table (
  id text,
  amount numeric,
  activity_date date,
  method public.investor_payment_method,
  transaction_type text,
  note text,
  created_at timestamptz,
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
  if not (
    public.user_can_manage_parent_tenant(p_tenant_id)
    or (p_investor_id is not null and public.auth_investor_id() = p_investor_id)
  ) then
    raise exception 'not allowed';
  end if;

  select count(*) into v_total_count
  from public.universal_wallet_ledger uwl
  inner join public.investors i on i.id = uwl.entity_id
  where i.tenant_id = p_tenant_id
    and uwl.entity_type = 'investor'
    and (p_investor_id is null or uwl.entity_id = p_investor_id)
    and coalesce(uwl.metadata->>'section', '') = 'investor_capital';

  return query
  select
    uwl.id::text,
    abs(uwl.amount)::numeric,
    uwl.created_at::date as activity_date,
    coalesce(nullif(uwl.metadata->>'method', ''), 'other')::public.investor_payment_method,
    coalesce(uwl.metadata->>'transaction_type', 'manual_adjustment'),
    coalesce(uwl.metadata->>'notes', uwl.metadata->>'note'),
    uwl.created_at,
    v_total_count
  from public.universal_wallet_ledger uwl
  inner join public.investors i on i.id = uwl.entity_id
  where i.tenant_id = p_tenant_id
    and uwl.entity_type = 'investor'
    and (p_investor_id is null or uwl.entity_id = p_investor_id)
    and coalesce(uwl.metadata->>'section', '') = 'investor_capital'
  order by uwl.created_at desc
  limit p_limit
  offset p_offset;
end;
$$;

grant execute on function public.list_investor_wallet_activity(bigint, bigint, int, int) to authenticated;

create or replace function public.get_staff_investor_capital_metrics(p_tenant_id bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_books_id bigint;
  v_month_start timestamptz;
  v_capital_in numeric := 0;
  v_withdrawn numeric := 0;
  v_deployed numeric := 0;
  v_deployed_month numeric := 0;
  v_realized numeric := 0;
  v_open_count bigint := 0;
  v_containers jsonb := '[]'::jsonb;
begin
  if not public.membership_has_module_action(p_tenant_id, 'investor_capital_ledger', 'view') then
    raise exception 'not allowed';
  end if;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_month_start := date_trunc('month', timezone('Asia/Dhaka', now()));

  v_capital_in := public.investor_uwl_flow_total(v_books_id, null, 'in');
  v_withdrawn := public.investor_uwl_flow_total(v_books_id, null, 'out');

  select
    coalesce(sum(si.allocated_cost), 0),
    coalesce(sum(si.allocated_cost) filter (where si.created_at >= v_month_start), 0),
    coalesce(sum(si.computed_profit) filter (where si.profit_status = 'realized'), 0),
    count(distinct si.global_shipment_id)
      filter (where si.status = 'active'::public.shipment_investment_status)
  into v_deployed, v_deployed_month, v_realized, v_open_count
  from public.shipment_investments si
  where si.tenant_id = v_books_id
    and si.status = 'active'::public.shipment_investment_status;

  select coalesce(jsonb_agg(row_to_json(c)), '[]'::jsonb)
  into v_containers
  from (
    select
      coalesce(gs.name, 'Unnamed batch') as name,
      round(sum(si.allocated_cost), 2) as allocated_cost
    from public.shipment_investments si
    left join public.global_shipments gs on gs.id = si.global_shipment_id
    where si.tenant_id = v_books_id
      and si.status = 'active'::public.shipment_investment_status
    group by coalesce(gs.name, 'Unnamed batch')
    order by sum(si.allocated_cost) desc
    limit 5
  ) c;

  return jsonb_build_object(
    'tenant_id', v_books_id,
    'active_pool_amount', round(v_capital_in - v_withdrawn, 2),
    'deployed_amount', round(v_deployed, 2),
    'deployed_this_month', round(v_deployed_month, 2),
    'due_to_investors', round(greatest(v_realized - v_withdrawn, 0), 2),
    'returned_amount', round(v_withdrawn, 2),
    'open_container_count', v_open_count,
    'open_containers', v_containers
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Drop legacy balance sync + journal tables
-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- Drop legacy balance sync + journal tables
-- ---------------------------------------------------------------------------
do $$
begin
  if to_regclass('public.investor_transactions') is not null then
    drop trigger if exists trg_sync_investor_balance_transactions on public.investor_transactions;
    drop trigger if exists trg_investor_transactions_set_updated_at on public.investor_transactions;
  end if;

  drop trigger if exists trg_sync_investor_balance_shipments on public.shipment_investments;
  drop trigger if exists trg_sync_investor_balance_investors on public.investors;

  if to_regclass('public.investor_balances') is not null then
    drop trigger if exists trg_investor_balances_set_updated_at on public.investor_balances;
  end if;
end $$;

drop function if exists public.sync_investor_balance_from_transactions() cascade;
drop function if exists public.sync_investor_balance_from_shipment_investments() cascade;
drop function if exists public.sync_investor_balance_from_investors() cascade;
drop function if exists public.refresh_investor_balance(bigint, bigint) cascade;

do $$
begin
  if to_regclass('public.investor_transactions') is not null then
    drop policy if exists investor_transactions_select on public.investor_transactions;
    drop policy if exists investor_transactions_insert on public.investor_transactions;
    drop policy if exists investor_transactions_update on public.investor_transactions;
    drop policy if exists investor_transactions_delete on public.investor_transactions;
  end if;

  if to_regclass('public.investor_balances') is not null then
    drop policy if exists investor_balances_select on public.investor_balances;
    drop policy if exists investor_balances_insert on public.investor_balances;
    drop policy if exists investor_balances_update on public.investor_balances;
    drop policy if exists investor_balances_delete on public.investor_balances;
  end if;
end $$;

drop table if exists public.investor_balances cascade;
drop table if exists public.investor_transactions cascade;

-- ---------------------------------------------------------------------------
-- shipment_investments: drop legacy shipment_id
-- ---------------------------------------------------------------------------
do $$
declare
  v_null_global bigint;
begin
  select count(*) into v_null_global
  from public.shipment_investments
  where global_shipment_id is null;

  if v_null_global > 0 then
    raise exception 'shipment_investments rows missing global_shipment_id: %', v_null_global;
  end if;
end $$;

alter table if exists public.shipment_investments
  drop constraint if exists shipment_investments_shipment_id_fkey;

drop index if exists public.shipment_investments_shipment_id_idx;

alter table if exists public.shipment_investments
  drop column if exists shipment_id;

alter table if exists public.shipment_investments
  alter column global_shipment_id set not null;

create unique index if not exists shipment_investments_tenant_investor_global_shipment_key
  on public.shipment_investments (tenant_id, investor_id, global_shipment_id);

commit;
