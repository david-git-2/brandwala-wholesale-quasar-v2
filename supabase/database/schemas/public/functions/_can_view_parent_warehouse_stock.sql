CREATE FUNCTION public._can_view_parent_warehouse_stock (
  p_parent_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    public.is_superadmin()
    or public.user_can_manage_parent_tenant(p_parent_tenant_id)
    or public.membership_has_module_action(p_parent_tenant_id, 'global_stock', 'view')
    or exists (
      select 1
      from public.tenants child
      inner join public.memberships m on m.tenant_id = child.id
      where child.parent_id = p_parent_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and public.membership_has_module_action(child.id, 'global_stock', 'view')
    );
$function$;

GRANT ALL ON FUNCTION public._can_view_parent_warehouse_stock(bigint) TO anon;

GRANT ALL ON FUNCTION public._can_view_parent_warehouse_stock(bigint) TO authenticated;

GRANT ALL ON FUNCTION public._can_view_parent_warehouse_stock(bigint) TO service_role;