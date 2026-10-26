-- Migration: 20261130000019_fix_customer_admin_shop_effective_grants.sql
-- Fix:
-- 1. get_active_module_keys_for_tenant parent-to-submodule expansion (e.g. shop_order -> shop_storefront, shop_cart, shop_order_mgmt, shop_dropship, ...)
-- 2. Customer Group Member Admin Role not granting shop effective grants / bootstrap is_admin.
-- 3. Auto-assign and sync tenant_role_id for customer_group_members.

-- 1. Fix get_active_module_keys_for_tenant to expand parent modules to their child submodules
create or replace function public.get_active_module_keys_for_tenant(
  p_tenant_id bigint
)
returns text[]
language sql
security definer
set search_path = public
stable
as $$
  with active_assignments as (
    select tm.module_key
    from public.tenant_modules tm
    inner join public.modules mo on mo.key = tm.module_key
    inner join public.tenants t on t.id = tm.tenant_id
    where p_tenant_id is not null
      and tm.tenant_id = p_tenant_id
      and t.is_active = true
      and tm.is_active = true
      and mo.is_active = true
  ),
  expanded_child_keys as (
    select child.key as module_key
    from active_assignments a
    inner join public.modules child
      on child.parent_module_key = a.module_key
    where child.is_active = true
      and not exists (
        select 1
        from public.tenant_module_submodules tms
        where tms.tenant_id = p_tenant_id
          and tms.submodule_key = child.key
          and tms.is_enabled = false
      )
  ),
  combined as (
    select module_key from active_assignments
    union
    select module_key from expanded_child_keys
  )
  select coalesce(
    array_agg(c.module_key order by c.module_key)
      filter (where c.module_key is not null),
    '{}'::text[]
  )
  from combined c;
$$;

grant execute on function public.get_active_module_keys_for_tenant(bigint) to authenticated;

-- 2. Auto-assign and sync tenant_role_id for customer_group_members if missing or on role update
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
        when 'negotiator' then 'negotiator'
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

drop trigger if exists trg_cgm_sync_tenant_role on public.customer_group_members;
create trigger trg_cgm_sync_tenant_role
  before insert or update on public.customer_group_members
  for each row execute function public.trg_fn_sync_cgm_tenant_role();

-- 3. Backfill existing customer_group_members tenant_role_id
update public.customer_group_members cgm
set tenant_role_id = tr.id
from public.customer_groups cg
join public.tenant_roles tr on tr.tenant_id = cg.tenant_id and tr.scope = 'shop'
where cgm.tenant_role_id is null
  and cgm.customer_group_id = cg.id
  and (
    (cgm.role = 'admin' and (tr.slug = 'customer-admin' or tr.is_admin = true)) or
    (cgm.role = 'negotiator' and tr.slug = 'negotiator') or
    (cgm.role = 'staff' and tr.slug = 'customer-staff')
  );

-- 4. Redefine get_shop_effective_grants to fallback to cgm.role = 'admin'
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
  v_cgm_role public.customer_group_role;
begin
  select cgm.tenant_role_id, tr.is_admin, cgm.role
  into v_tenant_role_id, v_role_is_admin, v_cgm_role
  from public.customer_group_members cgm
  left join public.tenant_roles tr on tr.id = cgm.tenant_role_id
  where cgm.id = p_customer_group_member_id
    and cgm.is_active = true;

  if coalesce(v_role_is_admin, v_cgm_role = 'admin', false) = true then
    return query
    select ma.module_key, ma.action
    from public.module_actions ma
    join public.tenant_modules tm on tm.module_key = ma.module_key or tm.module_key = (
      select mo.parent_module_key from public.modules mo where mo.key = ma.module_key limit 1
    )
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
  join public.tenant_modules tm on tm.module_key = e.module_key or tm.module_key = (
    select mo.parent_module_key from public.modules mo where mo.key = e.module_key limit 1
  )
  where tm.tenant_id = p_tenant_id
    and tm.is_active = true
    and ma.is_active = true
    and ma.scope = 'shop';
end;
$$;

-- 5. Redefine get_shop_bootstrap_context to fallback to cgm.role = 'admin' for is_admin flag
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
