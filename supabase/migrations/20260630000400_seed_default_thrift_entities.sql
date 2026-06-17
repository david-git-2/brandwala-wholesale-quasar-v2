begin;

-- Seed default category for all tenants
insert into public.thrift_categories (tenant_id, name, description, inserted_by)
select id, 'General', 'Default Category', 'system'
from public.tenants
on conflict (tenant_id, name) do nothing;

-- Seed default type for all tenants
insert into public.thrift_types (tenant_id, name, description, inserted_by)
select id, 'General', 'Default Type', 'system'
from public.tenants
on conflict (tenant_id, name) do nothing;

-- Seed default shelf for all tenants
insert into public.thrift_shelves (tenant_id, name, shelf_code, inserted_by)
select id, 'Default Shelf', 'A1', 'system'
from public.tenants
on conflict (tenant_id, shelf_code) do nothing;

commit;
