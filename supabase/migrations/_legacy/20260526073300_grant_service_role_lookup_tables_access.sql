-- Grant access to product lookup tables and sequences for service_role (backend sync scripts).
begin;

grant select, insert, update, delete on table public.product_brands to service_role;
grant select, insert, update, delete on table public.product_categories to service_role;

grant usage, select on sequence public.product_brands_id_seq to service_role;
grant usage, select on sequence public.product_categories_id_seq to service_role;

commit;
