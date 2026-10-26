-- =========================================================
-- Add tenant visibility policy for members
-- =========================================================

create policy "members_can_view_tenants"
on public.tenants
for select
to authenticated
using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = public.tenants.id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);
