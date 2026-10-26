-- Ensure backend product sync (python:pc) works across fresh environments.
-- Grants are idempotent and safe to re-run.

begin;

grant usage on schema public to service_role;

grant select on table public.markets to service_role;
grant select on table public.vendors to service_role;

grant select, insert, update on table public.products to service_role;
grant usage, select on sequence public.products_id_seq to service_role;

commit;
