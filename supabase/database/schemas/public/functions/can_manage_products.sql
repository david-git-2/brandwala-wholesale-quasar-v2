CREATE FUNCTION public.can_manage_products (
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
    or public.membership_has_module_action(p_tenant_id, 'products', 'edit');
$function$;

GRANT ALL ON FUNCTION public.can_manage_products(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_manage_products(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_manage_products(bigint) TO service_role;