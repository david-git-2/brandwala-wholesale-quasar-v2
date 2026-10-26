begin;

-- =========================================================
-- 1. Refactor Unique Constraint on module_actions
-- =========================================================
alter table public.module_actions
  drop constraint if exists module_actions_module_key_action_unique;

alter table public.module_actions
  add constraint module_actions_module_key_action_scope_unique
  unique (module_key, action, scope);

-- =========================================================
-- 1b. Seed platform module catalog rows (FK prerequisite)
-- =========================================================
insert into public.modules (key, name, description, is_active)
values
  (
    'platform_tenants',
    'Platform Tenants',
    'Superadmin tenant CRUD — not assignable via tenant_modules.',
    true
  ),
  (
    'platform_memberships',
    'Platform Memberships',
    'Superadmin membership management — not tenant-assignable.',
    true
  ),
  (
    'platform_modules',
    'Platform Modules',
    'Cross-tenant module assignment — superadmin only.',
    true
  ),
  (
    'platform_markets',
    'Platform Markets',
    'Global market catalog CRUD — superadmin only.',
    true
  )
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

-- =========================================================
-- 2. Seed module_actions catalog
-- =========================================================
insert into public.module_actions (module_key, action, scope, tenant_configurable, is_active)
values
  -- Procurement inputs
  ('order_management', 'view', 'app', true, true),
  ('order_management', 'create', 'app', true, true),
  ('order_management', 'edit', 'app', true, true),
  ('order_management', 'delete', 'app', true, true),
  ('order_management', 'submit', 'app', true, true),
  ('order_management', 'cancel', 'app', true, true),
  ('order_management', 'view', 'shop', true, true),
  ('order_management', 'create', 'shop', true, true),
  ('order_management', 'edit', 'shop', true, true),
  ('order_management', 'delete', 'shop', true, true),
  ('order_management', 'submit', 'shop', true, true),
  ('order_management', 'cancel', 'shop', true, true),

  ('costing_file', 'view', 'app', true, true),
  ('costing_file', 'create', 'app', true, true),
  ('costing_file', 'edit', 'app', true, true),
  ('costing_file', 'delete', 'app', true, true),
  ('costing_file', 'offer', 'app', true, true),
  ('costing_file', 'share', 'app', true, true),
  ('costing_file', 'view', 'shop', true, true),
  ('costing_file', 'create', 'shop', true, true),
  ('costing_file', 'edit', 'shop', true, true),
  ('costing_file', 'delete', 'shop', true, true),
  ('costing_file', 'offer', 'shop', true, true),
  ('costing_file', 'share', 'shop', true, true),

  ('product_based_costing', 'view', 'app', true, true),
  ('product_based_costing', 'create', 'app', true, true),
  ('product_based_costing', 'edit', 'app', true, true),
  ('product_based_costing', 'delete', 'app', true, true),
  ('product_based_costing', 'submit', 'app', true, true),

  -- Procurement and stock
  ('global_shipment', 'view', 'app', true, true),
  ('global_shipment', 'create', 'app', true, true),
  ('global_shipment', 'edit', 'app', true, true),
  ('global_shipment', 'receive', 'app', true, true),
  ('global_shipment', 'close', 'app', true, true),

  ('global_stock', 'view', 'app', true, true),
  ('global_stock', 'create', 'app', true, true),
  ('global_stock', 'adjust', 'app', true, true),
  ('global_stock', 'allocate', 'app', true, true),

  ('global_stock_type', 'view', 'app', true, true),
  ('global_stock_type', 'configure', 'app', true, true),

  ('procurement_stock', 'view', 'app', true, true),
  ('procurement_stock', 'manage', 'app', true, true),

  ('inventory', 'view', 'app', true, true),
  ('inventory', 'allocate', 'app', true, true),

  -- Profiles and CRM
  ('billing_profile', 'view', 'app', true, true),
  ('billing_profile', 'create', 'app', true, true),
  ('billing_profile', 'edit', 'app', true, true),
  ('billing_profile', 'delete', 'app', true, true),

  ('recipient_profile', 'view', 'app', true, true),
  ('recipient_profile', 'create', 'app', true, true),
  ('recipient_profile', 'edit', 'app', true, true),
  ('recipient_profile', 'delete', 'app', true, true),

  ('invoice_brand', 'view', 'app', true, true),
  ('invoice_brand', 'create', 'app', true, true),
  ('invoice_brand', 'edit', 'app', true, true),
  ('invoice_brand', 'configure', 'app', true, true),

  -- Sales and invoice
  ('global_invoice', 'view', 'app', true, true),
  ('global_invoice', 'create', 'app', true, true),
  ('global_invoice', 'edit', 'app', true, true),
  ('global_invoice', 'delete', 'app', true, true),
  ('global_invoice', 'post', 'app', true, true),
  ('global_invoice', 'void', 'app', true, true),
  ('global_invoice', 'return', 'app', true, true),

  ('sales_invoice', 'view', 'app', true, true),
  ('sales_invoice', 'create', 'app', true, true),
  ('sales_invoice', 'edit', 'app', true, true),
  ('sales_invoice', 'delete', 'app', true, true),
  ('sales_invoice', 'post', 'app', true, true),
  ('sales_invoice', 'void', 'app', true, true),
  ('sales_invoice', 'return', 'app', true, true),

  -- Treasury and reporting
  ('payments', 'view', 'app', true, true),
  ('payments', 'collect_payment', 'app', true, true),
  ('payments', 'allocate_payment', 'app', true, true),
  ('payments', 'void', 'app', true, true),

  ('invoice_reports', 'view', 'app', true, true),
  ('invoice_reports', 'export', 'app', true, true),

  ('shipment_reports', 'view', 'app', true, true),
  ('shipment_reports', 'export', 'app', true, true),

  ('billing_balances', 'view', 'app', true, true),
  ('billing_balances', 'export', 'app', true, true),

  ('parent_dashboard', 'view', 'app', true, true),

  ('investor_reports', 'view', 'app', true, true),
  ('investor_reports', 'export', 'app', true, true),

  ('reporting_treasury', 'view', 'app', true, true),

  -- Investor capital
  ('investor_profiles', 'view', 'app', true, true),
  ('investor_profiles', 'create', 'app', true, true),
  ('investor_profiles', 'edit', 'app', true, true),
  ('investor_profiles', 'configure', 'app', true, true),

  ('investor_capital_ledger', 'view', 'app', true, true),
  ('investor_capital_ledger', 'create', 'app', true, true),
  ('investor_capital_ledger', 'edit', 'app', true, true),
  ('investor_capital_ledger', 'void', 'app', true, true),

  ('investor_shipment_share', 'view', 'app', true, true),
  ('investor_shipment_share', 'create', 'app', true, true),
  ('investor_shipment_share', 'edit', 'app', true, true),

  ('investor_portal', 'view', 'investor', true, true),

  -- Shop - admin (App scope)
  ('shop_order', 'view', 'app', true, true),

  ('shop_config', 'view', 'app', true, true),
  ('shop_config', 'create', 'app', true, true),
  ('shop_config', 'edit', 'app', true, true),
  ('shop_config', 'configure', 'app', true, true),

  ('shop_permissions', 'view', 'app', true, true),
  ('shop_permissions', 'configure', 'app', true, true),

  ('shop_pricing', 'view', 'app', true, true),
  ('shop_pricing', 'create', 'app', true, true),
  ('shop_pricing', 'edit', 'app', true, true),
  ('shop_pricing', 'delete', 'app', true, true),

  ('shop_order_mgmt', 'view', 'app', true, true),
  ('shop_order_mgmt', 'edit', 'app', true, true),
  ('shop_order_mgmt', 'cancel', 'app', true, true),
  ('shop_order_mgmt', 'fulfill', 'app', true, true),

  ('shop_fulfillment', 'view', 'app', true, true),
  ('shop_fulfillment', 'fulfill', 'app', true, true),

  -- Shop - customer (Shop scope)
  ('shop_storefront', 'view', 'shop', true, true),
  ('shop_storefront', 'see_price', 'shop', true, true),
  ('shop_storefront', 'view_quantity', 'shop', true, true),
  ('shop_storefront', 'set_dropship_price', 'shop', true, true),

  ('shop_cart', 'view', 'shop', true, true),
  ('shop_cart', 'add_to_cart', 'shop', true, true),
  ('shop_cart', 'edit_line', 'shop', true, true),
  ('shop_cart', 'remove_line', 'shop', true, true),

  ('shop_order_mgmt', 'view', 'shop', true, true),
  ('shop_order_mgmt', 'place_order', 'shop', true, true),
  ('shop_order_mgmt', 'negotiate', 'shop', true, true),
  ('shop_order_mgmt', 'cancel', 'shop', true, true),

  -- Catalog and reference
  ('products', 'view', 'app', true, true),
  ('products', 'create', 'app', true, true),
  ('products', 'edit', 'app', true, true),
  ('products', 'delete', 'app', true, true),

  ('vendor', 'view', 'app', true, true),
  ('vendor', 'create', 'app', true, true),
  ('vendor', 'edit', 'app', true, true),
  ('vendor', 'delete', 'app', true, true),

  ('global_reference', 'view', 'app', true, true),

  ('global_reference_currency', 'view', 'app', true, true),
  ('global_reference_currency', 'configure', 'app', true, true),

  ('global_reference_market', 'view', 'app', true, true),
  ('global_reference_payment_method', 'view', 'app', true, true),
  ('global_reference_unit_of_measure', 'view', 'app', true, true),

  -- Verticals
  ('tasks', 'view', 'app', true, true),
  ('tasks', 'create', 'app', true, true),
  ('tasks', 'edit', 'app', true, true),
  ('tasks', 'delete', 'app', true, true),
  ('tasks', 'assign', 'app', true, true),

  ('thrift_stock', 'view', 'app', true, true),
  ('thrift_stock', 'create', 'app', true, true),
  ('thrift_stock', 'edit', 'app', true, true),
  ('thrift_stock', 'delete', 'app', true, true),
  ('thrift_stock', 'receive', 'app', true, true),

  ('thrift_shipment', 'view', 'app', true, true),
  ('thrift_shipment', 'create', 'app', true, true),
  ('thrift_shipment', 'edit', 'app', true, true),
  ('thrift_shipment', 'delete', 'app', true, true),
  ('thrift_shipment', 'receive', 'app', true, true),

  ('thrift_box', 'view', 'app', true, true),
  ('thrift_box', 'create', 'app', true, true),
  ('thrift_box', 'edit', 'app', true, true),
  ('thrift_box', 'delete', 'app', true, true),
  ('thrift_box', 'receive', 'app', true, true),

  ('thrift_shelf', 'view', 'app', true, true),
  ('thrift_shelf', 'create', 'app', true, true),
  ('thrift_shelf', 'edit', 'app', true, true),
  ('thrift_shelf', 'delete', 'app', true, true),
  ('thrift_shelf', 'receive', 'app', true, true),

  ('thrift_barcode', 'view', 'app', true, true),
  ('thrift_barcode', 'create', 'app', true, true),
  ('thrift_barcode', 'edit', 'app', true, true),
  ('thrift_barcode', 'delete', 'app', true, true),
  ('thrift_barcode', 'receive', 'app', true, true),

  ('thrift_category', 'view', 'app', true, true),
  ('thrift_category', 'create', 'app', true, true),
  ('thrift_category', 'edit', 'app', true, true),
  ('thrift_category', 'delete', 'app', true, true),
  ('thrift_category', 'receive', 'app', true, true),

  ('thrift_type', 'view', 'app', true, true),
  ('thrift_type', 'create', 'app', true, true),
  ('thrift_type', 'edit', 'app', true, true),
  ('thrift_type', 'delete', 'app', true, true),
  ('thrift_type', 'receive', 'app', true, true),

  ('thrift_settings', 'view', 'app', true, true),
  ('thrift_settings', 'create', 'app', true, true),
  ('thrift_settings', 'edit', 'app', true, true),
  ('thrift_settings', 'delete', 'app', true, true),
  ('thrift_settings', 'receive', 'app', true, true),

  ('koba_retail', 'view', 'app', true, true),
  ('koba_retail', 'order', 'app', true, true),
  ('koba_retail', 'view', 'shop', true, true),
  ('koba_retail', 'order', 'shop', true, true),

  ('koba_wholesale', 'view', 'app', true, true),
  ('koba_wholesale', 'create', 'app', true, true),
  ('koba_wholesale', 'edit', 'app', true, true),

  -- Platform Only (not tenant configurable)
  ('platform_tenants', 'view', 'platform', false, true),
  ('platform_tenants', 'create', 'platform', false, true),
  ('platform_tenants', 'edit', 'platform', false, true),
  ('platform_tenants', 'delete', 'platform', false, true),

  ('platform_memberships', 'view', 'platform', false, true),
  ('platform_memberships', 'create', 'platform', false, true),
  ('platform_memberships', 'edit', 'platform', false, true),

  ('platform_modules', 'view', 'platform', false, true),
  ('platform_modules', 'assign', 'platform', false, true),

  ('platform_markets', 'view', 'platform', false, true),
  ('platform_markets', 'create', 'platform', false, true),
  ('platform_markets', 'edit', 'platform', false, true)
