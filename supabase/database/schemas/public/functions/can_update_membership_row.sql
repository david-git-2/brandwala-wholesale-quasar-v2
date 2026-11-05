CREATE FUNCTION public.can_update_membership_row (
  p_existing_tenant_id bigint,
  p_existing_role      public.app_role
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
      public.is_tenant_admin(p_existing_tenant_id)
      and p_existing_role in ('staff', 'viewer', 'investor')
    )
$function$;

GRANT ALL ON FUNCTION public.can_update_membership_row(bigint, public.app_role) TO anon;

GRANT ALL ON FUNCTION public.can_update_membership_row(bigint, public.app_role) TO authenticated;

GRANT ALL ON FUNCTION public.can_update_membership_row(bigint, public.app_role) TO service_role;