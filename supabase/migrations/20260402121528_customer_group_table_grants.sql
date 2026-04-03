-- =========================================================
-- Grant authenticated access to customer group tables
-- RLS policies still enforce tenant-scoped visibility and writes.
-- =========================================================

grant select, insert, update, delete
on table public.customer_groups
to authenticated;

grant select, insert, update, delete
on table public.customer_group_members
to authenticated;
