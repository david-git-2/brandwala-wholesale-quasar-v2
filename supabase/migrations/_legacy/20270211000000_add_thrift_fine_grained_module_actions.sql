-- =========================================================
-- Migration: Add fine-grained module actions for Thrift vertical
-- Additions: edit_quantity, edit_price, view_cost, apply_discount
-- =========================================================

begin;

-- 1. Insert new fine-grained module actions for thrift_stock & thrift_shipment
insert into public.module_actions (module_key, action, scope, tenant_configurable, is_active)
values
  -- thrift_stock fine-grained actions
  ('thrift_stock', 'edit_quantity', 'app', true, true),
  ('thrift_stock', 'edit_price', 'app', true, true),
  ('thrift_stock', 'view_cost', 'app', true, true),
  ('thrift_stock', 'apply_discount', 'app', true, true),

  -- thrift_shipment fine-grained actions
  ('thrift_shipment', 'edit_quantity', 'app', true, true),
  ('thrift_shipment', 'edit_price', 'app', true, true),
  ('thrift_shipment', 'view_cost', 'app', true, true),
  ('thrift_shipment', 'apply_discount', 'app', true, true)
on conflict (module_key, action, scope) do update set
  is_active = true,
  tenant_configurable = true;

-- 2. Seed default system_role_templates for staff role (granted edit_quantity by default)
insert into public.system_role_templates (scope, role_slug, module_key, action, allowed)
values
  ('app', 'staff', 'thrift_stock', 'edit_quantity', true),
  ('app', 'staff', 'thrift_shipment', 'edit_quantity', true)
on conflict (scope, role_slug, module_key, action) do update set
  allowed = excluded.allowed;

commit;
