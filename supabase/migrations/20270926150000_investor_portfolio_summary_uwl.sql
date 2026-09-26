begin;

-- IC4 dropped investor_transactions; get_investor_portfolio_summary still referenced it.

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
  v_deposits numeric(12,2) := 0;
  v_withdrawals numeric(12,2) := 0;
  v_deployed numeric(12,2) := 0;
  v_payouts numeric(12,2) := 0;
  v_realized_profit numeric(12,2) := 0;
  v_unrealized_profit numeric(12,2) := 0;
  v_wallet_available numeric(12,2) := 0;
  v_currency text := 'BDT';
begin
  select * into v_investor from public.investors where id = p_investor_id;
  if v_investor.id is null then
    raise exception 'investor not found';
  end if;

  if not (
    public.user_can_manage_parent_tenant(v_investor.tenant_id)
    or (public.auth_investor_id() = p_investor_id)
  ) then
    raise exception 'not allowed';
  end if;

  v_currency := coalesce(nullif(trim(v_investor.currency_code), ''), 'BDT');

  v_deposits := public.investor_uwl_flow_total(v_investor.tenant_id, p_investor_id, 'in');
  v_withdrawals := public.investor_uwl_flow_total(v_investor.tenant_id, p_investor_id, 'out');

  select coalesce(sum(si.allocated_cost), 0) into v_deployed
  from public.shipment_investments si
  where si.investor_id = p_investor_id and si.status = 'active';

  select
    coalesce(sum(case when si.profit_status = 'realized' then si.computed_profit else 0 end), 0),
    coalesce(sum(case when si.profit_status in ('open', 'partial') then si.computed_profit else 0 end), 0)
  into v_realized_profit, v_unrealized_profit
  from public.shipment_investments si
  where si.investor_id = p_investor_id and si.status = 'active';

  select coalesce((
    public.get_wallet_account_balances(v_investor.tenant_id, 'investor', p_investor_id, v_currency)
      ->> 'available_balance'
  )::numeric, 0) into v_wallet_available;

  return jsonb_build_object(
    'investor', row_to_json(v_investor),
    'balances', jsonb_build_object(
      'deposits', v_deposits,
      'withdrawals', v_withdrawals,
      'deployed', v_deployed,
      'available', v_wallet_available - v_deployed,
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

commit;
