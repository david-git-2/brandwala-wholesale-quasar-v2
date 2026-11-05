CREATE FUNCTION public.is_tenant_staff (
  p_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (
    select 1
    from public.memberships m
    where (m.tenant_id = p_tenant_id or m.tenant_id = public.resolve_parent_tenant_id(p_tenant_id))
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and (
        m.role = 'superadmin'::public.app_role
        or m.role = 'admin'::public.app_role
        or public.has_module_action(m.tenant_id, 'shop_order_mgmt', 'view')
      )
  );
$function$;

GRANT ALL ON FUNCTION public.is_tenant_staff(bigint) TO anon;

GRANT ALL ON FUNCTION public.is_tenant_staff(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.is_tenant_staff(bigint) TO service_role;