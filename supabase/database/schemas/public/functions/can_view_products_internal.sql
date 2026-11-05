CREATE FUNCTION public.can_view_products_internal (
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
    or public.membership_has_module_action(p_tenant_id, 'products', 'view');
$function$;

GRANT ALL ON FUNCTION public.can_view_products_internal(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_view_products_internal(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_view_products_internal(bigint) TO service_role;