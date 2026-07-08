-- =========================================================
-- Cleanup: remove seeded module rows that are no longer features
-- =========================================================
-- These module keys were seeded by earlier migrations but have since been
-- superseded or dropped and no longer exist in the app module registry
-- (web/src/modules/navigation/moduleRegistry.ts).
--
-- Deliberately EXCLUDED (still live, just absent from the tenant nav registry):
--   inventory                -> enforced by procurement RLS + role grants
--   platform_tenants         -> platform-scope permission module (perm_p3)
--   platform_memberships     -> platform-scope permission module (perm_p3)
--   platform_modules         -> platform-scope permission module (perm_p3)
--   platform_markets         -> platform-scope permission module (perm_p3)
-- =========================================================

-- 1. Remove stale tenant links for superseded modules.
delete from public.tenant_modules
where module_key in (
  'shipment',
  'commerce_shop',
  'commerce_order',
  'commerce_invoice',
  'commerce_cart',
  'commerce_accounting'
);

-- 2. Delete the dead module rows. Grant/action tables cascade on delete,
--    but the keys below have zero grant/action references.
delete from public.modules
where key in (
  -- zero references anywhere
  'accounting',
  'cart',
  'store',
  'investor',
  'invoice',
  'global_accounting_ledger',
  'global_investor',
  'global_investor_shipment',
  'global_invoice_accounting',
  'global_shipment_accounting',
  'thrift_accounting_ledger',
  'thrift_currency',
  'thrift_invoice',
  'thrift_invoice_item',
  'thrift_pricing',
  -- superseded, only stale tenant_modules links (removed above)
  'shipment',
  'commerce_shop',
  'commerce_order',
  'commerce_invoice',
  'commerce_cart',
  'commerce_accounting'
);
