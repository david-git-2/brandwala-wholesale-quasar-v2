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
    (v_total_deposit - v_total_withdrawal - v_total_invested_active)
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
