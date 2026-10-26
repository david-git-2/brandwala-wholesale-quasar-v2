begin;

-- =========================================================
-- 1. Insert/Update Modules Catalog
-- =========================================================

-- Insert parent module
insert into public.modules (key, name, description, is_active, parent_module_key)
values (
  'procurement_stock',
  'Procurement & Stock',
  'Parent module for inbound procurement, warehouse pools, and tenant stock allocations.',
  true,
  null
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active,
  parent_module_key = excluded.parent_module_key;

-- Insert/Update submodules with parent assignment
insert into public.modules (key, name, description, is_active, parent_module_key)
values
  (
    'global_shipment',
    'Global Shipment',
    'Parent-coordinated dispatch, logistics, and delivery across sister concerns.',
    true,
    'procurement_stock'
  ),
  (
    'global_stock',
    'Global Stock',
    'Parent-owned stock with child allocation bridge.',
    true,
    'procurement_stock'
  ),
  (
    'inventory',
    'Tenant Stock',
    'Tenant allocated stock view and parent allocation manager.',
    true,
    'procurement_stock'
  ),
  (
    'global_stock_type',
    'Stock Types',
    'Stock classification types config (e.g. Standard Sellable, Box Damage).',
    true,
    'procurement_stock'
  )
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active,
  parent_module_key = excluded.parent_module_key;

-- =========================================================
-- 2. Migrate Tenant Assignments
-- =========================================================

-- Assign procurement_stock parent to any tenant that had global_shipment, global_stock, or inventory enabled
insert into public.tenant_modules (tenant_id, module_key, is_active)
select distinct tm.tenant_id, 'procurement_stock', true
from public.tenant_modules tm
where tm.module_key in ('global_shipment', 'global_stock', 'inventory')
  and tm.is_active = true
  and not exists (
    select 1
    from public.tenant_modules existing
    where existing.tenant_id = tm.tenant_id
      and existing.module_key = 'procurement_stock'
  );

-- Delete direct submodule tenant assignments since they are now resolved via the parent expansion
delete from public.tenant_modules
where module_key in ('global_shipment', 'global_stock', 'inventory');

commit;
