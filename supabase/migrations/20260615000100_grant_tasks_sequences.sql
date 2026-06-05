begin;

-- Grant sequence permissions to authenticated users
grant usage, select on sequence public.items_id_seq to authenticated;
grant usage, select on sequence public.item_assignees_id_seq to authenticated;
grant usage, select on sequence public.tags_id_seq to authenticated;
grant usage, select on sequence public.item_tags_id_seq to authenticated;
grant usage, select on sequence public.comments_id_seq to authenticated;
grant usage, select on sequence public.item_permissions_id_seq to authenticated;
grant usage, select on sequence public.activity_logs_id_seq to authenticated;

commit;
