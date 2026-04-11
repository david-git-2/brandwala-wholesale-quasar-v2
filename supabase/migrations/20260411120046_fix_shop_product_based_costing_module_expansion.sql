-- =========================================================
-- Shop module visibility fix
-- Do not expose customer-facing product_based_costing unless
-- that specific module is enabled for the tenant.
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
  )
  select
    coalesce(
      array_agg(module_key order by module_key),
      '{}'::text[]
    )
  from active_keys;
$$;

grant execute on function public.get_active_module_keys_for_tenant(bigint)
to authenticated;
