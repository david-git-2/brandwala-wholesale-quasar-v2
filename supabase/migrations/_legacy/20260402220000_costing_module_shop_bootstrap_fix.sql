-- =========================================================
-- Costing module bootstrap fix
-- Ensure shop navigation and guards can see the customer-side
-- costing key when costing is enabled for the tenant.
-- =========================================================

create or replace function public.get_active_module_keys_for_tenant(
  p_tenant_id bigint
)
returns text[]
language sql
security definer
set search_path = public
stable
as $$
  with active_keys as (
    select distinct tm.module_key
    from public.tenant_modules tm
    inner join public.modules mo
      on mo.key = tm.module_key
    inner join public.tenants t
      on t.id = tm.tenant_id
    where p_tenant_id is not null
      and tm.tenant_id = p_tenant_id
      and t.is_active = true
      and tm.is_active = true
      and mo.is_active = true
  ),
  expanded_keys as (
    select module_key
    from active_keys

    union

    select 'shop_costing_file'
    where exists (
      select 1
      from active_keys
      where module_key in ('costing_file', 'shop_costing_file')
    )
  )
  select
    coalesce(
      array_agg(module_key order by module_key),
      '{}'::text[]
    )
  from expanded_keys;
$$;

grant execute on function public.get_active_module_keys_for_tenant(bigint)
to authenticated;
