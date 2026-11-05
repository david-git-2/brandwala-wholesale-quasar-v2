CREATE FUNCTION public.is_parent_company (
  p_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select coalesce(
    (select t.parent_id is null from public.tenants t where t.id = p_tenant_id),
    false
  );
$function$;

GRANT ALL ON FUNCTION public.is_parent_company(bigint) TO anon;

GRANT ALL ON FUNCTION public.is_parent_company(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.is_parent_company(bigint) TO service_role;