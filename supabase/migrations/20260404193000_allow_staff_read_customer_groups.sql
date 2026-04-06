-- Let tenant staff read customer groups so they can load the customer list in costing flows.

drop policy if exists "customer_groups_select" on public.customer_groups;
create policy "customer_groups_select"
on public.customer_groups
for select
to authenticated
using (
  public.can_manage_customer_group(tenant_id)
  or public.is_tenant_staff(tenant_id)
);
