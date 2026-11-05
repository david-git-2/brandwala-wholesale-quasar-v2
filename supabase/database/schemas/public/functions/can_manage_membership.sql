CREATE FUNCTION public.can_manage_membership (
  p_target_tenant_id bigint,
  p_target_role      public.app_role
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select public.can_assign_membership_role(p_target_tenant_id, p_target_role)
$function$;

GRANT ALL ON FUNCTION public.can_manage_membership(bigint, public.app_role) TO anon;

GRANT ALL ON FUNCTION public.can_manage_membership(bigint, public.app_role) TO authenticated;

GRANT ALL ON FUNCTION public.can_manage_membership(bigint, public.app_role) TO service_role;