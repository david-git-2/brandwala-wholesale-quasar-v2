CREATE FUNCTION public.user_can_manage_parent_tenant (
  p_parent_tenant_id bigint
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
    where m.tenant_id = p_parent_tenant_id
      and public.membership_email_matches_current_user(m.email)
      and m.is_active = true
      and (
        m.role = 'owner'::public.app_role
        or public.has_module_action(p_parent_tenant_id, 'procurement_stock', 'manage')
      )
  );
$function$;

GRANT ALL ON FUNCTION public.user_can_manage_parent_tenant(bigint) TO anon;

GRANT ALL ON FUNCTION public.user_can_manage_parent_tenant(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.user_can_manage_parent_tenant(bigint) TO service_role;