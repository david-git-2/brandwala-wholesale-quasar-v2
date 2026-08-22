-- Reparent billing_profile from sales_invoice to customer (no sidebar link).

begin;

update public.modules
set
  parent_module_key = 'customer',
  description = 'Financial identity for invoices. Opened from Customers, not a sidebar item.'
where key = 'billing_profile';

update public.tenant_module_submodules
set parent_module_key = 'customer'
where submodule_key = 'billing_profile'
  and parent_module_key = 'sales_invoice';

commit;
