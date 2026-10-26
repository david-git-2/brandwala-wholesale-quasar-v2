-- Reparent recipient_profile from sales_invoice to customer (sidebar family).

begin;

update public.modules
set
  parent_module_key = 'customer',
  description = 'Manage end-customer delivery and drop-ship target profiles.'
where key = 'recipient_profile';

update public.tenant_module_submodules
set parent_module_key = 'customer'
where submodule_key = 'recipient_profile'
  and parent_module_key = 'sales_invoice';

commit;
