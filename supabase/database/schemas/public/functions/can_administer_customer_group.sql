CREATE FUNCTION public.can_administer_customer_group (
  p_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    public.is_superadmin()
    or public.is_tenant_admin(public.resolve_parent_tenant_id(p_tenant_id))
$function$;

GRANT ALL ON FUNCTION public.can_administer_customer_group(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_administer_customer_group(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_administer_customer_group(bigint) TO service_role;