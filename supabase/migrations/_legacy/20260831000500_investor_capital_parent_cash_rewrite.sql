begin;

-- =========================================================
-- Rewrite get_parent_cash_circulation (Phase 7)
-- =========================================================
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

  -- Aligned capital deposit & adjustment types
  select
    coalesce(sum(case when type in ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment') then amount else 0 end), 0),
    coalesce(sum(case when type in ('withdrawal', 'withdrawal_paid') then amount else 0 end), 0)
  into v_deposits, v_withdrawals
  from public.investor_transactions it
  where it.tenant_id = p_parent_tenant_id;

  -- Use allocated_cost / invested_amount
  select coalesce(sum(coalesce(allocated_cost, invested_amount)), 0) into v_deployed
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

  -- Aligned profit payouts
  select coalesce(sum(amount), 0) into v_payouts
  from public.investor_transactions
  where tenant_id = p_parent_tenant_id
    and type in ('profit_payout', 'profit_reinvest');

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

commit;
