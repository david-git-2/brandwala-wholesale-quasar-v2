-- Parent companies do not own storefronts (SHOP_ORDER D-SH9).
-- Strip shop_order from active keys when the tenant has children, and block assigning it.

begin;

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
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text := lower(trim(p_module_key));
  v_parent text;
begin
  if not public.is_superadmin() then
    return;
  end if;

  select mo.parent_module_key into v_parent
  from public.modules mo
  where mo.key = v_key;

  if v_parent is not null then
    raise exception 'Child submodules cannot be enabled independently. Please assign the main parent feature "%" instead.', v_parent;
  end if;

  if v_key = 'shop_order' and exists (
    select 1 from public.tenants child where child.parent_id = p_tenant_id
  ) then
    raise exception 'Shop & Order cannot be assigned to a parent company. Assign it on a sister concern or a standalone tenant.';
  end if;

  return query
  insert into public.tenant_modules as tm (tenant_id, module_key, is_active)
  values (p_tenant_id, v_key, coalesce(p_is_active, true))
  returning
    tm.id,
    tm.tenant_id,
    tm.module_key,
    tm.is_active,
    tm.created_at,
    tm.updated_at;
end;
$$;

create or replace function public.get_active_module_keys_for_tenant(
  p_tenant_id bigint
)
returns text[]
language sql
stable
security definer
set search_path = public
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
  ),
  tenant_kind as (
    select exists (
      select 1
      from public.tenants child
      where child.parent_id = p_tenant_id
    ) as is_parent_company
  ),
  visible as (
    select c.module_key
    from combined c
    cross join tenant_kind k
    where c.module_key is not null
      and not (
        k.is_parent_company
        and (
          c.module_key = 'shop_order'
          or exists (
            select 1
            from public.modules mo
            where mo.key = c.module_key
              and mo.parent_module_key = 'shop_order'
          )
        )
      )
  )
  select coalesce(
    array_agg(v.module_key order by v.module_key)
      filter (where v.module_key is not null),
    '{}'::text[]
  )
  from visible v;
$$;

commit;
