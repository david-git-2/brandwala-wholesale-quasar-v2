CREATE FUNCTION public.is_child_tenant (
  p_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select coalesce(
    (select t.parent_id is not null from public.tenants t where t.id = p_tenant_id),
    false
  );
$function$;

GRANT ALL ON FUNCTION public.is_child_tenant(bigint) TO anon;

GRANT ALL ON FUNCTION public.is_child_tenant(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.is_child_tenant(bigint) TO service_role;