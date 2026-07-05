begin;

-- =========================================================
-- 1. Insert/Update Parent Module
-- =========================================================
insert into public.modules (key, name, description, is_active, parent_module_key)
values (
  'investor_capital',
  'Investor Capital',
  'Parent module for investor profiles, capital ledger, shipment share allocations, and investor portal.',
  true,
  null
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active,
  parent_module_key = excluded.parent_module_key;

-- =========================================================
-- 2. Insert/Update Submodules with parent assignment
-- =========================================================
insert into public.modules (key, name, description, is_active, parent_module_key)
values
  (
    'investor_profiles',
    'Investor Profiles',
    'Manage investor profiles and client contact details.',
    true,
    'investor_capital'
  ),
  (
    'investor_capital_ledger',
    'Capital Ledger',
    'Manage capital deposits, adjustments, and withdrawal transactions.',
    true,
    'investor_capital'
  ),
  (
    'investor_shipment_share',
    'Shipment Share Allocations',
    'Assign investor cost-share percentage and track shipment profit allocations.',
    true,
    'investor_capital'
  ),
  (
    'investor_portal',
    'Investor Portal',
    'External read-only dashboard for investors to track their portfolio.',
    true,
    'investor_capital'
  )
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active,
  parent_module_key = excluded.parent_module_key;

-- =========================================================
-- 3. Migrate Tenant Assignments
-- =========================================================
-- Assign investor_capital parent to any tenant that had investor, global_investor, or global_investor_shipment keys enabled
insert into public.tenant_modules (tenant_id, module_key, is_active)
select distinct tm.tenant_id, 'investor_capital', true
from public.tenant_modules tm
where tm.module_key in ('investor', 'global_investor', 'global_investor_shipment')
  and tm.is_active = true
  and not exists (
    select 1
    from public.tenant_modules existing
    where existing.tenant_id = tm.tenant_id
      and existing.module_key = 'investor_capital'
  );

-- Delete direct submodule tenant assignments since they are now resolved via parent expansion
delete from public.tenant_modules
where module_key in ('investor', 'global_investor', 'global_investor_shipment');

-- =========================================================
-- 4. Deactivate Legacy Module Keys
-- =========================================================
update public.modules
set is_active = false
where key in ('investor', 'global_investor', 'global_investor_shipment');

commit;
