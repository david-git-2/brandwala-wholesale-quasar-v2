begin;

-- Restore get_staff_investor_capital_metrics after IC4 (global_shipment_id only; UWL totals).

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

grant execute on function public.get_staff_investor_capital_metrics(bigint) to authenticated;

commit;
