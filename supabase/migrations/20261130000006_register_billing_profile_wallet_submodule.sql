-- =========================================================
-- Migration: Register billing_profile_wallet submodule in public.modules
-- and auto-enable for all tenants with sales_invoice active module
-- =========================================================

begin;

-- 1. Insert or update billing_profile_wallet submodule in public.modules catalog
insert into public.modules (key, name, description, is_active, parent_module_key)
values (
  'billing_profile_wallet',
  'Billing Profile Wallet',
  'Unified financial ledger and wallet balances for billing profiles.',
  true,
  'sales_invoice'
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active,
  parent_module_key = excluded.parent_module_key;

-- 2. Insert default module_actions catalog for billing_profile_wallet
insert into public.module_actions (module_key, action, scope, tenant_configurable, is_active)
values
  ('billing_profile_wallet', 'view', 'app', true, true)
on conflict (module_key, action, scope) do update set
  is_active = true;

-- 3. Auto-enable billing_profile_wallet in tenant_modules (or expand via parent sales_invoice)
-- Note: Under parent/child module expansion (get_active_module_keys_for_tenant),
-- any tenant with 'sales_invoice' active automatically gains active status for all active child submodules,
-- unless explicitly disabled in tenant_module_submodules.

commit;
