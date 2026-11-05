CREATE FUNCTION public.get_shop_bootstrap_context (
  p_email                    text   DEFAULT NULL::text,
  p_tenant_id                bigint DEFAULT NULL::bigint,
  p_customer_group_member_id bigint DEFAULT NULL::bigint
)
  RETURNS TABLE (
    member_id                   bigint,
    member_name                 text,
    member_email                text,
    member_role                 public.customer_group_role,
    member_is_active            boolean,
    customer_group_id           bigint,
    customer_group_name         text,
    customer_group_is_active    boolean,
    customer_group_accent_color text,
    tenant_id                   bigint,
    tenant_name                 text,
    tenant_slug                 text,
    tenant_is_active            boolean,
    active_module_keys          text[],
    tenant_role_id              bigint,
    is_admin                    boolean,
    effective_grants            jsonb,
    permission_version          bigint
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_email text;
  v_member record;
  v_grants jsonb;
  v_perm_version bigint;
begin
  v_email := lower(trim(coalesce(p_email, public.current_user_email())));

  if p_tenant_id is null or p_customer_group_member_id is null then
    return;
  end if;

  select
    cgm.id,
    coalesce(
      nullif(trim(cgm.name), ''),
      (select coalesce(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name') from auth.users u where u.email = v_email limit 1)
    ) as name,
    lower(trim(cgm.email)) as email,
    cgm.role,
    cgm.is_active,
    cgm.tenant_role_id,
    cg.id as customer_group_id,
    cg.name as customer_group_name,
    cg.is_active as customer_group_is_active,
    cg.accent_color as customer_group_accent_color,
    t.id as tenant_id,
    t.name as tenant_name,
    t.slug as tenant_slug,
    t.is_active as tenant_is_active,
    coalesce(tr.is_admin, cgm.role = 'admin', false) as is_admin
  into v_member
  from public.customer_group_members cgm
  inner join public.customer_groups cg on cg.id = cgm.customer_group_id
  inner join public.tenants t on t.id = p_tenant_id
  left join public.tenant_roles tr on tr.id = cgm.tenant_role_id
  where p_tenant_id is not null
    and lower(trim(cgm.email)) = v_email
    and cgm.is_active = true
    and cg.is_active = true
    and cg.deleted_at is null
    and t.is_active = true
    and cgm.id = p_customer_group_member_id
    and coalesce(cg.parent_tenant_id, cg.tenant_id) = public.resolve_parent_tenant_id(p_tenant_id)
    and exists (
      select 1
      from public.shop_customer_group_access scga
      inner join public.shops s on s.id = scga.shop_id
      where scga.customer_group_id = cg.id
        and scga.status = true
        and s.tenant_id = p_tenant_id
        and s.is_active = true
        and s.deleted_at is null
    )
  order by
    case cgm.role
      when 'admin' then 1
      when 'manager' then 2
      when 'staff' then 3
      else 99
    end,
    cgm.id asc
  limit 1;

  if v_member.id is null then
    return;
  end if;

  select coalesce(
    jsonb_agg(jsonb_build_object('module_key', module_key, 'action', action)),
    '[]'::jsonb
  )
  into v_grants
  from public.get_shop_effective_grants(v_member.tenant_id, v_member.id);

  select tpv.version into v_perm_version
  from public.tenant_permission_versions tpv
  where tpv.tenant_id = v_member.tenant_id;

  if v_perm_version is null then
    perform public.bump_tenant_permission_version(v_member.tenant_id);
    v_perm_version := 1;
  end if;

  return query
  select
    v_member.id as member_id,
    v_member.name as member_name,
    v_member.email as member_email,
    v_member.role as member_role,
    v_member.is_active as member_is_active,
    v_member.customer_group_id,
    v_member.customer_group_name,
    v_member.customer_group_is_active,
    v_member.customer_group_accent_color,
    v_member.tenant_id,
    v_member.tenant_name,
    v_member.tenant_slug,
    v_member.tenant_is_active,
    coalesce(public.get_active_module_keys_for_tenant(v_member.tenant_id), array[]::text[]) as active_module_keys,
    v_member.tenant_role_id,
    v_member.is_admin,
    v_grants as effective_grants,
    v_perm_version as permission_version;
end;
$function$;

GRANT ALL ON FUNCTION public.get_shop_bootstrap_context(text, bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.get_shop_bootstrap_context(text, bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_shop_bootstrap_context(text, bigint, bigint) TO service_role;