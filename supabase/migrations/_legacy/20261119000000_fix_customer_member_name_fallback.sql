-- Migration: Fallback customer member name to auth.users metadata if null/empty
begin;

create or replace function public.check_shop_login_access(
  p_email text,
  p_tenant_id bigint default null
)
returns table(
  has_match boolean,
  matched_role public.customer_group_role,
  member_id bigint,
  member_name text,
  member_email text,
  member_tenant_id bigint,
  customer_group_id bigint,
  customer_group_name text,
  member_is_active boolean,
  customer_group_is_active boolean,
  member_created_at timestamptz,
  member_updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
begin
  v_email := lower(trim(coalesce(p_email, public.current_user_email(), '')));

  select
    cgm.role,
    cgm.id,
    coalesce(
      nullif(trim(cgm.name), ''),
      (select coalesce(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name') from auth.users u where u.email = v_email limit 1)
    ),
    lower(trim(cgm.email)),
    cg.tenant_id,
    cg.id,
    cg.name,
    cgm.is_active,
    cg.is_active,
    cgm.created_at,
    cgm.updated_at
  into
    matched_role,
    member_id,
    member_name,
    member_email,
    member_tenant_id,
    customer_group_id,
    customer_group_name,
    member_is_active,
    customer_group_is_active,
    member_created_at,
    member_updated_at
  from public.customer_group_members cgm
  inner join public.customer_groups cg
    on cg.id = cgm.customer_group_id
  where lower(trim(cgm.email)) = v_email
    and cgm.is_active = true
    and cg.is_active = true
    and (p_tenant_id is null or cg.tenant_id = p_tenant_id)
  order by
    cg.tenant_id asc,
    cg.id asc,
    case cgm.role
      when 'admin' then 1
      when 'negotiator' then 2
      when 'staff' then 3
      else 99
    end asc,
    cgm.id asc
  limit 1;

  has_match := member_id is not null;
  return next;
end;
$$;

create or replace function public.get_shop_bootstrap_context(
  p_email text default null,
  p_tenant_id bigint default null,
  p_customer_group_member_id bigint default null
)
returns table(
  member_id bigint,
  member_name text,
  member_email text,
  member_role public.customer_group_role,
  member_is_active boolean,
  customer_group_id bigint,
  customer_group_name text,
  customer_group_is_active boolean,
  customer_group_accent_color text,
  tenant_id bigint,
  tenant_name text,
  tenant_slug text,
  tenant_is_active boolean,
  active_module_keys text[],
  tenant_role_id bigint,
  is_admin boolean,
  effective_grants jsonb,
  permission_version bigint
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_email text;
  v_member record;
  v_grants jsonb;
  v_perm_version bigint;
begin
  v_email := lower(trim(coalesce(p_email, public.current_user_email())));

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
    tr.is_admin
  into v_member
  from public.customer_group_members cgm
  inner join public.customer_groups cg on cg.id = cgm.customer_group_id
  inner join public.tenants t on t.id = cg.tenant_id
  left join public.tenant_roles tr on tr.id = cgm.tenant_role_id
  where p_tenant_id is not null
    and lower(trim(cgm.email)) = v_email
    and cgm.is_active = true
    and cg.is_active = true
    and t.is_active = true
    and cg.tenant_id = p_tenant_id
    and (p_customer_group_member_id is null or cgm.id = p_customer_group_member_id)
  order by
    case cgm.role
      when 'admin' then 1
      when 'negotiator' then 2
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

  member_id := v_member.id;
  member_name := v_member.name;
  member_email := v_member.email;
  member_role := v_member.role;
  member_is_active := v_member.is_active;
  customer_group_id := v_member.customer_group_id;
  customer_group_name := v_member.customer_group_name;
  customer_group_is_active := v_member.customer_group_is_active;
  customer_group_accent_color := v_member.customer_group_accent_color;
  tenant_id := v_member.tenant_id;
  tenant_name := v_member.tenant_name;
  tenant_slug := v_member.tenant_slug;
  tenant_is_active := v_member.tenant_is_active;
  active_module_keys := coalesce(public.get_active_module_keys_for_tenant(v_member.tenant_id), '{}'::text[]);
  tenant_role_id := v_member.tenant_role_id;
  is_admin := coalesce(v_member.is_admin, false);
  effective_grants := v_grants;
  permission_version := v_perm_version;

  return next;
end;
$$;

commit;
