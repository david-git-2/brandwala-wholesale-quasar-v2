-- =========================================================
-- Step 4: Tenant module management RPCs
-- Make tenant_modules the backend source of tenant feature enablement
-- =========================================================

create or replace function public.can_view_tenant_modules(
  p_tenant_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
    or exists (
      select 1
      from public.customer_group_members cgm
      inner join public.customer_groups cg
        on cg.id = cgm.customer_group_id
      where cg.tenant_id = p_tenant_id
        and lower(trim(cgm.email)) = public.current_user_email()
        and cg.is_active = true
        and cgm.is_active = true
    )
$$;

grant execute on function public.can_view_tenant_modules(bigint)
to authenticated;

create or replace function public.list_tenant_modules_by_tenant(
  p_tenant_id bigint default null
)
returns table(
  id bigint,
  tenant_id bigint,
  module_key text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    tm.id,
    tm.tenant_id,
    tm.module_key,
    tm.is_active,
    tm.created_at,
    tm.updated_at
  from public.tenant_modules tm
  where p_tenant_id is not null
    and tm.tenant_id = p_tenant_id
    and public.can_view_tenant_modules(tm.tenant_id)
  order by tm.id asc;
$$;

grant execute on function public.list_tenant_modules_by_tenant(bigint)
to authenticated;

create or replace function public.get_tenant_module_by_id(
  p_id bigint
)
returns table(
  id bigint,
  tenant_id bigint,
  module_key text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    tm.id,
    tm.tenant_id,
    tm.module_key,
    tm.is_active,
    tm.created_at,
    tm.updated_at
  from public.tenant_modules tm
  where tm.id = p_id
    and public.can_view_tenant_modules(tm.tenant_id)
  limit 1;
$$;

grant execute on function public.get_tenant_module_by_id(bigint)
to authenticated;

create or replace function public.create_tenant_module_for_superadmin(
  p_tenant_id bigint,
  p_module_key text,
  p_is_active boolean default true
)
returns table(
  id bigint,
  tenant_id bigint,
  module_key text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with permission as (
    select public.is_superadmin() as allowed
  ),
  inserted as (
    insert into public.tenant_modules (
      tenant_id,
      module_key,
      is_active
    )
    select
      p_tenant_id,
      lower(trim(p_module_key)),
      coalesce(p_is_active, true)
    from permission
    where allowed
    returning
      id,
      tenant_id,
      module_key,
      is_active,
      created_at,
      updated_at
  )
  select
    id,
    tenant_id,
    module_key,
    is_active,
    created_at,
    updated_at
  from inserted;
$$;

grant execute on function public.create_tenant_module_for_superadmin(bigint, text, boolean)
to authenticated;

create or replace function public.update_tenant_module_for_superadmin(
  p_id bigint,
  p_tenant_id bigint default null,
  p_module_key text default null,
  p_is_active boolean default null
)
returns table(
  id bigint,
  tenant_id bigint,
  module_key text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with permission as (
    select public.is_superadmin() as allowed
  ),
  updated as (
    update public.tenant_modules tm
    set
      tenant_id = coalesce(p_tenant_id, tm.tenant_id),
      module_key = coalesce(lower(trim(p_module_key)), tm.module_key),
      is_active = coalesce(p_is_active, tm.is_active)
    from permission
    where allowed
      and tm.id = p_id
    returning
      tm.id,
      tm.tenant_id,
      tm.module_key,
      tm.is_active,
      tm.created_at,
      tm.updated_at
  )
  select
    id,
    tenant_id,
    module_key,
    is_active,
    created_at,
    updated_at
  from updated;
$$;

grant execute on function public.update_tenant_module_for_superadmin(bigint, bigint, text, boolean)
to authenticated;

create or replace function public.delete_tenant_module_for_superadmin(
  p_id bigint
)
returns table(
  id bigint,
  tenant_id bigint,
  module_key text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with permission as (
    select public.is_superadmin() as allowed
  ),
  deleted as (
    delete from public.tenant_modules tm
    using permission
    where allowed
      and tm.id = p_id
    returning
      tm.id,
      tm.tenant_id,
      tm.module_key,
      tm.is_active,
      tm.created_at,
      tm.updated_at
  )
  select
    id,
    tenant_id,
    module_key,
    is_active,
    created_at,
    updated_at
  from deleted;
$$;

grant execute on function public.delete_tenant_module_for_superadmin(bigint)
to authenticated;
