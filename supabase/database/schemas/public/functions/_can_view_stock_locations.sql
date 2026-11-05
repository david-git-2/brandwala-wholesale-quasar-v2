CREATE FUNCTION public._can_view_stock_locations (
  p_parent_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    public._can_view_parent_warehouse_stock(p_parent_tenant_id)
    or public.membership_has_module_action(p_parent_tenant_id, 'global_stock_location', 'view')
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_parent_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    );
$function$;

GRANT ALL ON FUNCTION public._can_view_stock_locations(bigint) TO anon;

GRANT ALL ON FUNCTION public._can_view_stock_locations(bigint) TO authenticated;

GRANT ALL ON FUNCTION public._can_view_stock_locations(bigint) TO service_role;