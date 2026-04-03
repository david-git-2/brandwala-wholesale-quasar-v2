-- =========================================================
-- Step 3: Seed the master module catalog
-- Idempotent seed for the MVP module set from MASTER_PLAN.md
-- =========================================================

insert into public.modules (
  key,
  name,
  description,
  is_active
)
values
  (
    'order_management',
    'Order Management',
    'Create, review, approve, and track order flow.',
    true
  ),
  (
    'shipment',
    'Shipment',
    'Coordinate dispatch, logistics, and delivery status.',
    true
  ),
  (
    'inventory',
    'Inventory',
    'Monitor stock, availability, and inventory movement.',
    true
  ),
  (
    'shop_costing_file',
    'Shop Costing File',
    'Support customer-side costing visibility and pricing context.',
    true
  ),
  (
    'costing_file',
    'Costing File',
    'Manage internal costing references and pricing preparation.',
    true
  ),
  (
    'accounting',
    'Accounting',
    'Handle accounting workflows tied to tenant operations.',
    true
  ),
  (
    'invoice',
    'Invoice',
    'Manage invoice creation, status, and reconciliation flow.',
    true
  )
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;
