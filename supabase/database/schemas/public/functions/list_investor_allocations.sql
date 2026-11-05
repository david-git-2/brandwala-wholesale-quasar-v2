CREATE FUNCTION public.list_investor_allocations (
  p_tenant_id   bigint,
  p_investor_id bigint,
  p_limit       integer DEFAULT 50,
  p_offset      integer DEFAULT 0
)
  RETURNS TABLE (
    id                 bigint,
    global_shipment_id bigint,
    shipment_name      text,
    shipment_status    text,
    cost_share_pct     numeric,
    allocated_cost     numeric,
    computed_profit    numeric,
    profit_status      text,
    created_at         timestamp with time zone,
    total_count        bigint
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.list_investor_allocations(bigint, bigint, integer, integer) TO anon;

GRANT ALL ON FUNCTION public.list_investor_allocations(bigint, bigint, integer, integer) TO authenticated;

GRANT ALL ON FUNCTION public.list_investor_allocations(bigint, bigint, integer, integer) TO service_role;