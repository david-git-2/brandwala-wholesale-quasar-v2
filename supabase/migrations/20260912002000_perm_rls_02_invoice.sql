begin;

-- =========================================================
-- Invoice / sales_invoice domain RLS cutover
-- =========================================================

drop policy if exists recipient_profiles_write on public.recipient_profiles;
create policy recipient_profiles_write on public.recipient_profiles
for all to authenticated
using (public.membership_has_module_action(recipient_profiles.tenant_id, 'recipient_profile', 'edit'))
with check (public.membership_has_module_action(recipient_profiles.tenant_id, 'recipient_profile', 'edit'));

drop policy if exists global_invoices_write on public.global_invoices;
create policy global_invoices_write on public.global_invoices
for all to authenticated
using (
  public.membership_has_module_action(global_invoices.tenant_id, 'global_invoice', 'edit')
  or public.user_can_manage_parent_tenant(parent_tenant_id)
)
with check (
  public.membership_has_module_action(global_invoices.tenant_id, 'global_invoice', 'edit')
  or public.user_can_manage_parent_tenant(parent_tenant_id)
);

drop policy if exists billing_profiles_write on public.billing_profiles;
create policy billing_profiles_write on public.billing_profiles
for all to authenticated
using (public.membership_has_module_action(billing_profiles.tenant_id, 'billing_profile', 'edit'))
with check (public.membership_has_module_action(billing_profiles.tenant_id, 'billing_profile', 'edit'));

-- invoice_brands (if table exists from sales_invoice hierarchy)
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'invoice_brands'
  ) then
    execute 'drop policy if exists invoice_brands_write on public.invoice_brands';
    execute $policy$
      create policy invoice_brands_write on public.invoice_brands
      for all to authenticated
      using (public.membership_has_module_action(tenant_id, 'invoice_brand', 'edit'))
      with check (public.membership_has_module_action(tenant_id, 'invoice_brand', 'edit'))
    $policy$;
  end if;
end $$;

commit;
