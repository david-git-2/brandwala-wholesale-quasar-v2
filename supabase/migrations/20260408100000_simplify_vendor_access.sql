-- =========================================================
-- Simplify vendor access model
-- - remove tenant vendor access settings
-- - keep vendors tenant-owned or global
-- - superadmin manages global vendors only
-- - tenant admins manage their own vendors only
-- =========================================================

drop function if exists public.get_tenant_vendor_access_setting(bigint);
drop function if exists public.set_tenant_vendor_access_setting(bigint, boolean);

drop policy if exists "superadmin_can_manage_tenant_vendor_access_settings"
on public.tenant_vendor_access_settings;

drop policy if exists "tenant_admin_can_view_own_vendor_access_settings"
on public.tenant_vendor_access_settings;

drop policy if exists "vendors_select"
on public.vendors;

drop policy if exists "vendors_insert"
on public.vendors;

drop policy if exists "vendors_update"
on public.vendors;

drop policy if exists "vendors_delete"
on public.vendors;

drop table if exists public.tenant_vendor_access_settings;

drop function if exists public.is_vendor_module_enabled(bigint);

create policy "vendors_select"
on public.vendors
for select
to authenticated
using (
  (
    public.is_superadmin()
    and tenant_id is null
  )
  or exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'
      and m.is_active = true
      and m.tenant_id is not null
      and vendors.tenant_id = m.tenant_id
  )
);

create policy "vendors_insert"
on public.vendors
for insert
to authenticated
with check (
  (
    public.is_superadmin()
    and tenant_id is null
  )
  or exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'
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
  or exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'
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
  or exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'
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
  or exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'admin'
      and m.is_active = true
      and m.tenant_id is not null
      and vendors.tenant_id = m.tenant_id
  )
);
