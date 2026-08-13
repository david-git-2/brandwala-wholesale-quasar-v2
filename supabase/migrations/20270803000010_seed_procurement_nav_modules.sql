-- Seed procurement nav submodules: movements, locations; refresh inventory as child Stock

begin;

update public.modules
set
  name = 'Procurement & Stock',
  description = 'Inbound shipments, warehouse stock, movements, locations, and child stock view.',
  is_active = true,
  parent_module_key = null
where key = 'procurement_stock';

insert into public.modules (key, name, description, is_active, parent_module_key)
values
  (
    'global_stock_movement',
    'Movements',
    'Warehouse movement documents: location and availability transfers.',
    true,
    'procurement_stock'
  ),
  (
    'global_stock_location',
    'Locations',
    'Bin and zone catalog for the parent warehouse.',
    true,
    'procurement_stock'
  ),
  (
    'inventory',
    'Stock',
    'Child tenant view of assigned / sellable stock.',
    true,
    'procurement_stock'
  )
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active,
  parent_module_key = excluded.parent_module_key;

update public.modules
set
  name = 'Shipment',
  description = 'Inbound batches: draft, cost entries, finalize, and Ready Stock.'
where key = 'global_shipment';

update public.modules
set
  name = 'Warehouse',
  description = 'Parent warehouse on-hand by availability and location.'
where key = 'global_stock';

insert into public.module_actions (module_key, action, scope, tenant_configurable, is_active)
values
  ('global_stock_movement', 'view', 'app', true, true),
  ('global_stock_location', 'view', 'app', true, true),
  ('inventory', 'view', 'app', true, true)
on conflict (module_key, action, scope) do update set
  is_active = true,
  tenant_configurable = true;

-- Parent expansion already covers submodules when procurement_stock is assigned.
-- Ensure no stale direct tenant_modules rows for new submodule keys.
delete from public.tenant_modules
where module_key in ('global_stock_movement', 'global_stock_location');

commit;
