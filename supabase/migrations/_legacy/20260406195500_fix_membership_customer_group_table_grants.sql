-- =========================================================
-- Fix missing grants for memberships and customer-group tables.
-- RLS policies still enforce access rules.
-- =========================================================

grant select, insert, update, delete
on table public.memberships
to authenticated;

grant usage, select
on sequence public.memberships_id_seq
to authenticated;

grant select, insert, update, delete
on table public.customer_groups
to authenticated;

grant select, insert, update, delete
on table public.customer_group_members
to authenticated;

grant usage, select
on sequence public.customer_groups_id_seq
to authenticated;

grant usage, select
on sequence public.customer_group_members_id_seq
to authenticated;
