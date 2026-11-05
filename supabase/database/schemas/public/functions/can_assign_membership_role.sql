CREATE FUNCTION public.can_assign_membership_role (
  p_target_tenant_id bigint,
  p_target_role      public.app_role
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    public.is_superadmin()
    or (
      public.is_network_owner(p_target_tenant_id)
      and p_target_role in ('manager', 'staff', 'viewer', 'investor')
    )
    or (
      public.is_tenant_manager(p_target_tenant_id)
      and p_target_role in ('staff', 'viewer', 'investor')
    );
$function$;

GRANT ALL ON FUNCTION public.can_assign_membership_role(bigint, public.app_role) TO anon;

GRANT ALL ON FUNCTION public.can_assign_membership_role(bigint, public.app_role) TO authenticated;

GRANT ALL ON FUNCTION public.can_assign_membership_role(bigint, public.app_role) TO service_role;