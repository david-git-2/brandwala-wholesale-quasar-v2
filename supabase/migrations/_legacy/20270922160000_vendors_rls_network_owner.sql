-- Company owners (app_role owner) can insert/update/delete tenant vendors.
-- Previous policies required memberships.role = 'admin', which owners do not have.

drop policy if exists "vendors_insert" on public.vendors;
drop policy if exists "vendors_update" on public.vendors;
drop policy if exists "vendors_delete" on public.vendors;

create policy "vendors_insert"
on public.vendors
for insert
to authenticated
with check (
  (
    public.is_superadmin()
    and tenant_id is null
  )
  or (
    tenant_id is not null
    and public.is_network_owner(tenant_id)
  )
  or exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'::public.app_role
      and m.is_active = true
      and m.tenant_id is not null
      and vendors.tenant_id = m.tenant_id
  )
);

create policy "vendors_update"
on public.vendors
for update
to authenticated
using (
  (
    public.is_superadmin()
    and tenant_id is null
  )
  or (
    tenant_id is not null
    and public.is_network_owner(tenant_id)
  )
  or exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'::public.app_role
      and m.is_active = true
      and m.tenant_id is not null
      and vendors.tenant_id = m.tenant_id
  )
)
with check (
  (
    public.is_superadmin()
    and tenant_id is null
  )
  or (
    tenant_id is not null
    and public.is_network_owner(tenant_id)
  )
  or exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'::public.app_role
      and m.is_active = true
      and m.tenant_id is not null
      and vendors.tenant_id = m.tenant_id
  )
);

create policy "vendors_delete"
on public.vendors
for delete
to authenticated
using (
  (
    public.is_superadmin()
    and tenant_id is null
  )
  or (
    tenant_id is not null
    and public.is_network_owner(tenant_id)
  )
  or exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'::public.app_role
      and m.is_active = true
      and m.tenant_id is not null
      and vendors.tenant_id = m.tenant_id
  )
);
