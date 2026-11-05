CREATE FUNCTION public.can_manage_products_for_parent (
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
      public.can_manage_products(p_parent_tenant_id)
      or exists (
        select 1
        from public.memberships m
        join public.tenants t on t.id = m.tenant_id
        where m.is_active = true
          and lower(trim(m.email)) = public.current_user_email()
          and coalesce(t.parent_id, t.id) = p_parent_tenant_id
          and public.membership_has_module_action(m.tenant_id, 'products', 'edit')
      )
    );
$function$;

GRANT ALL ON FUNCTION public.can_manage_products_for_parent(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_manage_products_for_parent(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_manage_products_for_parent(bigint) TO service_role;