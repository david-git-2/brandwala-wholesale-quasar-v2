begin;

-- ---------------------------------------------------------------------------
-- 1. System tenant_roles: Administrator -> Owner; add Manager template
-- ---------------------------------------------------------------------------
update public.tenant_roles
set
  name = 'Owner',
  slug = 'owner',
  source_app_role = 'owner'::public.app_role,
  is_admin = true
where scope = 'app'
  and slug = 'administrator'
  and is_system = true;

insert into public.tenant_roles (tenant_id, scope, name, slug, is_system, is_admin, source_app_role, is_active)
select
  t.id,
  'app',
  'Manager',
  'manager',
  true,
  false,
  'manager'::public.app_role,
  true
from public.tenants t
on conflict (tenant_id, scope, slug) do update
set
  name = excluded.name,
  source_app_role = excluded.source_app_role,
  is_system = true,
  is_active = true;

-- ---------------------------------------------------------------------------
-- 2. Backfill memberships: one owner per books group; demote other admins
-- (disable row triggers — guard_membership_update blocks role changes)
-- ---------------------------------------------------------------------------
alter table public.memberships disable trigger user;

create temp table _owner_backfill_pick (
  parent_tenant_id bigint primary key,
  membership_id bigint,
  email text,
  source text not null
) on commit drop;

insert into _owner_backfill_pick (parent_tenant_id, membership_id, email, source)
select
  books.parent_tenant_id,
  pick.membership_id,
  pick.email,
  pick.source
from (
  select distinct public.resolve_parent_tenant_id(t.id) as parent_tenant_id
  from public.tenants t
) books
cross join lateral (
  select
    m.id as membership_id,
    m.email,
    'parent'::text as source
  from public.memberships m
  where m.tenant_id = books.parent_tenant_id
    and m.role = 'admin'::public.app_role
    and m.is_active = true
  order by m.created_at asc, m.id asc
  limit 1
) pick
where pick.membership_id is not null;

insert into _owner_backfill_pick (parent_tenant_id, membership_id, email, source)
select
  books.parent_tenant_id,
  pick.membership_id,
  pick.email,
  pick.source
from (
  select distinct public.resolve_parent_tenant_id(t.id) as parent_tenant_id
  from public.tenants t
) books
cross join lateral (
  select
    m.id as membership_id,
    m.email,
    'child'::text as source
  from public.tenants child
  join public.memberships m on m.tenant_id = child.id
  where child.parent_id = books.parent_tenant_id
    and m.role = 'admin'::public.app_role
    and m.is_active = true
  order by m.created_at asc, m.id asc
  limit 1
) pick
where pick.membership_id is not null
  and not exists (
    select 1
    from _owner_backfill_pick existing
    where existing.parent_tenant_id = books.parent_tenant_id
  );

update public.memberships m
set
  role = 'owner'::public.app_role,
  tenant_role_id = (
    select tr.id
    from public.tenant_roles tr
    where tr.tenant_id = m.tenant_id
      and tr.scope = 'app'
      and tr.slug = 'owner'
    limit 1
  ),
  updated_at = now()
from _owner_backfill_pick pick
where pick.source = 'parent'
  and m.id = pick.membership_id;

insert into public.memberships (email, tenant_id, role, is_active, tenant_role_id)
select
  pick.email,
  pick.parent_tenant_id,
  'owner'::public.app_role,
  true,
  (
    select tr.id
    from public.tenant_roles tr
    where tr.tenant_id = pick.parent_tenant_id
      and tr.scope = 'app'
      and tr.slug = 'owner'
    limit 1
  )
from _owner_backfill_pick pick
where pick.source = 'child'
  and not exists (
    select 1
    from public.memberships existing
    where existing.tenant_id = pick.parent_tenant_id
      and lower(trim(existing.email)) = lower(trim(pick.email))
  );

update public.memberships m
set
  role = 'owner'::public.app_role,
  tenant_role_id = (
    select tr.id
    from public.tenant_roles tr
    where tr.tenant_id = m.tenant_id
      and tr.scope = 'app'
      and tr.slug = 'owner'
    limit 1
  ),
  updated_at = now()
from _owner_backfill_pick pick
where pick.source = 'child'
  and m.tenant_id = pick.parent_tenant_id
  and lower(trim(m.email)) = lower(trim(pick.email))
  and m.role <> 'owner'::public.app_role;

