CREATE FUNCTION public.create_tenant_role (
  p_tenant_id bigint,
  p_scope     text,
  p_name      text,
  p_slug      text,
  p_is_admin  boolean DEFAULT false
)
  RETURNS public.tenant_roles
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_row public.tenant_roles;
begin
  if not public.user_is_tenant_admin(p_tenant_id) then
    raise exception 'Unauthorized';
  end if;

  if p_scope not in ('app', 'shop') then
    raise exception 'Invalid scope: %', p_scope;
  end if;

  if p_is_admin = true and exists (
    select 1 from public.tenant_roles
    where tenant_id = p_tenant_id and scope = p_scope and is_admin = true
  ) then
    raise exception 'Only one Administrator role is allowed per scope';
  end if;

  insert into public.tenant_roles (
    tenant_id,
    scope,
    name,
    slug,
    is_system,
    is_admin,
    source_app_role,
    is_active
  )
  values (
    p_tenant_id,
    p_scope,
    trim(p_name),
    lower(trim(p_slug)),
    false,
    p_is_admin,
    null,
    true
  )
  returning * into v_row;

  return v_row;
end;
$function$;

GRANT ALL ON FUNCTION public.create_tenant_role(bigint, text, text, text, boolean) TO anon;

GRANT ALL ON FUNCTION public.create_tenant_role(bigint, text, text, text, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.create_tenant_role(bigint, text, text, text, boolean) TO service_role;