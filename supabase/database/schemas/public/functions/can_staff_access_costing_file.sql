CREATE FUNCTION public.can_staff_access_costing_file (
  p_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select public.is_tenant_staff(p_tenant_id)
$function$;

GRANT ALL ON FUNCTION public.can_staff_access_costing_file(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_staff_access_costing_file(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_staff_access_costing_file(bigint) TO service_role;