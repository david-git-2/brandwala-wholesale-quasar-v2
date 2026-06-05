begin;

-- Drop old select policy if exists
drop policy if exists "memberships_select" on public.memberships;

-- Create updated select policy allowing any active tenant member to read memberships in that tenant
create policy "memberships_select"
on public.memberships
for select
to authenticated
using (
  public.is_superadmin()
  or public.has_active_tenant_membership(tenant_id)
);

commit;
