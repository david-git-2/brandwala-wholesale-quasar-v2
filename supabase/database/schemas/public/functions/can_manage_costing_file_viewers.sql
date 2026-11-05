CREATE FUNCTION public.can_manage_costing_file_viewers (
  p_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select public.can_admin_manage_costing_file(p_tenant_id);
$function$;

GRANT ALL ON FUNCTION public.can_manage_costing_file_viewers(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_manage_costing_file_viewers(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_manage_costing_file_viewers(bigint) TO service_role;