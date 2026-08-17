-- SI3: Child sees only invoices they sold; parent sees the group.
-- SELECT/UPDATE keyed on issued_by_tenant_id (seller), not books tenant_id.

begin;

drop policy if exists global_invoices_select on public.global_invoices;
create policy global_invoices_select on public.global_invoices
for select to authenticated
using (
  public.has_active_tenant_membership(issued_by_tenant_id)
  or public.user_can_manage_parent_tenant(parent_tenant_id)
  or public.user_can_manage_parent_tenant(tenant_id)
);

drop policy if exists global_invoices_write on public.global_invoices;
create policy global_invoices_write on public.global_invoices
for all to authenticated
using (
  public.membership_has_module_action(issued_by_tenant_id, 'global_invoice', 'edit')
  or public.user_can_manage_parent_tenant(parent_tenant_id)
  or public.user_can_manage_parent_tenant(tenant_id)
)
with check (
  public.membership_has_module_action(issued_by_tenant_id, 'global_invoice', 'edit')
  or public.user_can_manage_parent_tenant(parent_tenant_id)
  or public.user_can_manage_parent_tenant(tenant_id)
);

do $$
begin
  assert exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'global_invoices'
      and policyname = 'global_invoices_select'
  ), 'SI3: global_invoices_select policy missing';
  assert exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'global_invoices'
      and policyname = 'global_invoices_write'
  ), 'SI3: global_invoices_write policy missing';
end $$;

commit;
