-- =========================================================
-- Rename seeded customer costing key:
-- shop_costing_file -> product_based_costing
-- =========================================================

insert into public.modules (
  key,
  name,
  description,
  is_active
)
values (
  'product_based_costing',
  'Product Based Costing',
  'Support customer-side costing visibility and pricing context.',
  true
)
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

-- If both keys exist for the same tenant, keep product_based_costing and drop duplicate old rows.
delete from public.tenant_modules old_tm
using public.tenant_modules new_tm
where old_tm.tenant_id = new_tm.tenant_id
  and old_tm.module_key = 'shop_costing_file'
  and new_tm.module_key = 'product_based_costing';

-- Move remaining old key assignments to new key.
update public.tenant_modules
set module_key = 'product_based_costing'
where module_key = 'shop_costing_file';

-- Remove old seeded module key after references are migrated.
delete from public.modules
where key = 'shop_costing_file';

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

    select 'product_based_costing'
    where exists (
      select 1
      from active_keys
      where module_key in ('costing_file', 'product_based_costing', 'shop_costing_file')
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
