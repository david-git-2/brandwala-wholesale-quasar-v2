begin;

-- =========================================================
-- 1. Create Core Permissions Tables
-- =========================================================

-- module_actions
create table if not exists public.module_actions (
  id bigserial primary key,
  module_key text not null references public.modules(key) on delete cascade,
  action text not null,
  description text,
  scope text not null check (scope in ('app', 'shop', 'platform', 'investor')),
  tenant_configurable boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint module_actions_module_key_action_unique unique (module_key, action)
);

create trigger trg_module_actions_updated_at
  before update on public.module_actions
  for each row execute function public.set_updated_at();

-- tenant_roles
create table if not exists public.tenant_roles (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  scope text not null check (scope in ('app', 'shop')),
  name text not null,
  slug text not null,
  is_system boolean not null default false,
  is_admin boolean not null default false,
  source_app_role public.app_role null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint tenant_roles_tenant_scope_slug_unique unique (tenant_id, scope, slug)
);

create trigger trg_tenant_roles_updated_at
  before update on public.tenant_roles
  for each row execute function public.set_updated_at();

-- system_role_templates
create table if not exists public.system_role_templates (
  id bigserial primary key,
  scope text not null check (scope in ('app', 'shop')),
  role_slug text not null,
  module_key text not null references public.modules(key) on delete cascade,
  action text not null,
  allowed boolean not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint system_role_templates_scope_slug_module_action_unique unique (scope, role_slug, module_key, action)
);

create trigger trg_system_role_templates_updated_at
  before update on public.system_role_templates
  for each row execute function public.set_updated_at();

-- tenant_role_grants
create table if not exists public.tenant_role_grants (
  id bigserial primary key,
  tenant_role_id bigint not null references public.tenant_roles(id) on delete cascade,
  module_key text not null references public.modules(key) on delete cascade,
  action text not null,
  allowed boolean not null,
  updated_by_email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint tenant_role_grants_role_module_action_unique unique (tenant_role_id, module_key, action)
);

create trigger trg_tenant_role_grants_updated_at
  before update on public.tenant_role_grants
  for each row execute function public.set_updated_at();

-- membership_grants
create table if not exists public.membership_grants (
  id bigserial primary key,
  membership_id bigint not null references public.memberships(id) on delete cascade,
  module_key text not null references public.modules(key) on delete cascade,
  action text not null,
  effect text not null check (effect in ('allow', 'deny')),
  created_by_email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint membership_grants_membership_module_action_unique unique (membership_id, module_key, action)
);

create trigger trg_membership_grants_updated_at
  before update on public.membership_grants
  for each row execute function public.set_updated_at();

