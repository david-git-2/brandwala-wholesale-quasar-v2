-- =========================================================
-- Harden cart insert/update RLS checks for customer store flow
-- =========================================================

drop policy if exists carts_insert on public.carts;
create policy carts_insert
on public.carts
for insert
to authenticated
with check (
  public.has_active_tenant_membership(tenant_id)
  or (
    store_id is not null
    and exists (
      select 1
      from public.stores s
      where s.id = store_id
        and s.tenant_id = tenant_id
        and public.can_customer_access_store(s.id)
    )
  )
  or (
    customer_group_id is not null
    and exists (
      select 1
      from public.customer_groups cg
      join public.customer_group_members cgm
        on cgm.customer_group_id = cg.id
      where cg.id = customer_group_id
        and cg.tenant_id = tenant_id
        and lower(trim(cgm.email)) = public.current_user_email()
        and cgm.is_active = true
    )
  )
);

drop policy if exists carts_update on public.carts;
create policy carts_update
on public.carts
for update
to authenticated
using (
  public.can_access_cart(id)
)
with check (
  public.has_active_tenant_membership(tenant_id)
  or (
    store_id is not null
    and exists (
      select 1
      from public.stores s
      where s.id = store_id
        and s.tenant_id = tenant_id
        and public.can_customer_access_store(s.id)
    )
  )
  or (
    customer_group_id is not null
    and exists (
      select 1
      from public.customer_groups cg
      join public.customer_group_members cgm
        on cgm.customer_group_id = cg.id
      where cg.id = customer_group_id
        and cg.tenant_id = tenant_id
        and lower(trim(cgm.email)) = public.current_user_email()
        and cgm.is_active = true
    )
  )
);
