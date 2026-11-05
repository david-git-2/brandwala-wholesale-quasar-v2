CREATE FUNCTION public.list_child_tenant_ids (
  p_parent_tenant_id bigint
)
  RETURNS SETOF bigint
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select t.id
  from public.tenants t
  where t.parent_id = p_parent_tenant_id
  order by t.id;
$function$;

GRANT ALL ON FUNCTION public.list_child_tenant_ids(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_child_tenant_ids(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_child_tenant_ids(bigint) TO service_role;