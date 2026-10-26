-- =========================================================
-- Allow users to view their own memberships
-- =========================================================

create policy "memberships_select_own"
on public.memberships
for select
to authenticated
using (
  lower(trim(email)) = public.current_user_email()
);
