CREATE FUNCTION public.get_investor_dashboard_summary (
  p_tenant_id   bigint,
  p_investor_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.get_investor_dashboard_summary(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.get_investor_dashboard_summary(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_investor_dashboard_summary(bigint, bigint) TO service_role;