CREATE FUNCTION public.can_access_preorder_demand_tenant (
  p_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select coalesce(
    public.is_tenant_staff(p_tenant_id)
    or exists (
      select 1 from public.tenants t
      where t.id = p_tenant_id
        and t.parent_id is not null
        and public.user_can_manage_parent_tenant(t.parent_id)
    ),
    false
  );
$function$;

GRANT ALL ON FUNCTION public.can_access_preorder_demand_tenant(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_access_preorder_demand_tenant(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_access_preorder_demand_tenant(bigint) TO service_role;