-- customer_group_member_grants
create table if not exists public.customer_group_member_grants (
  id bigserial primary key,
  customer_group_member_id bigint not null references public.customer_group_members(id) on delete cascade,
  module_key text not null references public.modules(key) on delete cascade,
  action text not null,
  effect text not null check (effect in ('allow', 'deny')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint customer_group_member_grants_cgm_module_action_unique unique (customer_group_member_id, module_key, action)
);

create trigger trg_customer_group_member_grants_updated_at
  before update on public.customer_group_member_grants
  for each row execute function public.set_updated_at();

-- =========================================================
-- 2. Alter Actor Tables
-- =========================================================

-- Add tenant_role_id to memberships
alter table public.memberships
  add column if not exists tenant_role_id bigint references public.tenant_roles(id) on delete restrict;

create index if not exists memberships_tenant_role_id_idx on public.memberships(tenant_role_id);

-- Add tenant_role_id to customer_group_members
alter table public.customer_group_members
  add column if not exists tenant_role_id bigint references public.tenant_roles(id) on delete restrict;

create index if not exists customer_group_members_tenant_role_id_idx on public.customer_group_members(tenant_role_id);

-- =========================================================
-- 3. Core Helper: check caller is tenant administrator
-- =========================================================
create or replace function public.user_is_tenant_admin(p_tenant_id bigint)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if public.is_superadmin() then
    return true;
  end if;

  return exists (
    select 1
    from public.memberships m
    left join public.tenant_roles tr on tr.id = m.tenant_role_id
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and (
        m.role = 'admin'
        or tr.is_admin = true
      )
  );
end;
$$;

grant execute on function public.user_is_tenant_admin(bigint) to authenticated;

-- =========================================================
-- 4. Core Function: seed_tenant_roles_and_grants
-- =========================================================
create or replace function public.seed_tenant_roles_and_grants(p_tenant_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role record;
begin
  -- App default roles
  insert into public.tenant_roles (tenant_id, scope, name, slug, is_system, is_admin, source_app_role)
  values
    (p_tenant_id, 'app', 'Administrator', 'administrator', true, true, 'admin'::public.app_role),
    (p_tenant_id, 'app', 'Staff', 'staff', true, false, 'staff'::public.app_role),
    (p_tenant_id, 'app', 'Viewer', 'viewer', true, false, 'viewer'::public.app_role)
  on conflict (tenant_id, scope, slug) do nothing;

  -- Shop default roles
  insert into public.tenant_roles (tenant_id, scope, name, slug, is_system, is_admin, source_app_role)
  values
    (p_tenant_id, 'shop', 'Customer Admin', 'customer-admin', true, false, null),
    (p_tenant_id, 'shop', 'Negotiator', 'negotiator', true, false, null),
    (p_tenant_id, 'shop', 'Customer Staff', 'customer-staff', true, false, null)
  on conflict (tenant_id, scope, slug) do nothing;

  -- Seed role grants from templates
  for v_role in (
    select id, scope, slug
    from public.tenant_roles
    where tenant_id = p_tenant_id and is_admin = false
  ) loop
    insert into public.tenant_role_grants (tenant_role_id, module_key, action, allowed)
    select v_role.id, t.module_key, t.action, t.allowed
    from public.system_role_templates t
    where t.scope = v_role.scope and t.role_slug = v_role.slug
    on conflict (tenant_role_id, module_key, action) do update set
      allowed = excluded.allowed;
  end loop;
end;
$$;

grant execute on function public.seed_tenant_roles_and_grants(bigint) to authenticated;

-- =========================================================
-- 5. Seed Existing Tenants & Memberships
-- =========================================================

-- Seed standard roles on existing tenants
select public.seed_tenant_roles_and_grants(id) from public.tenants;

-- Disable memberships guard trigger during backend backfill update
alter table public.memberships disable trigger trg_memberships_guard_update;

-- Backfill memberships.tenant_role_id
update public.memberships m
set tenant_role_id = tr.id
from public.tenant_roles tr
where m.tenant_role_id is null
  and m.tenant_id = tr.tenant_id
  and tr.scope = 'app'
  and (
    (m.role = 'admin' and tr.slug = 'administrator') or
    (m.role = 'staff' and tr.slug = 'staff') or
    (m.role = 'viewer' and tr.slug = 'viewer')
  );

-- Re-enable memberships guard trigger
alter table public.memberships enable trigger trg_memberships_guard_update;

-- Backfill customer_group_members.tenant_role_id
update public.customer_group_members cgm
set tenant_role_id = tr.id
from public.customer_groups cg
join public.tenant_roles tr on tr.tenant_id = cg.tenant_id and tr.scope = 'shop'
where cgm.tenant_role_id is null
  and cgm.customer_group_id = cg.id
  and (
    (cgm.role = 'admin' and tr.slug = 'customer-admin') or
    (cgm.role = 'negotiator' and tr.slug = 'negotiator') or
    (cgm.role = 'staff' and tr.slug = 'customer-staff')
  );

-- =========================================================
-- 6. Trigger: Seed system roles on Tenant Create
-- =========================================================
create or replace function public.trg_fn_seed_new_tenant()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.seed_tenant_roles_and_grants(new.id);
  return new;
end;
$$;

drop trigger if exists trg_after_tenant_insert on public.tenants;
create trigger trg_after_tenant_insert
  after insert on public.tenants
  for each row
  execute function public.trg_fn_seed_new_tenant();

-- =========================================================
-- 7. Trigger: Assign default role on Membership Insert
-- =========================================================
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
      when 'admin' then 'administrator'
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

drop trigger if exists trg_before_membership_insert on public.memberships;
create trigger trg_before_membership_insert
  before insert on public.memberships
  for each row
  execute function public.trg_fn_assign_default_membership_role();

-- =========================================================
-- 8. Trigger: Assign default role on Customer Member Insert
-- =========================================================
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
        when 'negotiator' then 'negotiator'
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

drop trigger if exists trg_before_customer_member_insert on public.customer_group_members;
create trigger trg_before_customer_member_insert
  before insert on public.customer_group_members
  for each row
  execute function public.trg_fn_assign_default_customer_role();

-- =========================================================
-- 9. Resolution Function: has_module_action
-- =========================================================
create or replace function public.has_module_action(
  p_tenant_id bigint,
  p_module_key text,
  p_action text
)
returns boolean
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_action_scope text;
  v_action_active boolean;
  v_member_id bigint;
  v_tenant_role_id bigint;
  v_role_is_admin boolean;
  v_override_effect text;
  v_role_allowed boolean;
  v_shop_allowed boolean;
begin
  -- Superadmin bypass
  if public.is_superadmin() then
    return true;
  end if;

  -- 1. Check action exists and is active
  select scope, is_active
  into v_action_scope, v_action_active
  from public.module_actions
  where module_key = p_module_key and action = p_action;

  if v_action_active is not true then
    return false;
  end if;

  -- 2. Platform scope check
  if v_action_scope = 'platform' then
    return false; -- only superadmins can run platform actions, handled in superadmin bypass above
  end if;

  -- 3. Check tenant module status
  if not exists (
    select 1
    from public.tenant_modules
    where tenant_id = p_tenant_id
      and module_key = p_module_key
      and is_active = true
  ) then
    return false;
  end if;

  -- 4. parent/child hierarchy blocks module for tenant
  if exists (
    select 1
    from public.tenants
    where id = p_tenant_id
      and parent_id is not null
  ) and p_module_key in (
    'global_shipment', 'global_stock', 'global_stock_type', 'procurement_stock',
    'shipment_reports', 'parent_dashboard', 'investor_reports',
    'investor_profiles', 'investor_capital_ledger', 'investor_shipment_share', 'investor_portal'
  ) then
    return false;
  end if;

  -- 5. Resolve actor and check permissions
  if v_action_scope in ('app', 'investor') then
    -- App/investor scope actor lookup
    select m.id, m.tenant_role_id, tr.is_admin
    into v_member_id, v_tenant_role_id, v_role_is_admin
    from public.memberships m
    left join public.tenant_roles tr on tr.id = m.tenant_role_id
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true;

    if v_member_id is null then
      return false;
    end if;

    -- Administrator shortcut
    if coalesce(v_role_is_admin, false) = true then
      return true;
    end if;

    -- Member overrides
    select effect
    into v_override_effect
    from public.membership_grants
    where membership_id = v_member_id
      and module_key = p_module_key
      and action = p_action;

    if v_override_effect = 'deny' then
      return false;
    elsif v_override_effect = 'allow' then
      return true;
    end if;

    -- Role grants
    select allowed
    into v_role_allowed
    from public.tenant_role_grants
    where tenant_role_id = v_tenant_role_id
      and module_key = p_module_key
      and action = p_action;

    return coalesce(v_role_allowed, false);

  elsif v_action_scope = 'shop' then
    -- Shop scope actor lookup (handles multiple groups)
    if exists (
      select 1
      from public.customer_group_members cgm
      join public.customer_groups cg on cg.id = cgm.customer_group_id
      join public.tenant_roles tr on tr.id = cgm.tenant_role_id
      where cg.tenant_id = p_tenant_id
        and cg.is_active = true
        and cgm.is_active = true
        and lower(trim(cgm.email)) = public.current_user_email()
        and tr.is_admin = true
    ) then
      return true;
    end if;

    -- Resolve overrides and role grants
    select
      coalesce(
        bool_or(case when g.effect = 'allow' then true else null end),
        bool_or(case when g.effect = 'deny' then false else null end),
        bool_or(rg.allowed)
      ) into v_shop_allowed
    from public.customer_group_members cgm
    join public.customer_groups cg on cg.id = cgm.customer_group_id
    left join public.customer_group_member_grants g
      on g.customer_group_member_id = cgm.id
      and g.module_key = p_module_key
      and g.action = p_action
    left join public.tenant_role_grants rg
      on rg.tenant_role_id = cgm.tenant_role_id
      and rg.module_key = p_module_key
      and rg.action = p_action
    where cg.tenant_id = p_tenant_id
      and cg.is_active = true
      and cgm.is_active = true
      and lower(trim(cgm.email)) = public.current_user_email();

    return coalesce(v_shop_allowed, false);
  end if;

  return false;
end;
$$;

grant execute on function public.has_module_action(bigint, text, text) to authenticated;

-- =========================================================
-- 10. Helper Function: get_effective_grants
-- =========================================================
create or replace function public.get_effective_grants(p_tenant_id bigint)
returns table (module_key text, action text)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_member_id bigint;
  v_tenant_role_id bigint;
  v_role_is_admin boolean;
begin
  select m.id, m.tenant_role_id, tr.is_admin
  into v_member_id, v_tenant_role_id, v_role_is_admin
  from public.memberships m
  left join public.tenant_roles tr on tr.id = m.tenant_role_id
  where m.tenant_id = p_tenant_id
    and lower(trim(m.email)) = public.current_user_email()
    and m.is_active = true;

  if public.is_superadmin() or coalesce(v_role_is_admin, false) = true then
    return query
    select ma.module_key, ma.action
    from public.module_actions ma
    join public.tenant_modules tm on tm.module_key = ma.module_key
    where tm.tenant_id = p_tenant_id
      and tm.is_active = true
      and ma.is_active = true
      and (ma.scope <> 'platform' or public.is_superadmin())
      and not (
        exists (
          select 1
          from public.tenants
          where id = p_tenant_id
            and parent_id is not null
        ) and ma.module_key in (
          'global_shipment', 'global_stock', 'global_stock_type', 'procurement_stock',
          'shipment_reports', 'parent_dashboard', 'investor_reports',
          'investor_profiles', 'investor_capital_ledger', 'investor_shipment_share', 'investor_portal'
        )
      );
    return;
  end if;

  return query
  with role_allowed as (
    select rg.module_key, rg.action
    from public.tenant_role_grants rg
    where rg.tenant_role_id = v_tenant_role_id
      and rg.allowed = true
  ),
  with_overrides as (
    select ra.module_key, ra.action from role_allowed ra
    union
    select mg.module_key, mg.action
    from public.membership_grants mg
    where mg.membership_id = v_member_id
      and mg.effect = 'allow'
  ),
  effective as (
    select wo.module_key, wo.action from with_overrides wo
    except
    select mg.module_key, mg.action
    from public.membership_grants mg
    where mg.membership_id = v_member_id
      and mg.effect = 'deny'
  )
  select e.module_key, e.action
  from effective e
  join public.module_actions ma on ma.module_key = e.module_key and ma.action = e.action
  join public.tenant_modules tm on tm.module_key = e.module_key
  where tm.tenant_id = p_tenant_id
    and tm.is_active = true
    and ma.is_active = true
    and (ma.scope <> 'platform' or public.is_superadmin())
    and not (
      exists (
        select 1
        from public.tenants
        where id = p_tenant_id
          and parent_id is not null
      ) and ma.module_key in (
        'global_shipment', 'global_stock', 'global_stock_type', 'procurement_stock',
        'shipment_reports', 'parent_dashboard', 'investor_reports',
        'investor_profiles', 'investor_capital_ledger', 'investor_shipment_share', 'investor_portal'
      )
    );
end;
$$;

grant execute on function public.get_effective_grants(bigint) to authenticated;

-- =========================================================
-- 11. Helper Function: get_shop_effective_grants
-- =========================================================
create or replace function public.get_shop_effective_grants(
  p_tenant_id bigint,
  p_customer_group_member_id bigint
)
returns table (module_key text, action text)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_tenant_role_id bigint;
  v_role_is_admin boolean;
begin
  select cgm.tenant_role_id, tr.is_admin
  into v_tenant_role_id, v_role_is_admin
  from public.customer_group_members cgm
  left join public.tenant_roles tr on tr.id = cgm.tenant_role_id
  where cgm.id = p_customer_group_member_id
    and cgm.is_active = true;

  if coalesce(v_role_is_admin, false) = true then
    return query
    select ma.module_key, ma.action
    from public.module_actions ma
    join public.tenant_modules tm on tm.module_key = ma.module_key
    where tm.tenant_id = p_tenant_id
      and tm.is_active = true
      and ma.is_active = true
      and ma.scope = 'shop';
    return;
  end if;

  return query
  with role_allowed as (
    select rg.module_key, rg.action
    from public.tenant_role_grants rg
    where rg.tenant_role_id = v_tenant_role_id
      and rg.allowed = true
  ),
  with_overrides as (
    select ra.module_key, ra.action from role_allowed ra
    union
    select g.module_key, g.action
    from public.customer_group_member_grants g
    where g.customer_group_member_id = p_customer_group_member_id
      and g.effect = 'allow'
  ),
  effective as (
    select wo.module_key, wo.action from with_overrides wo
    except
    select g.module_key, g.action
    from public.customer_group_member_grants g
    where g.customer_group_member_id = p_customer_group_member_id
      and g.effect = 'deny'
  )
  select e.module_key, e.action
  from effective e
  join public.module_actions ma on ma.module_key = e.module_key and ma.action = e.action
  join public.tenant_modules tm on tm.module_key = e.module_key
  where tm.tenant_id = p_tenant_id
    and tm.is_active = true
    and ma.is_active = true
    and ma.scope = 'shop';
end;
$$;

grant execute on function public.get_shop_effective_grants(bigint, bigint) to authenticated;

-- =========================================================
-- 12. Redefine Bootstrap Contexts
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
  effective_grants jsonb
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
  effective_grants jsonb
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

  return next;
end;
$$;

grant execute on function public.get_shop_bootstrap_context(text, bigint, bigint) to authenticated;

-- =========================================================
-- 13. Grant & Role CRUD RPCs
-- =========================================================

-- list_tenant_roles
create or replace function public.list_tenant_roles(p_tenant_id bigint, p_scope text)
returns table (
  id bigint,
  tenant_id bigint,
  scope text,
  name text,
  slug text,
  is_system boolean,
  is_admin boolean,
  source_app_role public.app_role,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.is_superadmin() and not exists (
    select 1 from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Access denied';
  end if;

  return query
  select r.id, r.tenant_id, r.scope, r.name, r.slug, r.is_system, r.is_admin, r.source_app_role, r.is_active, r.created_at, r.updated_at
  from public.tenant_roles r
  where r.tenant_id = p_tenant_id
    and r.scope = p_scope
    and r.is_active = true;
end;
$$;

grant execute on function public.list_tenant_roles(bigint, text) to authenticated;

-- create_tenant_role
create or replace function public.create_tenant_role(
  p_tenant_id bigint,
  p_scope text,
  p_name text,
  p_slug text,
  p_is_admin boolean default false
)
returns public.tenant_roles
language plpgsql
security definer
set search_path = public
volatile
as $$
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
$$;

grant execute on function public.create_tenant_role(bigint, text, text, text, boolean) to authenticated;

-- update_tenant_role
create or replace function public.update_tenant_role(
  p_role_id bigint,
  p_name text,
  p_is_admin boolean
)
returns public.tenant_roles
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  v_row public.tenant_roles;
begin
  select * into v_row from public.tenant_roles where id = p_role_id;

  if v_row.id is null then
    raise exception 'Role not found';
  end if;

  if not public.user_is_tenant_admin(v_row.tenant_id) then
    raise exception 'Unauthorized';
  end if;

  if p_is_admin = true and v_row.is_admin = false and exists (
    select 1 from public.tenant_roles
    where tenant_id = v_row.tenant_id and scope = v_row.scope and is_admin = true and id <> p_role_id
  ) then
    raise exception 'Only one Administrator role is allowed per scope';
  end if;

  if v_row.is_system = true and v_row.is_admin <> p_is_admin then
    raise exception 'Cannot modify admin status of system roles';
  end if;

  update public.tenant_roles
  set
    name = trim(p_name),
    is_admin = p_is_admin,
    updated_at = now()
  where id = p_role_id
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.update_tenant_role(bigint, text, boolean) to authenticated;

-- delete_tenant_role
create or replace function public.delete_tenant_role(p_role_id bigint)
returns void
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  v_row public.tenant_roles;
begin
  select * into v_row from public.tenant_roles where id = p_role_id;

  if v_row.id is null then
    raise exception 'Role not found';
  end if;

  if not public.user_is_tenant_admin(v_row.tenant_id) then
    raise exception 'Unauthorized';
  end if;

  if v_row.is_system = true then
    raise exception 'Cannot delete system roles';
  end if;

  if exists (
    select 1 from public.memberships where tenant_role_id = p_role_id
  ) then
    raise exception 'Cannot delete role: members are currently assigned to it';
  end if;

  if exists (
    select 1 from public.customer_group_members where tenant_role_id = p_role_id
  ) then
    raise exception 'Cannot delete role: customer group members are currently assigned to it';
  end if;

  delete from public.tenant_roles where id = p_role_id;
end;
$$;

grant execute on function public.delete_tenant_role(bigint) to authenticated;

-- list_tenant_role_grants
create or replace function public.list_tenant_role_grants(p_tenant_role_id bigint)
returns table (
  id bigint,
  tenant_role_id bigint,
  module_key text,
  action text,
  allowed boolean,
  updated_by_email text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id from public.tenant_roles where id = p_tenant_role_id;

  if v_tenant_id is null then
    raise exception 'Role not found';
  end if;

  if not public.is_superadmin() and not exists (
    select 1 from public.memberships
    where tenant_id = v_tenant_id
      and lower(trim(email)) = public.current_user_email()
      and is_active = true
  ) then
    raise exception 'Access denied';
  end if;

  return query
  select rg.id, rg.tenant_role_id, rg.module_key, rg.action, rg.allowed, rg.updated_by_email, rg.created_at, rg.updated_at
  from public.tenant_role_grants rg
  where rg.tenant_role_id = p_tenant_role_id;
end;
$$;

grant execute on function public.list_tenant_role_grants(bigint) to authenticated;

-- upsert_tenant_role_grant
create or replace function public.upsert_tenant_role_grant(
  p_tenant_role_id bigint,
  p_module_key text,
  p_action text,
  p_allowed boolean
)
returns public.tenant_role_grants
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  v_role public.tenant_roles;
  v_row public.tenant_role_grants;
begin
  select * into v_role from public.tenant_roles where id = p_tenant_role_id;

  if v_role.id is null then
    raise exception 'Role not found';
  end if;

  if not public.user_is_tenant_admin(v_role.tenant_id) then
    raise exception 'Unauthorized';
  end if;

  if v_role.is_admin = true then
    raise exception 'Cannot assign explicit grants to an Administrator role';
  end if;

  if not exists (
    select 1 from public.tenant_modules
    where tenant_id = v_role.tenant_id and module_key = p_module_key and is_active = true
  ) then
    raise exception 'Module is not active for this tenant';
  end if;

  if not exists (
    select 1 from public.module_actions
    where module_key = p_module_key and action = p_action and is_active = true
  ) then
    raise exception 'Invalid or inactive action: % for module %', p_action, p_module_key;
  end if;

  insert into public.tenant_role_grants (
    tenant_role_id,
    module_key,
    action,
    allowed,
    updated_by_email
  )
  values (
    p_tenant_role_id,
    p_module_key,
    p_action,
    p_allowed,
    public.current_user_email()
  )
  on conflict (tenant_role_id, module_key, action) do update set
    allowed = excluded.allowed,
    updated_by_email = excluded.updated_by_email,
    updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.upsert_tenant_role_grant(bigint, text, text, boolean) to authenticated;

-- assign_membership_role
create or replace function public.assign_membership_role(
  p_membership_id bigint,
  p_tenant_role_id bigint
)
returns public.memberships
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  v_member public.memberships;
  v_role public.tenant_roles;
begin
  select * into v_member from public.memberships where id = p_membership_id;
  if v_member.id is null then
    raise exception 'Membership not found';
  end if;

  if not public.user_is_tenant_admin(v_member.tenant_id) then
    raise exception 'Unauthorized';
  end if;

  select * into v_role from public.tenant_roles where id = p_tenant_role_id;
  if v_role.id is null then
    raise exception 'Role not found';
  end if;

  if v_role.tenant_id <> v_member.tenant_id then
    raise exception 'Role and Membership must belong to the same tenant';
  end if;

  if v_role.scope <> 'app' then
    raise exception 'Role scope must be app for internal memberships';
  end if;

  update public.memberships
  set
    tenant_role_id = p_tenant_role_id,
    updated_at = now()
  where id = p_membership_id
  returning * into v_member;

  return v_member;
end;
$$;

grant execute on function public.assign_membership_role(bigint, bigint) to authenticated;

-- assign_customer_group_member_role
create or replace function public.assign_customer_group_member_role(
  p_cgm_id bigint,
  p_tenant_role_id bigint
)
returns public.customer_group_members
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  v_member public.customer_group_members;
  v_group public.customer_groups;
  v_role public.tenant_roles;
begin
  select * into v_member from public.customer_group_members where id = p_cgm_id;
  if v_member.id is null then
    raise exception 'Customer group member not found';
  end if;

  select * into v_group from public.customer_groups where id = v_member.customer_group_id;
  if v_group.id is null then
    raise exception 'Customer group not found';
  end if;

  if not public.user_is_tenant_admin(v_group.tenant_id) then
    raise exception 'Unauthorized';
  end if;

  select * into v_role from public.tenant_roles where id = p_tenant_role_id;
  if v_role.id is null then
    raise exception 'Role not found';
  end if;

  if v_role.tenant_id <> v_group.tenant_id then
    raise exception 'Role and Customer group member must belong to the same tenant';
  end if;

  if v_role.scope <> 'shop' then
    raise exception 'Role scope must be shop for customer group members';
  end if;

  update public.customer_group_members
  set
    tenant_role_id = p_tenant_role_id,
    updated_at = now()
  where id = p_cgm_id
  returning * into v_member;

  return v_member;
end;
$$;

grant execute on function public.assign_customer_group_member_role(bigint, bigint) to authenticated;

-- list_membership_grants
create or replace function public.list_membership_grants(p_membership_id bigint)
returns table (
  id bigint,
  membership_id bigint,
  module_key text,
  action text,
  effect text,
  created_by_email text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id from public.memberships where id = p_membership_id;
  if v_tenant_id is null then
    raise exception 'Membership not found';
  end if;

  if not public.is_superadmin() and not exists (
    select 1 from public.memberships
    where tenant_id = v_tenant_id
      and lower(trim(email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Access denied';
  end if;

  return query
  select mg.id, mg.membership_id, mg.module_key, mg.action, mg.effect, mg.created_by_email, mg.created_at, mg.updated_at
  from public.membership_grants mg
  where mg.membership_id = p_membership_id;
end;
$$;

grant execute on function public.list_membership_grants(bigint) to authenticated;

-- upsert_membership_grant
create or replace function public.upsert_membership_grant(
  p_membership_id bigint,
  p_module_key text,
  p_action text,
  p_effect text
)
returns public.membership_grants
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  v_member public.memberships;
  v_row public.membership_grants;
begin
  select * into v_member from public.memberships where id = p_membership_id;
  if v_member.id is null then
    raise exception 'Membership not found';
  end if;

  if not public.user_is_tenant_admin(v_member.tenant_id) then
    raise exception 'Unauthorized';
  end if;

  if p_effect not in ('allow', 'deny') then
    raise exception 'Invalid effect: %', p_effect;
  end if;

  if not exists (
    select 1 from public.tenant_modules
    where tenant_id = v_member.tenant_id and module_key = p_module_key and is_active = true
  ) then
    raise exception 'Module is not active for this tenant';
  end if;

  if not exists (
    select 1 from public.module_actions
    where module_key = p_module_key and action = p_action and is_active = true
  ) then
    raise exception 'Invalid or inactive action: % for module %', p_action, p_module_key;
  end if;

  insert into public.membership_grants (
    membership_id,
    module_key,
    action,
    effect,
    created_by_email
  )
  values (
    p_membership_id,
    p_module_key,
    p_action,
    p_effect,
    public.current_user_email()
  )
  on conflict (membership_id, module_key, action) do update set
    effect = excluded.effect,
    created_by_email = excluded.created_by_email,
    updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.upsert_membership_grant(bigint, text, text, text) to authenticated;

-- list_customer_group_member_grants
create or replace function public.list_customer_group_member_grants(p_cgm_id bigint)
returns table (
  id bigint,
  customer_group_member_id bigint,
  module_key text,
  action text,
  effect text
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_tenant_id bigint;
begin
  select cg.tenant_id into v_tenant_id
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  where cgm.id = p_cgm_id;

  if v_tenant_id is null then
    raise exception 'Customer group member not found';
  end if;

  if not public.is_superadmin() and not exists (
    select 1 from public.memberships
    where tenant_id = v_tenant_id
      and lower(trim(email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Access denied';
  end if;

  return query
  select cgmg.id, cgmg.customer_group_member_id, cgmg.module_key, cgmg.action, cgmg.effect
  from public.customer_group_member_grants cgmg
  where cgmg.customer_group_member_id = p_cgm_id;
end;
$$;

grant execute on function public.list_customer_group_member_grants(bigint) to authenticated;

-- upsert_customer_group_member_grant
create or replace function public.upsert_customer_group_member_grant(
  p_cgm_id bigint,
  p_module_key text,
  p_action text,
  p_effect text
)
returns public.customer_group_member_grants
language plpgsql
security definer
set search_path = public
volatile
as $$
declare
  v_member public.customer_group_members;
  v_group public.customer_groups;
  v_row public.customer_group_member_grants;
begin
  select * into v_member from public.customer_group_members where id = p_cgm_id;
  if v_member.id is null then
    raise exception 'Customer group member not found';
  end if;

  select * into v_group from public.customer_groups where id = v_member.customer_group_id;
  if v_group.id is null then
    raise exception 'Customer group not found';
  end if;

  if not public.user_is_tenant_admin(v_group.tenant_id) then
    raise exception 'Unauthorized';
  end if;

  if p_effect not in ('allow', 'deny') then
    raise exception 'Invalid effect: %', p_effect;
  end if;

  if not exists (
    select 1 from public.tenant_modules
    where tenant_id = v_group.tenant_id and module_key = p_module_key and is_active = true
  ) then
    raise exception 'Module is not active for this tenant';
  end if;

  if not exists (
    select 1 from public.module_actions
    where module_key = p_module_key and action = p_action and is_active = true
  ) then
    raise exception 'Invalid or inactive action: % for module %', p_action, p_module_key;
  end if;

  insert into public.customer_group_member_grants (
    customer_group_member_id,
    module_key,
    action,
    effect
  )
  values (
    p_cgm_id,
    p_module_key,
    p_action,
    p_effect
  )
  on conflict (customer_group_member_id, module_key, action) do update set
    effect = excluded.effect
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.upsert_customer_group_member_grant(bigint, text, text, text) to authenticated;

-- =========================================================
-- 14. Row Level Security Policies
-- =========================================================

-- Enable RLS
alter table public.module_actions enable row level security;
alter table public.tenant_roles enable row level security;
alter table public.system_role_templates enable row level security;
alter table public.tenant_role_grants enable row level security;
alter table public.membership_grants enable row level security;
alter table public.customer_group_member_grants enable row level security;

-- module_actions policies
create policy "module_actions_select_all"
  on public.module_actions for select
  to authenticated
  using (true);

create policy "module_actions_write_superadmin"
  on public.module_actions for all
  to authenticated
  using (public.is_superadmin())
  with check (public.is_superadmin());

-- system_role_templates policies
create policy "system_role_templates_select_all"
  on public.system_role_templates for select
  to authenticated
  using (true);

create policy "system_role_templates_write_superadmin"
  on public.system_role_templates for all
  to authenticated
  using (public.is_superadmin())
  with check (public.is_superadmin());

-- tenant_roles policies
create policy "tenant_roles_select_member"
  on public.tenant_roles for select
  to authenticated
  using (
    exists (
      select 1 from public.memberships m
      where m.tenant_id = tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    ) or public.is_superadmin()
  );

create policy "tenant_roles_write_admin"
  on public.tenant_roles for all
  to authenticated
  using (public.user_is_tenant_admin(tenant_id))
  with check (public.user_is_tenant_admin(tenant_id));

-- tenant_role_grants policies
create policy "tenant_role_grants_select_member"
  on public.tenant_role_grants for select
  to authenticated
  using (
    exists (
      select 1 from public.tenant_roles tr
      join public.memberships m on m.tenant_id = tr.tenant_id
      where tr.id = tenant_role_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    ) or public.is_superadmin()
  );

create policy "tenant_role_grants_write_admin"
  on public.tenant_role_grants for all
  to authenticated
  using (
    exists (
      select 1 from public.tenant_roles tr
      where tr.id = tenant_role_id
        and public.user_is_tenant_admin(tr.tenant_id)
    )
  )
  with check (
    exists (
      select 1 from public.tenant_roles tr
      where tr.id = tenant_role_id
        and public.user_is_tenant_admin(tr.tenant_id)
    )
  );

-- membership_grants policies
create policy "membership_grants_select_member"
  on public.membership_grants for select
  to authenticated
  using (
    exists (
      select 1 from public.memberships target
      join public.memberships caller on caller.tenant_id = target.tenant_id
      where target.id = membership_id
        and lower(trim(caller.email)) = public.current_user_email()
        and caller.is_active = true
    ) or public.is_superadmin()
  );

create policy "membership_grants_write_admin"
  on public.membership_grants for all
  to authenticated
  using (
    exists (
      select 1 from public.memberships m
      where m.id = membership_id
        and public.user_is_tenant_admin(m.tenant_id)
    )
  )
  with check (
    exists (
      select 1 from public.memberships m
      where m.id = membership_id
        and public.user_is_tenant_admin(m.tenant_id)
    )
  );

-- customer_group_member_grants policies
create policy "cg_member_grants_select_member"
  on public.customer_group_member_grants for select
  to authenticated
  using (
    exists (
      select 1 from public.customer_group_members target
      join public.customer_groups cg on cg.id = target.customer_group_id
      join public.memberships caller on caller.tenant_id = cg.tenant_id
      where target.id = customer_group_member_id
        and lower(trim(caller.email)) = public.current_user_email()
        and caller.is_active = true
    ) or public.is_superadmin()
  );

create policy "cg_member_grants_write_admin"
  on public.customer_group_member_grants for all
  to authenticated
  using (
    exists (
      select 1 from public.customer_group_members target
      join public.customer_groups cg on cg.id = target.customer_group_id
      where target.id = customer_group_member_id
        and public.user_is_tenant_admin(cg.tenant_id)
    )
  )
  with check (
    exists (
      select 1 from public.customer_group_members target
      join public.customer_groups cg on cg.id = target.customer_group_id
      where target.id = customer_group_member_id
        and public.user_is_tenant_admin(cg.tenant_id)
    )
  );

commit;
