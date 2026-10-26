-- =========================================================
-- Add tenant_id to product_brands and product_categories
-- =========================================================

begin;

-- 1) Add tenant_id column to product_brands
alter table public.product_brands 
  add column if not exists tenant_id bigint null;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'product_brands_tenant_id_fkey'
  ) then
    alter table public.product_brands
      add constraint product_brands_tenant_id_fkey
      foreign key (tenant_id) references public.tenants(id)
      on delete cascade;
  end if;
end
$$;

-- 2) Add tenant_id column to product_categories
alter table public.product_categories 
  add column if not exists tenant_id bigint null;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'product_categories_tenant_id_fkey'
  ) then
    alter table public.product_categories
      add constraint product_categories_tenant_id_fkey
      foreign key (tenant_id) references public.tenants(id)
      on delete cascade;
  end if;
end
$$;

-- 3) Backfill tenant_id from associated vendor_id
update public.product_brands b
set tenant_id = v.tenant_id
from public.vendors v
where b.vendor_id = v.id
  and b.tenant_id is null;

update public.product_categories c
set tenant_id = v.tenant_id
from public.vendors v
where c.vendor_id = v.id
  and c.tenant_id is null;

-- 4) Backfill tenant_id from vendor_code if vendor_id was null
update public.product_brands b
set tenant_id = v.tenant_id
from public.vendors v
where b.tenant_id is null
  and b.vendor_code is not null
  and upper(trim(b.vendor_code)) = upper(trim(v.code));

update public.product_categories c
set tenant_id = v.tenant_id
from public.vendors v
where c.tenant_id is null
  and c.vendor_code is not null
  and upper(trim(c.vendor_code)) = upper(trim(v.code));

-- 5) Add indexes
create index if not exists product_brands_tenant_id_idx on public.product_brands (tenant_id);
create index if not exists product_categories_tenant_id_idx on public.product_categories (tenant_id);

commit;
