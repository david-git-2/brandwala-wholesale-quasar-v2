-- =========================================================
-- Grant authenticated access to customer group ID sequences
-- Needed for inserts that rely on bigserial nextval().
-- =========================================================

grant usage, select
on sequence public.customer_groups_id_seq
to authenticated;

grant usage, select
on sequence public.customer_group_members_id_seq
to authenticated;
