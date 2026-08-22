-- Rename shop customer role negotiator → manager (enum, templates, tenant roles, RPCs).

begin;

alter type public.customer_group_role rename value 'negotiator' to 'manager';

update public.system_role_templates
set role_slug = 'manager'
where scope = 'shop'
  and role_slug = 'negotiator';

update public.tenant_roles
set
  slug = 'manager',
  name = 'Customer Manager'
where scope = 'shop'
  and slug = 'negotiator';

create or replace function public.is_customer_group_admin_or_negotiator(
  p_customer_group_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.customer_group_members cgm
    where cgm.customer_group_id = p_customer_group_id
      and lower(trim(cgm.email)) = public.current_user_email()
      and cgm.role in ('admin', 'manager')
      and cgm.is_active = true
  )
$$;

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
      when 'manager' then 2
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
    coalesce(tr.is_admin, cgm.role = 'admin', false) as is_admin
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
$$;

create or replace function public.trg_fn_assign_default_customer_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
  v_role_slug text;
  v_role_id bigint;
begin
  if new.tenant_role_id is null and new.customer_group_id is not null and new.role is not null then
    select tenant_id into v_tenant_id
    from public.customer_groups
    where id = new.customer_group_id;

    if v_tenant_id is not null then
      v_role_slug := case new.role
        when 'admin' then 'customer-admin'
        when 'manager' then 'manager'
        when 'staff' then 'customer-staff'
        else 'customer-staff'
      end;

      select id into v_role_id
      from public.tenant_roles
      where tenant_id = v_tenant_id
        and scope = 'shop'
        and slug = v_role_slug;

      new.tenant_role_id := v_role_id;
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.trg_fn_sync_cgm_tenant_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
  v_target_slug text;
  v_role_id bigint;
begin
  if new.tenant_role_id is null or (tg_op = 'UPDATE' and old.role <> new.role) then
    select cg.tenant_id into v_tenant_id
    from public.customer_groups cg
    where cg.id = new.customer_group_id;

    if v_tenant_id is not null then
      v_target_slug := case new.role
        when 'admin' then 'customer-admin'
        when 'manager' then 'manager'
        when 'staff' then 'customer-staff'
        else 'customer-staff'
      end;

      select tr.id into v_role_id
      from public.tenant_roles tr
      where tr.tenant_id = v_tenant_id
        and tr.scope = 'shop'
        and (tr.slug = v_target_slug or (new.role = 'admin' and tr.is_admin = true))
      order by tr.is_admin desc, tr.id asc
      limit 1;

      if v_role_id is not null then
        new.tenant_role_id := v_role_id;
      end if;
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.seed_tenant_roles_and_grants(p_tenant_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role record;
begin
  insert into public.tenant_roles (tenant_id, scope, name, slug, is_system, is_admin, source_app_role)
  values
    (p_tenant_id, 'app', 'Administrator', 'administrator', true, true, 'admin'::public.app_role),
    (p_tenant_id, 'app', 'Staff', 'staff', true, false, 'staff'::public.app_role),
    (p_tenant_id, 'app', 'Viewer', 'viewer', true, false, 'viewer'::public.app_role)
  on conflict (tenant_id, scope, slug) do nothing;

  insert into public.tenant_roles (tenant_id, scope, name, slug, is_system, is_admin, source_app_role)
  values
    (p_tenant_id, 'shop', 'Customer Admin', 'customer-admin', true, false, null),
    (p_tenant_id, 'shop', 'Customer Manager', 'manager', true, false, null),
    (p_tenant_id, 'shop', 'Customer Staff', 'customer-staff', true, false, null)
  on conflict (tenant_id, scope, slug) do nothing;

  for v_role in (
    select id, scope, slug
    from public.tenant_roles
    where tenant_id = p_tenant_id and is_admin = false
  ) loop
    insert into public.tenant_role_grants (tenant_role_id, module_key, action, allowed)
    select v_role.id, t.module_key, t.action, t.allowed
    from public.system_role_templates t
    where t.scope = v_role.scope and t.role_slug = v_role.slug
    on conflict (tenant_role_id, module_key, action) do nothing;
  end loop;
end;
$$;

grant execute on function public.seed_tenant_roles_and_grants(bigint) to authenticated;

commit;
