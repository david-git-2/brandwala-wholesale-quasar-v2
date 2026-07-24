-- Migration: 20261123000000_seed_shop_category_module.sql
-- Description: Seed shop_category submodule in master catalog and enable for tenant 10 and all shop_order tenants

BEGIN;

-- 1. Insert or update shop_category submodule in public.modules catalog
INSERT INTO public.modules (key, name, description, is_active, parent_module_key)
VALUES (
  'shop_category',
  'Shop Categories',
  'Manage tenant shop categories displayed across customer storefronts.',
  true,
  'shop_order'
)
ON CONFLICT (key) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  is_active = EXCLUDED.is_active,
  parent_module_key = EXCLUDED.parent_module_key;

-- 2. Insert module_actions catalog for shop_category
INSERT INTO public.module_actions (module_key, action, scope, tenant_configurable, is_active)
VALUES
  ('shop_category', 'view', 'app', true, true)
ON CONFLICT (module_key, action, scope) DO UPDATE SET
  is_active = true;

-- 3. Enable shop_category in tenant_modules for tenant 10 and all tenants with shop_order or shop_config
INSERT INTO public.tenant_modules (tenant_id, module_key, is_active)
SELECT DISTINCT tm.tenant_id, 'shop_category', true
FROM public.tenant_modules tm
WHERE tm.module_key IN ('shop_order', 'shop_order_mgmt', 'shop_config') AND tm.is_active = true
ON CONFLICT (tenant_id, module_key) DO UPDATE SET
  is_active = true;

-- Ensure tenant 10 explicitly has shop_category enabled if tenant 10 exists
INSERT INTO public.tenant_modules (tenant_id, module_key, is_active)
SELECT id, 'shop_category', true
FROM public.tenants
WHERE id = 10
ON CONFLICT (tenant_id, module_key) DO UPDATE SET
  is_active = true;

COMMIT;
