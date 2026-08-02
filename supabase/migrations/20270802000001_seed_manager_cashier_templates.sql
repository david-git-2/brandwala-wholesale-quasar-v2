-- Migration: Seed system_role_templates and tenant_roles for manager and cashier

-- 1. Seed default system_role_templates for manager role (App Scope)
-- Manager: Full read/write operational access across core modules
INSERT INTO public.system_role_templates (scope, role_slug, module_key, action, allowed)
SELECT 'app', 'manager', ma.module_key, ma.action, true
FROM public.module_actions ma
ON CONFLICT (scope, role_slug, module_key, action) DO NOTHING;

-- 2. Seed default system_role_templates for cashier role (App Scope)
-- Cashier: Sales, POS, register balancing, and customer order management actions
INSERT INTO public.system_role_templates (scope, role_slug, module_key, action, allowed)
SELECT 'app', 'cashier', ma.module_key, ma.action,
  CASE 
    WHEN ma.module_key IN ('commerce_orders', 'customer_groups', 'finance_billing', 'thrift_items') 
         AND ma.action IN ('view', 'create', 'update', 'checkout', 'issue_invoice', 'collect_payment') THEN true
    ELSE false
  END
FROM public.module_actions ma
ON CONFLICT (scope, role_slug, module_key, action) DO NOTHING;

-- 3. Seed system tenant_roles for all existing tenants if missing
INSERT INTO public.tenant_roles (tenant_id, name, slug, is_system, is_admin, source_app_role, scope)
SELECT 
  t.id,
  r.name,
  r.slug,
  true AS is_system,
  r.is_admin,
  r.source_app_role,
  'app' AS scope
FROM public.tenants t
CROSS JOIN (
  VALUES 
    ('Manager', 'manager', false, 'manager'::public.app_role),
    ('Cashier', 'cashier', false, 'cashier'::public.app_role)
) AS r(name, slug, is_admin, source_app_role)
WHERE NOT EXISTS (
  SELECT 1 FROM public.tenant_roles tr
  WHERE tr.tenant_id = t.id AND tr.slug = r.slug AND tr.scope = 'app'
);