on conflict (module_key, action, scope) do update set
  tenant_configurable = excluded.tenant_configurable,
  is_active = excluded.is_active;

-- =========================================================
-- 3. Seed system_role_templates
-- =========================================================
insert into public.system_role_templates (scope, role_slug, module_key, action, allowed)
values
  -- app staff role templates
  ('app', 'staff', 'order_management', 'view', true),
  ('app', 'staff', 'order_management', 'create', true),
  ('app', 'staff', 'order_management', 'edit', true),
  ('app', 'staff', 'order_management', 'delete', true),
  ('app', 'staff', 'order_management', 'submit', true),
  ('app', 'staff', 'order_management', 'cancel', true),
  ('app', 'staff', 'vendor', 'view', true),
  ('app', 'staff', 'vendor', 'create', true),
  ('app', 'staff', 'vendor', 'edit', true),
  ('app', 'staff', 'vendor', 'delete', true),
  ('app', 'staff', 'products', 'view', true),
  ('app', 'staff', 'products', 'create', true),
  ('app', 'staff', 'products', 'edit', true),
  ('app', 'staff', 'products', 'delete', true),
  ('app', 'staff', 'product_based_costing', 'view', true),
  ('app', 'staff', 'product_based_costing', 'create', true),
  ('app', 'staff', 'product_based_costing', 'edit', true),
  ('app', 'staff', 'product_based_costing', 'delete', true),
  ('app', 'staff', 'product_based_costing', 'submit', true),
  ('app', 'staff', 'costing_file', 'view', true),
  ('app', 'staff', 'costing_file', 'create', true),
  ('app', 'staff', 'costing_file', 'edit', true),
  ('app', 'staff', 'costing_file', 'delete', true),
  ('app', 'staff', 'costing_file', 'offer', true),
  ('app', 'staff', 'costing_file', 'share', true),
  ('app', 'staff', 'koba_retail', 'view', true),
  ('app', 'staff', 'koba_retail', 'order', true),
  ('app', 'staff', 'koba_wholesale', 'view', true),
  ('app', 'staff', 'koba_wholesale', 'create', true),
  ('app', 'staff', 'koba_wholesale', 'edit', true),
  ('app', 'staff', 'tasks', 'view', true),
  ('app', 'staff', 'tasks', 'create', true),
  ('app', 'staff', 'tasks', 'edit', true),
  ('app', 'staff', 'tasks', 'delete', true),
  ('app', 'staff', 'tasks', 'assign', true),
  ('app', 'staff', 'thrift_stock', 'view', true),
  ('app', 'staff', 'thrift_stock', 'create', true),
  ('app', 'staff', 'thrift_stock', 'edit', true),
  ('app', 'staff', 'thrift_stock', 'delete', true),
  ('app', 'staff', 'thrift_stock', 'receive', true),
  ('app', 'staff', 'thrift_shipment', 'view', true),
  ('app', 'staff', 'thrift_shipment', 'create', true),
  ('app', 'staff', 'thrift_shipment', 'edit', true),
  ('app', 'staff', 'thrift_shipment', 'delete', true),
  ('app', 'staff', 'thrift_shipment', 'receive', true),
  ('app', 'staff', 'thrift_box', 'view', true),
  ('app', 'staff', 'thrift_box', 'create', true),
  ('app', 'staff', 'thrift_box', 'edit', true),
  ('app', 'staff', 'thrift_box', 'delete', true),
  ('app', 'staff', 'thrift_box', 'receive', true),
  ('app', 'staff', 'thrift_shelf', 'view', true),
  ('app', 'staff', 'thrift_shelf', 'create', true),
  ('app', 'staff', 'thrift_shelf', 'edit', true),
  ('app', 'staff', 'thrift_shelf', 'delete', true),
  ('app', 'staff', 'thrift_shelf', 'receive', true),
  ('app', 'staff', 'thrift_barcode', 'view', true),
  ('app', 'staff', 'thrift_barcode', 'create', true),
  ('app', 'staff', 'thrift_barcode', 'edit', true),
  ('app', 'staff', 'thrift_barcode', 'delete', true),
  ('app', 'staff', 'thrift_barcode', 'receive', true),
  ('app', 'staff', 'thrift_category', 'view', true),
  ('app', 'staff', 'thrift_category', 'create', true),
  ('app', 'staff', 'thrift_category', 'edit', true),
  ('app', 'staff', 'thrift_category', 'delete', true),
  ('app', 'staff', 'thrift_category', 'receive', true),
  ('app', 'staff', 'thrift_type', 'view', true),
  ('app', 'staff', 'thrift_type', 'create', true),
  ('app', 'staff', 'thrift_type', 'edit', true),
  ('app', 'staff', 'thrift_type', 'delete', true),
  ('app', 'staff', 'thrift_type', 'receive', true),
  ('app', 'staff', 'thrift_settings', 'view', true),
  ('app', 'staff', 'thrift_settings', 'create', true),
  ('app', 'staff', 'thrift_settings', 'edit', true),
  ('app', 'staff', 'thrift_settings', 'delete', true),
  ('app', 'staff', 'thrift_settings', 'receive', true),
  ('app', 'staff', 'global_reference_currency', 'view', true),
  ('app', 'staff', 'global_reference_currency', 'configure', true),
  ('app', 'staff', 'global_reference_market', 'view', true),
  ('app', 'staff', 'global_reference_payment_method', 'view', true),
  ('app', 'staff', 'global_reference_unit_of_measure', 'view', true),
  ('app', 'staff', 'global_invoice', 'view', true),
  ('app', 'staff', 'global_invoice', 'create', true),
  ('app', 'staff', 'global_invoice', 'edit', true),
  ('app', 'staff', 'global_invoice', 'delete', true),
  ('app', 'staff', 'global_invoice', 'post', true),
  ('app', 'staff', 'global_invoice', 'void', true),
  ('app', 'staff', 'global_invoice', 'return', true),
  ('app', 'staff', 'sales_invoice', 'view', true),
  ('app', 'staff', 'sales_invoice', 'create', true),
  ('app', 'staff', 'sales_invoice', 'edit', true),
  ('app', 'staff', 'sales_invoice', 'delete', true),
  ('app', 'staff', 'sales_invoice', 'post', true),
  ('app', 'staff', 'sales_invoice', 'void', true),
  ('app', 'staff', 'sales_invoice', 'return', true),
  ('app', 'staff', 'billing_profile', 'view', true),
  ('app', 'staff', 'billing_profile', 'create', true),
  ('app', 'staff', 'billing_profile', 'edit', true),
  ('app', 'staff', 'billing_profile', 'delete', true),
  ('app', 'staff', 'recipient_profile', 'view', true),
  ('app', 'staff', 'recipient_profile', 'create', true),
  ('app', 'staff', 'recipient_profile', 'edit', true),
  ('app', 'staff', 'recipient_profile', 'delete', true),
  ('app', 'staff', 'invoice_brand', 'view', true),
  ('app', 'staff', 'invoice_brand', 'create', true),
  ('app', 'staff', 'invoice_brand', 'edit', true),
  ('app', 'staff', 'invoice_brand', 'configure', true),
  ('app', 'staff', 'payments', 'view', true),
  ('app', 'staff', 'payments', 'collect_payment', true),
  ('app', 'staff', 'payments', 'allocate_payment', true),
  ('app', 'staff', 'payments', 'void', true),
  ('app', 'staff', 'invoice_reports', 'view', true),
  ('app', 'staff', 'invoice_reports', 'export', true),
  ('app', 'staff', 'billing_balances', 'view', true),
  ('app', 'staff', 'billing_balances', 'export', true),
  ('app', 'staff', 'investor_profiles', 'view', true),
  ('app', 'staff', 'investor_profiles', 'create', true),
  ('app', 'staff', 'investor_profiles', 'edit', true),
  ('app', 'staff', 'investor_profiles', 'configure', true),
  ('app', 'staff', 'investor_capital_ledger', 'view', true),
  ('app', 'staff', 'investor_capital_ledger', 'create', true),
  ('app', 'staff', 'investor_capital_ledger', 'edit', true),
  ('app', 'staff', 'investor_capital_ledger', 'void', true),
  ('app', 'staff', 'investor_shipment_share', 'view', true),
  ('app', 'staff', 'investor_shipment_share', 'create', true),
  ('app', 'staff', 'investor_shipment_share', 'edit', true),
  ('app', 'staff', 'shop_config', 'view', true),
  ('app', 'staff', 'shop_config', 'create', true),
  ('app', 'staff', 'shop_config', 'edit', true),
  ('app', 'staff', 'shop_config', 'configure', true),
  ('app', 'staff', 'shop_permissions', 'view', true),
  ('app', 'staff', 'shop_permissions', 'configure', true),
  ('app', 'staff', 'shop_pricing', 'view', true),
  ('app', 'staff', 'shop_pricing', 'create', true),
  ('app', 'staff', 'shop_pricing', 'edit', true),
  ('app', 'staff', 'shop_pricing', 'delete', true),
  ('app', 'staff', 'shop_order_mgmt', 'view', true),
  ('app', 'staff', 'shop_order_mgmt', 'edit', true),
  ('app', 'staff', 'shop_order_mgmt', 'cancel', true),
  ('app', 'staff', 'shop_order_mgmt', 'fulfill', true),
  ('app', 'staff', 'shop_fulfillment', 'view', true),
  ('app', 'staff', 'shop_fulfillment', 'fulfill', true),

  -- Seed write/manage actions for staff for procurement_stock pilot
  ('app', 'staff', 'global_shipment', 'view', true),
  ('app', 'staff', 'global_shipment', 'create', true),
  ('app', 'staff', 'global_shipment', 'edit', true),
  ('app', 'staff', 'global_shipment', 'receive', true),
  ('app', 'staff', 'global_shipment', 'close', true),
  ('app', 'staff', 'global_stock', 'view', true),
  ('app', 'staff', 'global_stock', 'create', true),
  ('app', 'staff', 'global_stock', 'adjust', true),
  ('app', 'staff', 'global_stock', 'allocate', true),
  ('app', 'staff', 'global_stock_type', 'view', true),
  ('app', 'staff', 'global_stock_type', 'configure', true),
  ('app', 'staff', 'procurement_stock', 'view', true),
  ('app', 'staff', 'procurement_stock', 'manage', true),

  -- app viewer role templates
  ('app', 'viewer', 'costing_file', 'view', true),
  ('app', 'viewer', 'tasks', 'view', true),

  -- shop customer-admin templates
  ('shop', 'customer-admin', 'order_management', 'view', true),
  ('shop', 'customer-admin', 'order_management', 'create', true),
  ('shop', 'customer-admin', 'order_management', 'edit', true),
  ('shop', 'customer-admin', 'order_management', 'delete', true),
  ('shop', 'customer-admin', 'order_management', 'submit', true),
  ('shop', 'customer-admin', 'order_management', 'cancel', true),
  ('shop', 'customer-admin', 'costing_file', 'view', true),
  ('shop', 'customer-admin', 'costing_file', 'create', true),
  ('shop', 'customer-admin', 'costing_file', 'edit', true),
  ('shop', 'customer-admin', 'costing_file', 'delete', true),
  ('shop', 'customer-admin', 'costing_file', 'offer', true),
  ('shop', 'customer-admin', 'costing_file', 'share', true),
  ('shop', 'customer-admin', 'koba_retail', 'view', true),
  ('shop', 'customer-admin', 'koba_retail', 'order', true),
  ('shop', 'customer-admin', 'shop_storefront', 'view', true),
  ('shop', 'customer-admin', 'shop_storefront', 'see_price', true),
  ('shop', 'customer-admin', 'shop_storefront', 'view_quantity', true),
  ('shop', 'customer-admin', 'shop_storefront', 'set_dropship_price', true),
  ('shop', 'customer-admin', 'shop_cart', 'view', true),
  ('shop', 'customer-admin', 'shop_cart', 'add_to_cart', true),
  ('shop', 'customer-admin', 'shop_cart', 'edit_line', true),
  ('shop', 'customer-admin', 'shop_cart', 'remove_line', true),
  ('shop', 'customer-admin', 'shop_order_mgmt', 'view', true),
  ('shop', 'customer-admin', 'shop_order_mgmt', 'place_order', true),
  ('shop', 'customer-admin', 'shop_order_mgmt', 'negotiate', true),
  ('shop', 'customer-admin', 'shop_order_mgmt', 'cancel', true),

  -- shop negotiator templates
  ('shop', 'negotiator', 'order_management', 'view', true),
  ('shop', 'negotiator', 'order_management', 'create', true),
  ('shop', 'negotiator', 'order_management', 'edit', true),
  ('shop', 'negotiator', 'order_management', 'delete', true),
  ('shop', 'negotiator', 'order_management', 'submit', true),
  ('shop', 'negotiator', 'order_management', 'cancel', true),
  ('shop', 'negotiator', 'costing_file', 'view', true),
  ('shop', 'negotiator', 'costing_file', 'create', true),
  ('shop', 'negotiator', 'costing_file', 'edit', true),
  ('shop', 'negotiator', 'costing_file', 'delete', true),
  ('shop', 'negotiator', 'costing_file', 'offer', true),
  ('shop', 'negotiator', 'costing_file', 'share', true),
  ('shop', 'negotiator', 'koba_retail', 'view', true),
  ('shop', 'negotiator', 'koba_retail', 'order', true),
  ('shop', 'negotiator', 'shop_storefront', 'view', true),
  ('shop', 'negotiator', 'shop_storefront', 'see_price', true),
  ('shop', 'negotiator', 'shop_storefront', 'view_quantity', true),
  ('shop', 'negotiator', 'shop_storefront', 'set_dropship_price', true),
  ('shop', 'negotiator', 'shop_cart', 'view', true),
  ('shop', 'negotiator', 'shop_cart', 'add_to_cart', true),
  ('shop', 'negotiator', 'shop_cart', 'edit_line', true),
  ('shop', 'negotiator', 'shop_cart', 'remove_line', true),
  ('shop', 'negotiator', 'shop_order_mgmt', 'view', true),
  ('shop', 'negotiator', 'shop_order_mgmt', 'place_order', true),
  ('shop', 'negotiator', 'shop_order_mgmt', 'negotiate', true),
  ('shop', 'negotiator', 'shop_order_mgmt', 'cancel', true),

  -- shop customer-staff templates
  ('shop', 'customer-staff', 'order_management', 'view', true),
  ('shop', 'customer-staff', 'costing_file', 'view', true),
  ('shop', 'customer-staff', 'koba_retail', 'view', true),
  ('shop', 'customer-staff', 'shop_storefront', 'view', true),
  ('shop', 'customer-staff', 'shop_cart', 'view', true),
  ('shop', 'customer-staff', 'shop_order_mgmt', 'view', true)
