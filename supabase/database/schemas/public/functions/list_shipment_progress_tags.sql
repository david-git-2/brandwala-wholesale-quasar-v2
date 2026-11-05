CREATE FUNCTION public.list_shipment_progress_tags (
  p_tenant_id        bigint,
  p_include_archived boolean DEFAULT false
)
  RETURNS SETOF public.tags
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
    select t.*
    from public.tags t
    where t.tenant_id = p_tenant_id
      and t.group_name = 'shipment_progress'
      and (p_include_archived or t.is_active = true)
    order by t.sort_order nulls last, t.name;
end;
$function$;

GRANT ALL ON FUNCTION public.list_shipment_progress_tags(bigint, boolean) TO anon;

GRANT ALL ON FUNCTION public.list_shipment_progress_tags(bigint, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.list_shipment_progress_tags(bigint, boolean) TO service_role;