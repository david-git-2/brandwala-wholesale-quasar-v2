-- Migration: AC-P1 Permissions Setup Foundation & Contract Hardening
begin;

-- =========================================================
-- 1. Schema Primitives: tenant_permission_versions
-- =========================================================
create table if not exists public.tenant_permission_versions (
  tenant_id bigint primary key references public.tenants(id) on delete cascade,
  version bigint not null default 1,
  updated_at timestamptz not null default now()
);

-- Seed versions for all existing tenants
insert into public.tenant_permission_versions (tenant_id, version)
select id, 1 from public.tenants
on conflict (tenant_id) do nothing;

-- Uniqueness/Integrity constraints: only one active admin role per tenant+scope
create unique index if not exists tenant_roles_one_active_admin_idx
  on public.tenant_roles (tenant_id, scope)
  where (is_admin = true and is_active = true);

-- =========================================================
-- 2. Version Tracking Logic
-- =========================================================
create or replace function public.bump_tenant_permission_version(p_tenant_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.tenant_permission_versions (tenant_id, version, updated_at)
  values (p_tenant_id, 1, now())
  on conflict (tenant_id) do update set
    version = tenant_permission_versions.version + 1,
    updated_at = now();
end;
$$;

-- Trigger functions to bump tenant permission versions on modification of relevant tables
create or replace function public.trg_fn_bump_role_tenant_version()
returns trigger
language plpgsql
security definer
as $$
begin
  if tg_op = 'DELETE' then
    perform public.bump_tenant_permission_version(old.tenant_id);
    return old;
  else
    perform public.bump_tenant_permission_version(new.tenant_id);
    return new;
  end if;
end;
$$;

drop trigger if exists trg_tenant_roles_bump_version on public.tenant_roles;
create trigger trg_tenant_roles_bump_version
  after insert or update or delete on public.tenant_roles
  for each row execute function public.trg_fn_bump_role_tenant_version();

create or replace function public.trg_fn_bump_grant_tenant_version()
returns trigger
language plpgsql
security definer
as $$
declare
  v_tenant_id bigint;
begin
  if tg_op = 'DELETE' then
    select tenant_id into v_tenant_id from public.tenant_roles where id = old.tenant_role_id;
  else
    select tenant_id into v_tenant_id from public.tenant_roles where id = new.tenant_role_id;
  end if;
  if v_tenant_id is not null then
    perform public.bump_tenant_permission_version(v_tenant_id);
  end if;
  if tg_op = 'DELETE' then
    return old;
  else
    return new;
  end if;
end;
$$;

drop trigger if exists trg_tenant_role_grants_bump_version on public.tenant_role_grants;
create trigger trg_tenant_role_grants_bump_version
  after insert or update or delete on public.tenant_role_grants
  for each row execute function public.trg_fn_bump_grant_tenant_version();

create or replace function public.trg_fn_bump_membership_grant_tenant_version()
returns trigger
language plpgsql
security definer
as $$
declare
  v_tenant_id bigint;
begin
  if tg_op = 'DELETE' then
    select tenant_id into v_tenant_id from public.memberships where id = old.membership_id;
  else
    select tenant_id into v_tenant_id from public.memberships where id = new.membership_id;
  end if;
  if v_tenant_id is not null then
    perform public.bump_tenant_permission_version(v_tenant_id);
  end if;
  if tg_op = 'DELETE' then
    return old;
  else
    return new;
  end if;
end;
$$;

drop trigger if exists trg_membership_grants_bump_version on public.membership_grants;
create trigger trg_membership_grants_bump_version
  after insert or update or delete on public.membership_grants
  for each row execute function public.trg_fn_bump_membership_grant_tenant_version();

create or replace function public.trg_fn_bump_cgm_grant_tenant_version()
returns trigger
language plpgsql
security definer
as $$
declare
  v_tenant_id bigint;
begin
  if tg_op = 'DELETE' then
    select cg.tenant_id into v_tenant_id
    from public.customer_group_members cgm
    join public.customer_groups cg on cg.id = cgm.customer_group_id
    where cgm.id = old.customer_group_member_id;
  else
    select cg.tenant_id into v_tenant_id
    from public.customer_group_members cgm
    join public.customer_groups cg on cg.id = cgm.customer_group_id
    where cgm.id = new.customer_group_member_id;
  end if;
  if v_tenant_id is not null then
    perform public.bump_tenant_permission_version(v_tenant_id);
  end if;
  if tg_op = 'DELETE' then
    return old;
  else
    return new;
  end if;
end;
$$;

drop trigger if exists trg_cgm_grants_bump_version on public.customer_group_member_grants;
create trigger trg_cgm_grants_bump_version
  after insert or update or delete on public.customer_group_member_grants
  for each row execute function public.trg_fn_bump_cgm_grant_tenant_version();

create or replace function public.trg_fn_bump_membership_version()
returns trigger
language plpgsql
security definer
as $$
begin
  if tg_op = 'DELETE' then
    perform public.bump_tenant_permission_version(old.tenant_id);
    return old;
  elsif tg_op = 'INSERT' then
    perform public.bump_tenant_permission_version(new.tenant_id);
    return new;
  elsif coalesce(old.tenant_role_id, 0) <> coalesce(new.tenant_role_id, 0) or old.is_active <> new.is_active or old.role <> new.role then
    perform public.bump_tenant_permission_version(new.tenant_id);
    return new;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_memberships_bump_version on public.memberships;
create trigger trg_memberships_bump_version
  after insert or update or delete on public.memberships
  for each row execute function public.trg_fn_bump_membership_version();

create or replace function public.trg_fn_bump_cgm_version()
returns trigger
language plpgsql
security definer
as $$
declare
  v_tenant_id bigint;
begin
  if tg_op = 'DELETE' then
    select tenant_id into v_tenant_id from public.customer_groups where id = old.customer_group_id;
  else
    select tenant_id into v_tenant_id from public.customer_groups where id = new.customer_group_id;
  end if;
  if v_tenant_id is not null then
    if tg_op = 'DELETE' or tg_op = 'INSERT' or coalesce(old.tenant_role_id, 0) <> coalesce(new.tenant_role_id, 0) or old.is_active <> new.is_active or old.role <> new.role then
      perform public.bump_tenant_permission_version(v_tenant_id);
    end if;
  end if;
  if tg_op = 'DELETE' then
    return old;
  else
    return new;
  end if;
end;
$$;

drop trigger if exists trg_cgm_bump_version on public.customer_group_members;
create trigger trg_cgm_bump_version
  after insert or update or delete on public.customer_group_members
  for each row execute function public.trg_fn_bump_cgm_version();

create or replace function public.trg_fn_bump_tenant_modules_version()
returns trigger
language plpgsql
security definer
as $$
begin
  if tg_op = 'DELETE' then
    perform public.bump_tenant_permission_version(old.tenant_id);
    return old;
  else
    perform public.bump_tenant_permission_version(new.tenant_id);
    return new;
  end if;
end;
$$;

drop trigger if exists trg_tenant_modules_bump_version on public.tenant_modules;
create trigger trg_tenant_modules_bump_version
  after insert or update or delete on public.tenant_modules
  for each row execute function public.trg_fn_bump_tenant_modules_version();


-- =========================================================
-- 3. Guardrails and Constraints Triggers
-- =========================================================

-- Guardrail: Deny delete/deactivate of final active admin role
create or replace function public.trg_fn_tenant_role_guardrails()
returns trigger
language plpgsql
security definer
as $$
declare
  v_count int;
begin
  if tg_op = 'DELETE' then
    if old.is_admin = true and old.is_active = true then
      raise exception 'Cannot delete the final active admin role for this scope';
    end if;
    return old;
  elsif tg_op = 'UPDATE' then
    if old.is_admin = true and old.is_active = true and (new.is_admin = false or new.is_active = false) then
      select count(*) into v_count
      from public.tenant_roles
      where tenant_id = old.tenant_id
        and scope = old.scope
        and is_admin = true
        and is_active = true
        and id <> old.id;
      if v_count = 0 then
        raise exception 'Cannot deactivate or downgrade the final active admin role for this scope';
      end if;
    end if;
    return new;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_tenant_roles_guardrails on public.tenant_roles;
create trigger trg_tenant_roles_guardrails
  before update or delete on public.tenant_roles
  for each row execute function public.trg_fn_tenant_role_guardrails();

-- Guardrail: Memberships role assignment restrictions
create or replace function public.trg_fn_memberships_permission_guardrails()
returns trigger
language plpgsql
security definer
as $$
declare
  v_role_scope text;
  v_role_tenant bigint;
  v_role_is_admin boolean;
  v_active_admins int;
begin
  if new.tenant_role_id is not null then
    select scope, tenant_id, is_admin into v_role_scope, v_role_tenant, v_role_is_admin
    from public.tenant_roles
    where id = new.tenant_role_id;

    if v_role_tenant <> new.tenant_id then
      raise exception 'Cross-tenant role assignment is not allowed';
    end if;

    if v_role_scope <> 'app' then
      raise exception 'Scope mismatch: app membership cannot be assigned a % scoped role', v_role_scope;
    end if;
  end if;

  if tg_op = 'UPDATE' and old.is_active = true then
    declare
      v_was_admin boolean;
      v_is_admin boolean;
    begin
      v_was_admin := (old.role = 'admin') or exists (
        select 1 from public.tenant_roles where id = old.tenant_role_id and is_admin = true
      );
      v_is_admin := (new.is_active = true) and ((new.role = 'admin') or exists (
        select 1 from public.tenant_roles where id = new.tenant_role_id and is_admin = true
      ));

      if v_was_admin and not v_is_admin then
        select count(*) into v_active_admins
        from public.memberships m
        left join public.tenant_roles tr on tr.id = m.tenant_role_id
        where m.tenant_id = old.tenant_id
          and m.is_active = true
          and m.id <> old.id
          and (m.role = 'admin' or tr.is_admin = true);

        if v_active_admins = 0 then
          raise exception 'Cannot downgrade or deactivate the last active administrator for this tenant';
        end if;
      end if;
    end;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_memberships_permission_guardrails on public.memberships;
create trigger trg_memberships_permission_guardrails
  before insert or update on public.memberships
  for each row execute function public.trg_fn_memberships_permission_guardrails();

-- Guardrail: Customer group members assignment restrictions
create or replace function public.trg_fn_cgm_permission_guardrails()
returns trigger
language plpgsql
security definer
as $$
declare
  v_role_scope text;
  v_role_tenant bigint;
  v_cg_tenant bigint;
begin
  if new.tenant_role_id is not null then
    select scope, tenant_id into v_role_scope, v_role_tenant
    from public.tenant_roles
    where id = new.tenant_role_id;

    select tenant_id into v_cg_tenant
    from public.customer_groups
    where id = new.customer_group_id;

    if v_role_tenant <> v_cg_tenant then
      raise exception 'Cross-tenant role assignment is not allowed';
    end if;

    if v_role_scope <> 'shop' then
      raise exception 'Scope mismatch: customer group member cannot be assigned a % scoped role', v_role_scope;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_cgm_permission_guardrails on public.customer_group_members;
create trigger trg_cgm_permission_guardrails
  before insert or update on public.customer_group_members
  for each row execute function public.trg_fn_cgm_permission_guardrails();

-- Guardrail: On module disable, block if dependent grants/overrides exist unless explicit force is used
create or replace function public.trg_fn_tenant_modules_disable_guardrails()
returns trigger
language plpgsql
security definer
as $$
declare
  v_has_grants boolean;
  v_has_overrides boolean;
begin
  if tg_op = 'UPDATE' and old.is_active = true and new.is_active = false then
    if coalesce(current_setting('request.force_module_disable', true), '') <> 'true' then
      select exists (
        select 1 from public.tenant_role_grants tg
        join public.tenant_roles tr on tr.id = tg.tenant_role_id
        where tr.tenant_id = old.tenant_id and tg.module_key = old.module_key
      ) into v_has_grants;

      if v_has_grants then
        raise exception 'Cannot disable module %: active role grants depend on it. Use force to override.', old.module_key;
      end if;

      select exists (
        select 1 from public.membership_grants mg
        join public.memberships m on m.id = mg.membership_id
        where m.tenant_id = old.tenant_id and mg.module_key = old.module_key
      ) into v_has_overrides;

      if v_has_overrides then
        raise exception 'Cannot disable module %: active member overrides depend on it. Use force to override.', old.module_key;
      end if;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_tenant_modules_disable_guardrails on public.tenant_modules;
create trigger trg_tenant_modules_disable_guardrails
  before update on public.tenant_modules
  for each row execute function public.trg_fn_tenant_modules_disable_guardrails();


-- =========================================================
-- 4. RPC Hardening: get_tenant_role_detail
-- =========================================================
create or replace function public.get_tenant_role_detail(p_role_id bigint)
returns json
language plpgsql
security definer
stable
set search_path = public
as $$
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
$$;

grant execute on function public.get_tenant_role_detail(bigint) to authenticated;


-- =========================================================
-- 5. Redefine Bootstrap Contexts to include permission_version
-- =========================================================

-- Redefine get_app_bootstrap_context
drop function if exists public.get_app_bootstrap_context(text, bigint, bigint);

create or replace function public.get_app_bootstrap_context(
  p_email text default null,
  p_tenant_id bigint default null,
  p_membership_id bigint default null
)
returns table(
  member_id bigint,
  member_email text,
  member_role public.app_role,
  member_is_active boolean,
  member_preference jsonb,
  tenant_id bigint,
  tenant_name text,
  tenant_slug text,
  tenant_is_active boolean,
  tenant_preference jsonb,
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
    and m.role in ('admin', 'staff', 'viewer')
    and (p_tenant_id is null or m.tenant_id = p_tenant_id)
    and (p_membership_id is null or m.id = p_membership_id)
  order by
    case m.role
      when 'admin' then 1
      when 'staff' then 2
      when 'viewer' then 3
      else 99
    end,
    m.id asc
  limit 1;

  if v_member.id is null then
    return;
  end if;

  select coalesce(
    jsonb_agg(jsonb_build_object('module_key', module_key, 'action', action)),
    '[]'::jsonb
  )
  into v_grants
  from public.get_effective_grants(v_member.tenant_id);

  select tpv.version into v_perm_version
  from public.tenant_permission_versions tpv
  where tpv.tenant_id = v_member.tenant_id;

  if v_perm_version is null then
    perform public.bump_tenant_permission_version(v_member.tenant_id);
    v_perm_version := 1;
  end if;

  member_id := v_member.id;
  member_email := v_member.email;
  member_role := v_member.role;
  member_is_active := v_member.is_active;
  member_preference := coalesce(v_member.member_preference, '{}'::jsonb);
  tenant_id := v_member.tenant_id;
  tenant_name := v_member.tenant_name;
  tenant_slug := v_member.tenant_slug;
  tenant_is_active := v_member.tenant_is_active;
  tenant_preference := coalesce(v_member.tenant_preference, '{}'::jsonb);
  active_module_keys := coalesce(public.get_active_module_keys_for_tenant(v_member.tenant_id), '{}'::text[]);
  tenant_role_id := v_member.tenant_role_id;
  is_admin := coalesce(v_member.is_admin, false);
  effective_grants := v_grants;
  permission_version := v_perm_version;

  return next;
end;
$$;

grant execute on function public.get_app_bootstrap_context(text, bigint, bigint) to authenticated;

-- Redefine get_shop_bootstrap_context
drop function if exists public.get_shop_bootstrap_context(text, bigint, bigint);

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
    cgm.name,
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

grant execute on function public.get_shop_bootstrap_context(text, bigint, bigint) to authenticated;

-- Redefine get_investor_bootstrap_context
create or replace function public.get_investor_bootstrap_context(
  p_tenant_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_membership public.memberships;
  v_tenant public.tenants;
  v_perm_version bigint;
begin
  select * into v_tenant from public.tenants where id = p_tenant_id;
  if v_tenant.id is null then raise exception 'tenant not found'; end if;

  select * into v_membership
  from public.memberships m
  where m.tenant_id = p_tenant_id
    and lower(trim(m.email)) = public.current_user_email()
    and m.is_active = true
    and m.role = 'investor'::public.app_role
  limit 1;

  if v_membership.id is null then
    return jsonb_build_object('authenticated', false, 'tenant', row_to_json(v_tenant));
  end if;

  select version into v_perm_version
  from public.tenant_permission_versions
  where tenant_id = p_tenant_id;

  if v_perm_version is null then
    perform public.bump_tenant_permission_version(p_tenant_id);
    v_perm_version := 1;
  end if;

  return jsonb_build_object(
    'authenticated', true,
    'tenant', row_to_json(v_tenant),
    'investor_account', row_to_json(v_membership),
    'portfolio', public.get_investor_portfolio_summary(v_membership.investor_id),
    'module_keys', (
      select coalesce(jsonb_agg(tm.module_key), '[]'::jsonb)
      from public.tenant_modules tm
      where tm.tenant_id = p_tenant_id
        and tm.is_active = true
        and tm.module_key = 'investor_portal'
    ),
    'permission_version', v_perm_version
  );
end;
$$;

grant execute on function public.get_investor_bootstrap_context(bigint) to authenticated;

commit;
