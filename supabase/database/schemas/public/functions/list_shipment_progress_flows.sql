CREATE FUNCTION public.list_shipment_progress_flows (
  p_tenant_id        bigint,
  p_include_archived boolean DEFAULT false
)
  RETURNS TABLE (
    id          bigint,
    tenant_id   bigint,
    name        text,
    slug        text,
    is_active   boolean,
    is_default  boolean,
    created_at  timestamp with time zone,
    stage_count bigint
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  return query
  select
    f.id,
    f.tenant_id,
    f.name,
    f.slug,
    f.is_active,
    f.is_default,
    f.created_at,
    count(s.id) as stage_count
  from public.shipment_progress_flows f
  left join public.shipment_progress_flow_stages s on s.flow_id = f.id
  where f.tenant_id = p_tenant_id
    and (p_include_archived or f.is_active = true)
  group by f.id
  order by f.is_default desc, f.name asc;
end;
$function$;

GRANT ALL ON FUNCTION public.list_shipment_progress_flows(bigint, boolean) TO anon;

GRANT ALL ON FUNCTION public.list_shipment_progress_flows(bigint, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.list_shipment_progress_flows(bigint, boolean) TO service_role;