on conflict (scope, role_slug, module_key, action) do update set
  allowed = excluded.allowed;

-- =========================================================
-- 4. Redefine has_module_action to Support Multi-Scope Resolution
-- =========================================================
create or replace function public.has_module_action(
  p_tenant_id bigint,
  p_module_key text,
  p_action text
)
returns boolean
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_has_app_action boolean;
  v_has_shop_action boolean;
  v_member_id bigint;
  v_tenant_role_id bigint;
  v_role_is_admin boolean;
  v_override_effect text;
  v_role_allowed boolean;
  v_shop_allowed boolean;
begin
  -- Superadmin bypass
  if public.is_superadmin() then
    return true;
  end if;

  -- 1. Check module status for the tenant
  if not exists (
    select 1
    from public.tenant_modules
    where tenant_id = p_tenant_id
      and module_key = p_module_key
      and is_active = true
  ) then
    return false;
  end if;

  -- 2. parent/child hierarchy blocks module for tenant
  if exists (
    select 1
    from public.tenants
    where id = p_tenant_id
      and parent_id is not null
  ) and p_module_key in (
    'global_shipment', 'global_stock', 'global_stock_type', 'procurement_stock',
    'shipment_reports', 'parent_dashboard', 'investor_reports',
    'investor_profiles', 'investor_capital_ledger', 'investor_shipment_share', 'investor_portal'
  ) then
    return false;
  end if;

  -- 3. Resolve active action entries in module_actions
  select
    exists(
      select 1 from public.module_actions ma
      where ma.module_key = p_module_key and ma.action = p_action
        and ma.scope in ('app', 'investor') and ma.is_active = true
    ),
    exists(
      select 1 from public.module_actions ma
      where ma.module_key = p_module_key and ma.action = p_action
        and ma.scope = 'shop' and ma.is_active = true
    )
  into v_has_app_action, v_has_shop_action;

  -- 4. Check App Scope permissions
  if v_has_app_action and exists (
    select 1 from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    select m.id, m.tenant_role_id, tr.is_admin
    into v_member_id, v_tenant_role_id, v_role_is_admin
    from public.memberships m
    left join public.tenant_roles tr on tr.id = m.tenant_role_id
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true;

    -- Administrator shortcut
    if coalesce(v_role_is_admin, false) = true then
      return true;
    end if;

    -- Member overrides
    select effect
    into v_override_effect
    from public.membership_grants
    where membership_id = v_member_id
      and module_key = p_module_key
      and action = p_action;

    if v_override_effect = 'deny' then
      return false;
    elsif v_override_effect = 'allow' then
      return true;
    end if;

    -- Role grants
    select allowed
    into v_role_allowed
    from public.tenant_role_grants
    where tenant_role_id = v_tenant_role_id
      and module_key = p_module_key
      and action = p_action;

    return coalesce(v_role_allowed, false);

  -- 5. Check Shop Scope permissions
  elsif v_has_shop_action and exists (
    select 1
    from public.customer_group_members cgm
    join public.customer_groups cg on cg.id = cgm.customer_group_id
    where cg.tenant_id = p_tenant_id
      and lower(trim(cgm.email)) = public.current_user_email()
      and cgm.is_active = true
      and cg.is_active = true
  ) then
    -- Administrator shortcut check
    if exists (
      select 1
      from public.customer_group_members cgm
      join public.customer_groups cg on cg.id = cgm.customer_group_id
      join public.tenant_roles tr on tr.id = cgm.tenant_role_id
      where cg.tenant_id = p_tenant_id
        and cg.is_active = true
        and cgm.is_active = true
        and lower(trim(cgm.email)) = public.current_user_email()
        and tr.is_admin = true
    ) then
      return true;
    end if;

    -- Resolve overrides and role grants
    select
      coalesce(
        bool_or(case when g.effect = 'allow' then true else null end),
        bool_or(case when g.effect = 'deny' then false else null end),
        bool_or(rg.allowed)
      ) into v_shop_allowed
    from public.customer_group_members cgm
    join public.customer_groups cg on cg.id = cgm.customer_group_id
    left join public.customer_group_member_grants g
      on g.customer_group_member_id = cgm.id
      and g.module_key = p_module_key
      and g.action = p_action
    left join public.tenant_role_grants rg
      on rg.tenant_role_id = cgm.tenant_role_id
      and rg.module_key = p_module_key
      and rg.action = p_action
    where cg.tenant_id = p_tenant_id
      and cg.is_active = true
      and cgm.is_active = true
      and lower(trim(cgm.email)) = public.current_user_email();

    return coalesce(v_shop_allowed, false);
  end if;

  return false;
end;
$$;

-- =========================================================
-- 5. Redefine user_can_manage_parent_tenant (Pilot Domain Cutover)
-- =========================================================
create or replace function public.user_can_manage_parent_tenant(p_parent_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_parent_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and (
        m.role = 'admin'
        or public.has_module_action(p_parent_tenant_id, 'procurement_stock', 'manage')
      )
  );
$$;

-- =========================================================
-- 6. Backfill existing tenants' role grants
-- =========================================================
select public.seed_tenant_roles_and_grants(id) from public.tenants;

commit;
