CREATE FUNCTION public.is_tenant_admin (
  p_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    public.is_network_owner(p_tenant_id)
    or public.is_tenant_manager(p_tenant_id);
$function$;

GRANT ALL ON FUNCTION public.is_tenant_admin(bigint) TO anon;

GRANT ALL ON FUNCTION public.is_tenant_admin(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.is_tenant_admin(bigint) TO service_role;