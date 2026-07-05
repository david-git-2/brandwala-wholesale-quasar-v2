begin;

-- =========================================================
-- 1. Insert/Update Parent Module
-- =========================================================
insert into public.modules (key, name, description, is_active, parent_module_key)
values (
  'sales_invoice',
  'Sales & Invoice',
  'Parent module for sales invoices, billing profiles, recipient profiles, and invoice brands.',
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
    'global_invoice',
    'Global Invoice',
    'Unified invoice model for retail and wholesale; parent or child issuer.',
    true,
    'sales_invoice'
  ),
  (
    'billing_profile',
    'Billing Profiles',
    'Manage billing profiles and customer group configurations.',
    true,
    'sales_invoice'
  ),
  (
    'recipient_profile',
    'Recipient Profiles',
    'Manage end-customer delivery and drop-ship target profiles.',
    true,
    'sales_invoice'
  ),
  (
    'invoice_brand',
    'Invoice Brands',
    'Configure invoice branding, logos, layout styles, and details.',
    true,
    'sales_invoice'
  ),
  (
    'invoice',
    'Legacy Invoice',
    'Legacy invoice access and redirect configuration.',
    true,
    'sales_invoice'
  )
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active,
  parent_module_key = excluded.parent_module_key;

-- =========================================================
-- 3. Migrate Tenant Assignments
-- =========================================================
insert into public.tenant_modules (tenant_id, module_key, is_active)
select distinct tm.tenant_id, 'sales_invoice', true
from public.tenant_modules tm
where tm.module_key in ('global_invoice', 'invoice')
  and tm.is_active = true
  and not exists (
    select 1
    from public.tenant_modules existing
    where existing.tenant_id = tm.tenant_id
      and existing.module_key = 'sales_invoice'
  );

-- Delete direct submodule tenant assignments since they are now resolved via parent expansion
delete from public.tenant_modules
where module_key in ('global_invoice', 'invoice');

commit;
