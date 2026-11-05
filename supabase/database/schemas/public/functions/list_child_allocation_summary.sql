CREATE FUNCTION public.list_child_allocation_summary (
  p_stock_id bigint
)
  RETURNS TABLE (
    child_tenant_id   bigint,
    child_tenant_name text,
    allocation_id     bigint,
    allocated_qty     integer
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  return query
  select
    t.id as child_tenant_id,
    t.name as child_tenant_name,
    coalesce(gsa.id, 0)::bigint as allocation_id,
    coalesce(gsa.quantity, 0)::integer as allocated_qty
  from public.tenants t
  left join public.global_stock_allocations gsa on gsa.child_tenant_id = t.id and gsa.stock_id = p_stock_id
  where t.parent_id = (select parent_tenant_id from public.global_stocks where id = p_stock_id)
  order by t.name asc;
end;
$function$;

GRANT ALL ON FUNCTION public.list_child_allocation_summary(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_child_allocation_summary(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_child_allocation_summary(bigint) TO service_role;