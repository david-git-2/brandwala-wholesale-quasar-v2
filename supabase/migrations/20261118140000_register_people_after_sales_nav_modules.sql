-- Register People and After Sales in the module catalog so production nav and grants resolve like other app modules.
-- after_sales expands automatically when sales_invoice is assigned; people is enabled for tenants that use party/cash desks.

BEGIN;

-- Parent must exist before after_sales FK (prod may have module rows only from legacy seeds).
INSERT INTO public.modules (key, name, description, is_active, parent_module_key)
VALUES (
  'sales_invoice',
  'Sales & Invoice',
  'Parent module for sales invoices, billing profiles, recipient profiles, and invoice brands.',
  true,
  NULL
)
ON CONFLICT (key) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  is_active = EXCLUDED.is_active,
  parent_module_key = EXCLUDED.parent_module_key;

INSERT INTO public.modules (key, name, description, is_active, parent_module_key)
VALUES
  (
    'after_sales',
    'After Sales Service',
    'Returns, replacement, warranty, and dropship complaint cases.',
    true,
    'sales_invoice'
  ),
  (
    'people',
    'People',
    'Parties, operating accounts, customers, vendors, cargo, and investors in one directory.',
    true,
    NULL
  )
ON CONFLICT (key) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  is_active = EXCLUDED.is_active,
  parent_module_key = EXCLUDED.parent_module_key;

INSERT INTO public.module_actions (module_key, action, scope, tenant_configurable, is_active)
VALUES
  ('after_sales', 'view', 'app', true, true),
  ('people', 'view', 'app', true, true)
ON CONFLICT (module_key, action, scope) DO UPDATE SET
  is_active = true,
  tenant_configurable = true;

INSERT INTO public.tenant_modules (tenant_id, module_key, is_active)
SELECT DISTINCT tm.tenant_id, 'people', true
FROM public.tenant_modules tm
WHERE tm.is_active = true
  AND tm.module_key IN (
    'cashbook',
    'customer',
    'vendor',
    'sales_invoice',
    'investor_capital',
    'global_invoice'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.tenant_modules existing
    WHERE existing.tenant_id = tm.tenant_id
      AND existing.module_key = 'people'
  );

COMMIT;