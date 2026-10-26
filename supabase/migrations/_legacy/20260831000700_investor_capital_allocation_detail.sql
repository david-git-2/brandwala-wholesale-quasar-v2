begin;

-- =========================================================
-- Create get_investor_allocation_detail RPC (Track A0)
-- =========================================================
create or replace function public.get_investor_allocation_detail(
  p_tenant_id bigint,
  p_investor_id bigint,
  p_global_shipment_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_shipment record;
  v_investment record;
  v_pnl jsonb;
begin
  if not (
    public.user_can_manage_parent_tenant(p_tenant_id)
    or (public.auth_investor_id() = p_investor_id)
  ) then
    raise exception 'not allowed';
  end if;

  select * into v_shipment
  from public.global_shipments
  where id = p_global_shipment_id;

  if not found then
    return null;
  end if;

  select * into v_investment
  from public.shipment_investments
  where investor_id = p_investor_id
    and global_shipment_id = p_global_shipment_id
    and status = 'active';

  if not found then
    return null;
  end if;

  v_pnl := public.get_shipment_pnl(p_tenant_id, p_global_shipment_id);

  return jsonb_build_object(
    'id', v_investment.id,
    'global_shipment_id', v_investment.global_shipment_id,
    'shipment_name', v_shipment.name,
    'shipment_status', v_shipment.status,
    'cost_share_pct', v_investment.cost_share_pct,
    'allocated_cost', v_investment.allocated_cost,
    'computed_profit', v_investment.computed_profit,
    'profit_status', v_investment.profit_status,
    'created_at', v_investment.created_at,
    'invested_amount', v_investment.invested_amount,
    'total_landed_cost', coalesce((v_pnl -> 'totals' ->> 'landed_cost')::numeric, 0.00),
    'realized_revenue', coalesce((v_pnl -> 'totals' ->> 'revenue')::numeric, 0.00),
    'gross_profit', coalesce((v_pnl -> 'totals' ->> 'gross_profit')::numeric, 0.00),
    'unsold_value', coalesce((v_pnl -> 'totals' ->> 'unsold_value')::numeric, 0.00)
  );
end;
$$;

grant execute on function public.get_investor_allocation_detail(bigint, bigint, bigint) to authenticated;

commit;
