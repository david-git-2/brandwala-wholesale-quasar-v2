-- Child shop staff must see books-owned customer groups to grant shop access.
-- Group rows live on parent_tenant_id; tenant_id is kept in sync with that.

begin;

drop policy if exists "customer_groups_select" on public.customer_groups;

create policy "customer_groups_select"
  on public.customer_groups
  for select
  to authenticated
  using (
    public.can_manage_customer_group(coalesce(parent_tenant_id, tenant_id))
    or public.is_tenant_staff(coalesce(parent_tenant_id, tenant_id))
    or exists (
      select 1
      from public.tenants child
      where child.parent_id = coalesce(customer_groups.parent_tenant_id, customer_groups.tenant_id)
        and public.is_tenant_staff(child.id)
    )
  );

commit;
