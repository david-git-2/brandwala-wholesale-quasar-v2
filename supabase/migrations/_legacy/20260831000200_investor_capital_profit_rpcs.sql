begin;

-- =========================================================
-- 1. Rewrite refresh_shipment_investor_profits (Phase 3)
-- =========================================================
-- Parameter was renamed from p_shipment_id; CREATE OR REPLACE cannot do that.
drop function if exists public.refresh_shipment_investor_profits(bigint);

create or replace function public.refresh_shipment_investor_profits(
  p_global_shipment_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shipment public.global_shipments;
  v_pnl jsonb;
  v_buy numeric(12,2);
  v_profit numeric(12,2);
  v_updated integer := 0;
  v_inv record;
  v_status text;
  v_sold_qty numeric;
  v_received_qty numeric;
begin
  select * into v_shipment from public.global_shipments where id = p_global_shipment_id;
  if v_shipment.id is null then raise exception 'global shipment not found'; end if;

  if not public.user_can_manage_parent_tenant(v_shipment.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  -- Fetch operational P&L from treasury
  v_pnl := public.get_shipment_pnl(v_shipment.parent_tenant_id, p_global_shipment_id);
  v_buy := coalesce((v_pnl -> 'totals' ->> 'landed_cost')::numeric, 0.00);
  v_profit := coalesce((v_pnl -> 'totals' ->> 'gross_profit')::numeric, 0.00);

  -- Determine status based on sold vs received qty
  select
    coalesce(sum(ordered_quantity), 0),
    coalesce(sum(sold_qty), 0)
  into v_received_qty, v_sold_qty
  from (
    select
      si.ordered_quantity,
      coalesce(sum(ii.quantity - ii.return_quantity), 0) as sold_qty
    from public.global_shipment_items si
    left join public.global_invoice_items ii on ii.shipment_item_id = si.id
    left join public.global_invoices inv on inv.id = ii.invoice_id and inv.invoice_status = 'posted'::public.global_invoice_status
    where si.shipment_id = p_global_shipment_id
    group by si.id, si.ordered_quantity
  ) t;

  if v_received_qty = 0 then
    v_status := 'open';
  elsif v_sold_qty >= v_received_qty then
    v_status := 'realized';
  elsif v_sold_qty > 0 then
    v_status := 'partial';
  else
    v_status := 'open';
  end if;

  -- Update active investments
  for v_inv in
    select * from public.shipment_investments
    where global_shipment_id = p_global_shipment_id
      and status = 'active'
      and cost_share_pct is not null
  loop
    update public.shipment_investments
    set
      allocated_cost = round(v_buy * cost_share_pct / 100.0, 2),
      computed_profit = round(v_profit * cost_share_pct / 100.0, 2),
      profit_status = v_status
    where id = v_inv.id;

    v_updated := v_updated + 1;
  end loop;

  return jsonb_build_object(
    'global_shipment_id', p_global_shipment_id,
    'updated_count', v_updated,
    'buy_cost_total', v_buy,
    'profit_total', v_profit,
    'profit_status', v_status
  );
end;
$$;

grant execute on function public.refresh_shipment_investor_profits(bigint) to authenticated;

-- =========================================================
-- 2. Refine get_investor_portfolio_summary
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
  v_realized_profit numeric(12,2);
  v_unrealized_profit numeric(12,2);
begin
  select * into v_investor from public.investors where id = p_investor_id;
  if v_investor.id is null then raise exception 'investor not found'; end if;

  if not (
    public.user_can_manage_parent_tenant(v_investor.tenant_id)
    or (public.auth_investor_id() = p_investor_id)
  ) then
    raise exception 'not allowed';
  end if;

  -- Total capital in including adjustments
  select coalesce(sum(amount), 0) into v_deposits
  from public.investor_transactions
  where investor_id = p_investor_id
    and type in ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment');

  -- Total withdrawals
  select coalesce(sum(amount), 0) into v_withdrawals
  from public.investor_transactions
  where investor_id = p_investor_id
    and type in ('withdrawal', 'withdrawal_paid', 'profit_payout');

  -- Legacy payouts field (for compatibility if needed)
  select coalesce(sum(amount), 0) into v_payouts
  from public.investor_transactions
  where investor_id = p_investor_id
    and type = 'profit_payout';

  -- Deployed capital
  select coalesce(sum(allocated_cost), 0) into v_deployed
  from public.shipment_investments
  where investor_id = p_investor_id and status = 'active';

  -- Realized & Unrealized profits
  select
    coalesce(sum(case when profit_status = 'realized' then computed_profit else 0 end), 0),
    coalesce(sum(case when profit_status in ('open', 'partial') then computed_profit else 0 end), 0)
  into v_realized_profit, v_unrealized_profit
  from public.shipment_investments
  where investor_id = p_investor_id and status = 'active';

  return jsonb_build_object(
    'investor', row_to_json(v_investor),
    'balances', jsonb_build_object(
      'deposits', v_deposits,
      'withdrawals', v_withdrawals,
      'deployed', v_deployed,
      'available', v_deposits - v_withdrawals - v_deployed,
      'payouts', v_payouts,
      'realized_profit', v_realized_profit,
      'unrealized_profit', v_unrealized_profit,
      'withdrawable_balance', v_realized_profit - v_withdrawals
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

-- =========================================================
-- 3. New get_investor_dashboard_summary
-- =========================================================
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
  v_withdrawable_balance numeric(12,2) := 0;
begin
  if not (
    public.user_can_manage_parent_tenant(p_tenant_id)
    or (public.auth_investor_id() = p_investor_id)
  ) then
    raise exception 'not allowed';
  end if;

  select coalesce(sum(amount), 0) into v_total_capital_in
  from public.investor_transactions
  where investor_id = p_investor_id
    and type in ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment');

  select coalesce(sum(amount), 0) into v_total_withdrawn
  from public.investor_transactions
  where investor_id = p_investor_id
    and type in ('withdrawal', 'withdrawal_paid', 'profit_payout');

  select coalesce(sum(allocated_cost), 0) into v_deployed_capital
  from public.shipment_investments
  where investor_id = p_investor_id
    and status = 'active';

  select
    coalesce(sum(case when profit_status = 'realized' then computed_profit else 0 end), 0),
    coalesce(sum(case when profit_status in ('open', 'partial') then computed_profit else 0 end), 0)
  into v_realized_profit, v_unrealized_profit
  from public.shipment_investments
  where investor_id = p_investor_id
    and status = 'active';

  v_withdrawable_balance := v_realized_profit - v_total_withdrawn;

  return jsonb_build_object(
    'total_capital_in', v_total_capital_in,
    'deployed_capital', v_deployed_capital,
    'unallocated_cash', v_total_capital_in - v_total_withdrawn - v_deployed_capital,
    'realized_profit', v_realized_profit,
    'unrealized_profit', v_unrealized_profit,
    'withdrawable_balance', v_withdrawable_balance,
    'total_withdrawn', v_total_withdrawn
  );
end;
$$;

grant execute on function public.get_investor_dashboard_summary(bigint, bigint) to authenticated;

-- =========================================================
-- 4. New list_investor_allocations
-- =========================================================
create or replace function public.list_investor_allocations(
  p_tenant_id bigint,
  p_investor_id bigint,
  p_limit int default 50,
  p_offset int default 0
)
returns table (
  id bigint,
  global_shipment_id bigint,
  shipment_name text,
  shipment_status text,
  cost_share_pct numeric,
  allocated_cost numeric,
  computed_profit numeric,
  profit_status text,
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
    or (public.auth_investor_id() = p_investor_id)
  ) then
    raise exception 'not allowed';
  end if;

  select count(*) into v_total_count
  from public.shipment_investments si
  where si.investor_id = p_investor_id
    and si.status = 'active';

  return query
  select
    si.id,
    si.global_shipment_id,
    gs.name as shipment_name,
    gs.status as shipment_status,
    si.cost_share_pct::numeric,
    si.allocated_cost::numeric,
    si.computed_profit::numeric,
    si.profit_status,
    si.created_at,
    v_total_count
  from public.shipment_investments si
  left join public.global_shipments gs on gs.id = si.global_shipment_id
  where si.investor_id = p_investor_id
    and si.status = 'active'
  order by si.created_at desc
  limit p_limit
  offset p_offset;
end;
$$;

grant execute on function public.list_investor_allocations(bigint, bigint, int, int) to authenticated;

-- =========================================================
-- 5. New list_investor_transactions
-- =========================================================
create or replace function public.list_investor_transactions(
  p_tenant_id bigint,
  p_investor_id bigint,
  p_limit int default 50,
  p_offset int default 0
)
returns table (
  id bigint,
  amount numeric,
  date date,
  method public.investor_payment_method,
  type public.investor_transaction_type,
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
    or (public.auth_investor_id() = p_investor_id)
  ) then
    raise exception 'not allowed';
  end if;

  select count(*) into v_total_count
  from public.investor_transactions tx
  where tx.investor_id = p_investor_id;

  return query
  select
    tx.id,
    tx.amount::numeric,
    tx.date,
    tx.method,
    tx.type,
    tx.note,
    tx.created_at,
    v_total_count
  from public.investor_transactions tx
  where tx.investor_id = p_investor_id
  order by tx.date desc, tx.created_at desc
  limit p_limit
  offset p_offset;
end;
$$;

grant execute on function public.list_investor_transactions(bigint, bigint, int, int) to authenticated;

commit;
