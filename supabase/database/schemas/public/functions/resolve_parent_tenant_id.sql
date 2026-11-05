CREATE FUNCTION public.resolve_parent_tenant_id (
  p_tenant_id bigint
)
  RETURNS bigint
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select coalesce(
    (select t.parent_id from public.tenants t where t.id = p_tenant_id),
    p_tenant_id
  );
$function$;

GRANT ALL ON FUNCTION public.resolve_parent_tenant_id(bigint) TO anon;

GRANT ALL ON FUNCTION public.resolve_parent_tenant_id(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.resolve_parent_tenant_id(bigint) TO service_role;