CREATE FUNCTION public.has_active_tenant_membership (
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
    or public.is_network_owner(p_tenant_id)
    or exists (
      select 1
      from public.memberships m
      where public.membership_email_matches_current_user(m.email)
        and m.tenant_id = p_tenant_id
        and m.is_active = true
    );
$function$;

GRANT ALL ON FUNCTION public.has_active_tenant_membership(bigint) TO anon;

GRANT ALL ON FUNCTION public.has_active_tenant_membership(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.has_active_tenant_membership(bigint) TO service_role;