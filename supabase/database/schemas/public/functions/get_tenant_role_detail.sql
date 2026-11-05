CREATE FUNCTION public.get_tenant_role_detail (
  p_role_id bigint
)
  RETURNS json
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_role json;
begin
  select row_to_json(r) into v_role
  from (
    select id, tenant_id, scope, name, slug, is_system, is_admin, source_app_role, is_active, created_at, updated_at
    from public.tenant_roles
    where id = p_role_id
  ) r;
  
  if v_role is null then
    raise exception 'Role not found';
  end if;
  
  return v_role;
end;
$function$;

GRANT ALL ON FUNCTION public.get_tenant_role_detail(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_tenant_role_detail(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_tenant_role_detail(bigint) TO service_role;