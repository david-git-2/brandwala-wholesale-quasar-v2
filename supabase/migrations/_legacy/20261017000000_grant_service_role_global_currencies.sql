-- Allow python product sync to resolve list_price_currency_id (GBP)
-- and validate products.tenant_id / parent_tenant_id FKs (+ parent trigger).

begin;

grant select on table public.global_currencies to service_role;
grant execute on function public.list_global_currencies() to service_role;

grant select on table public.tenants to service_role;

commit;
