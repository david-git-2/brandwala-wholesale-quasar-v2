CREATE FUNCTION public.list_configurable_module_actions (
  p_scope     text,
  p_tenant_id bigint
)
  RETURNS TABLE (
    id                  bigint,
    module_key          text,
    action              text,
    description         text,
    scope               text,
    tenant_configurable boolean,
    is_active           boolean
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if p_scope not in ('app', 'shop', 'investor') then
    raise exception 'Invalid scope: %', p_scope;
  end if;

  if not public.is_superadmin() and not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Access denied';
  end if;

  return query
  select
    ma.id,
    ma.module_key,
    ma.action,
    ma.description,
    ma.scope,
    ma.tenant_configurable,
    ma.is_active
  from public.module_actions ma
  where ma.is_active = true
    and ma.tenant_configurable = true
    and ma.scope = p_scope
    and ma.scope <> 'platform'
    and ma.module_key = any(public.get_active_module_keys_for_tenant(p_tenant_id));
end;
$function$;

GRANT ALL ON FUNCTION public.list_configurable_module_actions(text, bigint) TO anon;

GRANT ALL ON FUNCTION public.list_configurable_module_actions(text, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_configurable_module_actions(text, bigint) TO service_role;