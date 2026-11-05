CREATE FUNCTION public.can_tenant_view_costing_file_viewer (
  p_tenant_id bigint
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
    where lower(trim(m.email)) = public.current_authenticated_email()
      and m.tenant_id = p_tenant_id
      and m.role = 'viewer'
      and m.is_active = true
  );
$function$;

GRANT ALL ON FUNCTION public.can_tenant_view_costing_file_viewer(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_tenant_view_costing_file_viewer(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_tenant_view_costing_file_viewer(bigint) TO service_role;