begin;

-- =========================================================
-- 1. Insert/Update Parent Module
-- =========================================================
insert into public.modules (key, name, description, is_active, parent_module_key)
values (
  'reporting_treasury',
  'Reports & Treasury',
  'Parent module for payments, balances, and margin reports.',
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
    'payments',
    'Payments & Collection',
    'Record payments and allocate to invoices.',
    true,
    'reporting_treasury'
  ),
  (
    'invoice_reports',
    'Invoice Reports',
    'Invoice margins and gross profit reports.',
    true,
    'reporting_treasury'
  ),
  (
    'shipment_reports',
    'Shipment Reports',
    'Shipment batch landed cost vs realized margin P&L.',
    true,
    'reporting_treasury'
  ),
  (
    'billing_balances',
    'Customer Balances',
    'Total amount due per billing profile.',
    true,
    'reporting_treasury'
  ),
  (
    'parent_dashboard',
    'Consolidated Dashboard',
    'Roll up sales and margin across sister concerns.',
    true,
    'reporting_treasury'
  ),
  (
    'investor_reports',
    'Investor Reports',
    'Profit share per shipment batch for investors.',
    true,
    'reporting_treasury'
  )
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active,
  parent_module_key = excluded.parent_module_key;

-- =========================================================
-- 3. Migrate Tenant Assignments
-- =========================================================
-- Assign reporting_treasury parent to any tenant that had accounting or any global_*_accounting keys enabled
insert into public.tenant_modules (tenant_id, module_key, is_active)
select distinct tm.tenant_id, 'reporting_treasury', true
from public.tenant_modules tm
where tm.module_key in ('accounting', 'global_accounting_ledger', 'global_invoice_accounting', 'global_shipment_accounting')
  and tm.is_active = true
  and not exists (
    select 1
    from public.tenant_modules existing
    where existing.tenant_id = tm.tenant_id
      and existing.module_key = 'reporting_treasury'
  );

-- Delete direct submodule tenant assignments since they are now resolved via parent expansion
delete from public.tenant_modules
where module_key in ('accounting', 'global_accounting_ledger', 'global_invoice_accounting', 'global_shipment_accounting');

-- =========================================================
-- 4. Deactivate Legacy Module Keys
-- =========================================================
update public.modules
set is_active = false
where key in ('accounting', 'global_accounting_ledger', 'global_invoice_accounting', 'global_shipment_accounting');

commit;