-- Remaining admin rows -> manager
update public.memberships m
set
  role = 'manager'::public.app_role,
  tenant_role_id = (
    select tr.id
    from public.tenant_roles tr
    where tr.tenant_id = m.tenant_id
      and tr.scope = 'app'
      and tr.slug = 'manager'
    limit 1
  ),
  updated_at = now()
where m.role = 'admin'::public.app_role;

alter table public.memberships enable trigger user;

-- ---------------------------------------------------------------------------
-- 3. Constraints: one active owner per tenant; owner only on parent/standalone
-- ---------------------------------------------------------------------------
create unique index if not exists memberships_one_active_owner_per_tenant_idx
  on public.memberships (tenant_id)
  where role = 'owner'::public.app_role and is_active = true;

create or replace function public.trg_fn_memberships_owner_placement()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_parent_id bigint;
begin
  if new.role = 'admin'::public.app_role then
    raise exception 'app_role admin is retired; use owner, manager, staff, or viewer';
  end if;

  if new.role = 'owner'::public.app_role then
    select t.parent_id into v_parent_id
    from public.tenants t
    where t.id = new.tenant_id;

    if v_parent_id is not null then
      raise exception 'Owner membership must be on the parent or standalone tenant, not a child desk';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_memberships_owner_placement on public.memberships;
create trigger trg_memberships_owner_placement
  before insert or update of role, tenant_id on public.memberships
  for each row
  execute function public.trg_fn_memberships_owner_placement();

-- ---------------------------------------------------------------------------
-- 4. Default tenant_role mapping for new memberships
-- ---------------------------------------------------------------------------
create or replace function public.trg_fn_assign_default_membership_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role_slug text;
  v_role_id bigint;
begin
  if new.tenant_role_id is null and new.tenant_id is not null and new.role is not null then
    v_role_slug := case new.role
      when 'owner' then 'owner'
      when 'manager' then 'manager'
      when 'staff' then 'staff'
      when 'viewer' then 'viewer'
      else 'viewer'
    end;

    select id into v_role_id
    from public.tenant_roles
    where tenant_id = new.tenant_id
      and scope = 'app'
      and slug = v_role_slug;

    new.tenant_role_id := v_role_id;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Last-owner guardrail (replaces last-admin)
-- ---------------------------------------------------------------------------
create or replace function public.trg_fn_memberships_permission_guardrails()
returns trigger
language plpgsql
security definer
as $$
declare
  v_role_scope text;
  v_role_tenant bigint;
begin
  if new.tenant_role_id is not null then
    select scope, tenant_id into v_role_scope, v_role_tenant
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
      v_was_owner boolean;
      v_is_owner boolean;
      v_active_owners int;
    begin
      v_was_owner := old.role = 'owner'::public.app_role;
      v_is_owner := new.is_active = true and new.role = 'owner'::public.app_role;

      if v_was_owner and not v_is_owner then
        select count(*) into v_active_owners
        from public.memberships m
        where m.tenant_id = old.tenant_id
          and m.is_active = true
          and m.id <> old.id
          and m.role = 'owner'::public.app_role;

        if v_active_owners = 0 then
          raise exception 'Cannot downgrade or deactivate the last active owner for this tenant';
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

-- ---------------------------------------------------------------------------
-- 6. Seed helper for new tenants
-- ---------------------------------------------------------------------------
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
    (p_tenant_id, 'app', 'Owner', 'owner', true, true, 'owner'::public.app_role),
    (p_tenant_id, 'app', 'Manager', 'manager', true, false, 'manager'::public.app_role),
    (p_tenant_id, 'app', 'Staff', 'staff', true, false, 'staff'::public.app_role),
    (p_tenant_id, 'app', 'Viewer', 'viewer', true, false, 'viewer'::public.app_role)
  on conflict (tenant_id, scope, slug) do nothing;

  insert into public.tenant_roles (tenant_id, scope, name, slug, is_system, is_admin, source_app_role)
  values
    (p_tenant_id, 'shop', 'Customer Admin', 'customer-admin', true, false, null),
    (p_tenant_id, 'shop', 'Negotiator', 'negotiator', true, false, null),
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

commit;
