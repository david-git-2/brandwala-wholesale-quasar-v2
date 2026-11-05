CREATE FUNCTION public.can_view_products_for_parent (
  p_parent_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    p_parent_tenant_id is not null
    and (
      public.can_view_products_internal(p_parent_tenant_id)
      or public.can_view_products_customer(p_parent_tenant_id)
      or public.user_can_manage_parent_tenant(p_parent_tenant_id)
      or exists (
        select 1
        from public.memberships m
        join public.tenants t on t.id = m.tenant_id
        where m.is_active = true
          and lower(trim(m.email)) = public.current_user_email()
          and coalesce(t.parent_id, t.id) = p_parent_tenant_id
          and public.membership_has_module_action(m.tenant_id, 'products', 'view')
      )
      or exists (
        select 1
        from public.customer_group_members cgm
        join public.customer_groups cg on cg.id = cgm.customer_group_id
        join public.tenants t on t.id = cg.tenant_id
        where cgm.is_active = true
          and cg.is_active = true
          and lower(trim(cgm.email)) = public.current_user_email()
          and coalesce(t.parent_id, t.id) = p_parent_tenant_id
      )
    );
$function$;

GRANT ALL ON FUNCTION public.can_view_products_for_parent(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_view_products_for_parent(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_view_products_for_parent(bigint) TO service_role;