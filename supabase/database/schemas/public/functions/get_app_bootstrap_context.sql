CREATE FUNCTION public.get_app_bootstrap_context (
  p_email         text   DEFAULT NULL::text,
  p_tenant_id     bigint DEFAULT NULL::bigint,
  p_membership_id bigint DEFAULT NULL::bigint
)
  RETURNS TABLE (
    member_id          bigint,
    member_email       text,
    member_role        public.app_role,
    member_is_active   boolean,
    member_preference  jsonb,
    tenant_id          bigint,
    tenant_name        text,
    tenant_slug        text,
    tenant_is_active   boolean,
    tenant_preference  jsonb,
    active_module_keys text[],
    tenant_role_id     bigint,
    is_admin           boolean,
    effective_grants   jsonb,
    permission_version bigint
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_email text;
  v_member record;
  v_target_tenant_id bigint;
  v_grants jsonb;
  v_perm_version bigint;
  v_is_admin boolean;
begin
  v_email := lower(trim(coalesce(p_email, public.current_user_email())));
  v_target_tenant_id := p_tenant_id;

  select
    m.id,
    lower(trim(m.email)) as email,
    m.role,
    m.is_active,
    m.preference as member_preference,
    m.tenant_role_id,
    t.id as tenant_id,
    t.name as tenant_name,
    t.slug as tenant_slug,
    t.is_active as tenant_is_active,
    t.preference as tenant_preference,
    tr.is_admin
  into v_member
  from public.memberships m
  inner join public.tenants t on t.id = m.tenant_id
  left join public.tenant_roles tr on tr.id = m.tenant_role_id
  where lower(trim(m.email)) = v_email
    and m.is_active = true
    and m.role in ('owner', 'manager', 'staff', 'viewer')
    and (p_tenant_id is null or m.tenant_id = p_tenant_id)
    and (p_membership_id is null or m.id = p_membership_id)
  order by
    case m.role
      when 'owner' then 1
      when 'manager' then 2
      when 'staff' then 3
      when 'viewer' then 4
      else 99
    end,
    m.id asc
  limit 1;

  if v_member.id is null and p_tenant_id is not null and public.is_network_owner(p_tenant_id) then
    select
      m.id,
      lower(trim(m.email)) as email,
      m.role,
      m.is_active,
      m.preference as member_preference,
      m.tenant_role_id,
      t.id as tenant_id,
      t.name as tenant_name,
      t.slug as tenant_slug,
      t.is_active as tenant_is_active,
      t.preference as tenant_preference,
      tr.is_admin
    into v_member
    from public.memberships m
    inner join public.tenants t on t.id = m.tenant_id
    left join public.tenant_roles tr on tr.id = m.tenant_role_id
    where lower(trim(m.email)) = v_email
      and m.is_active = true
      and m.role = 'owner'::public.app_role
      and m.tenant_id = public.resolve_parent_tenant_id(p_tenant_id)
    order by m.id asc
    limit 1;

    if v_member.id is not null then
      select child.id, child.name, child.slug, child.is_active, child.preference
      into v_target_tenant_id, v_member.tenant_name, v_member.tenant_slug,
           v_member.tenant_is_active, v_member.tenant_preference
      from public.tenants child
      where child.id = p_tenant_id;
    end if;
  end if;

  if v_member.id is null then
    return;
  end if;

  select coalesce(
    jsonb_agg(jsonb_build_object('module_key', module_key, 'action', action)),
    '[]'::jsonb
  )
  into v_grants
  from public.get_effective_grants(coalesce(v_target_tenant_id, v_member.tenant_id));

  select tpv.version into v_perm_version
  from public.tenant_permission_versions tpv
  where tpv.tenant_id = coalesce(v_target_tenant_id, v_member.tenant_id);

  if v_perm_version is null then
    perform public.bump_tenant_permission_version(coalesce(v_target_tenant_id, v_member.tenant_id));
    v_perm_version := 1;
  end if;

  v_is_admin := v_member.role in ('owner'::public.app_role, 'manager'::public.app_role)
    or coalesce(v_member.is_admin, false);

  member_id := v_member.id;
  member_email := v_member.email;
  member_role := v_member.role;
  member_is_active := v_member.is_active;
  member_preference := coalesce(v_member.member_preference, '{}'::jsonb);
  tenant_id := coalesce(v_target_tenant_id, v_member.tenant_id);
  tenant_name := v_member.tenant_name;
  tenant_slug := v_member.tenant_slug;
  tenant_is_active := v_member.tenant_is_active;
  tenant_preference := coalesce(v_member.tenant_preference, '{}'::jsonb);
  active_module_keys := coalesce(
    public.get_active_module_keys_for_tenant(coalesce(v_target_tenant_id, v_member.tenant_id)),
    '{}'::text[]
  );
  tenant_role_id := v_member.tenant_role_id;
  is_admin := v_is_admin;
  effective_grants := v_grants;
  permission_version := v_perm_version;

  return next;
end;
$function$;

GRANT ALL ON FUNCTION public.get_app_bootstrap_context(text, bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.get_app_bootstrap_context(text, bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_app_bootstrap_context(text, bigint, bigint) TO service_role;