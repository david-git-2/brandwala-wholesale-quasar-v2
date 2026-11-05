CREATE FUNCTION public.get_investor_capital_report (
  p_tenant_id   bigint,
  p_investor_id bigint,
  p_start_date  date,
  p_end_date    date
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.get_investor_capital_report(bigint, bigint, date, date) TO anon;

GRANT ALL ON FUNCTION public.get_investor_capital_report(bigint, bigint, date, date) TO authenticated;

GRANT ALL ON FUNCTION public.get_investor_capital_report(bigint, bigint, date, date) TO service_role;