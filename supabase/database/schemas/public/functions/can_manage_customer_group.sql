CREATE FUNCTION public.can_manage_customer_group (
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
    or public.is_tenant_admin(p_tenant_id)
    or public.membership_has_module_action(p_tenant_id, 'customer', 'edit')
    or public.membership_has_module_action(p_tenant_id, 'customer', 'create');
$function$;

GRANT ALL ON FUNCTION public.can_manage_customer_group(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_manage_customer_group(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_manage_customer_group(bigint) TO service_role;