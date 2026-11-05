CREATE FUNCTION public.can_act_on_parent_tenant_stock (
  p_parent_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    public.has_active_tenant_membership(p_parent_tenant_id)
    or public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      inner join public.tenants t on t.id = m.tenant_id
      where t.parent_id = p_parent_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
    or exists (
      select 1
      from public.customer_group_members cgm
      inner join public.customer_groups cg on cg.id = cgm.customer_group_id
      inner join public.shop_customer_group_access scga on scga.customer_group_id = cg.id
      inner join public.shops s on s.id = scga.shop_id
      where public.resolve_parent_tenant_id(s.tenant_id) = p_parent_tenant_id
        and coalesce(cg.parent_tenant_id, cg.tenant_id) = p_parent_tenant_id
        and lower(trim(cgm.email)) = public.current_user_email()
        and cgm.is_active = true
        and cg.is_active = true
        and scga.status = true
        and s.is_active = true
        and s.deleted_at is null
    )
    or exists (
      select 1
      from public.shops s
      join lateral public.get_shop_permissions_for_customer(s.id) perms on true
      where public.resolve_parent_tenant_id(s.tenant_id) = p_parent_tenant_id
        and s.is_active = true
        and s.deleted_at is null
        and coalesce(perms.can_place_order, false)
    );
$function$;

GRANT ALL ON FUNCTION public.can_act_on_parent_tenant_stock(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_act_on_parent_tenant_stock(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_act_on_parent_tenant_stock(bigint) TO service_role;