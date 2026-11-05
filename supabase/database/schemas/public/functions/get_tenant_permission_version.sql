CREATE FUNCTION public.get_tenant_permission_version (
  p_tenant_id bigint
)
  RETURNS bigint
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_version bigint;
begin
  select version into v_version
  from public.tenant_permission_versions
  where tenant_id = p_tenant_id;
  
  return coalesce(v_version, 1);
end;
$function$;

GRANT ALL ON FUNCTION public.get_tenant_permission_version(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_tenant_permission_version(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_tenant_permission_version(bigint) TO service_role;