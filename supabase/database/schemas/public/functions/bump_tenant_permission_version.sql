CREATE FUNCTION public.bump_tenant_permission_version (
  p_tenant_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  insert into public.tenant_permission_versions (tenant_id, version, updated_at)
  values (p_tenant_id, 1, now())
  on conflict (tenant_id) do update set
    version = tenant_permission_versions.version + 1,
    updated_at = now();
end;
$function$;

GRANT ALL ON FUNCTION public.bump_tenant_permission_version(bigint) TO anon;

GRANT ALL ON FUNCTION public.bump_tenant_permission_version(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.bump_tenant_permission_version(bigint) TO service_role;