-- Grant access to sequence for koba_brands and koba_categories tables for backend sync scripts and users
begin;

grant usage, select on sequence public.koba_brands_id_seq to service_role;
grant usage, select on sequence public.koba_brands_id_seq to authenticated;

grant usage, select on sequence public.koba_categories_id_seq to service_role;
grant usage, select on sequence public.koba_categories_id_seq to authenticated;

commit;
