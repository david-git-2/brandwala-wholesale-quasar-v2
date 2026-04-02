grant select, insert, update, delete on table public.costing_files to authenticated;
grant select, insert, update, delete on table public.costing_file_items to authenticated;

grant usage, select on sequence public.costing_files_id_seq to authenticated;
grant usage, select on sequence public.costing_file_items_id_seq to authenticated;
