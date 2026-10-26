-- =========================================================
-- Create product brand/category lookup tables
-- =========================================================

create table if not exists public.product_brands (
  id bigserial primary key,
  name text not null,
  value text generated always as (lower(trim(name))) stored,
  vendor_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint product_brands_name_not_blank check (length(trim(name)) > 0)
);

create table if not exists public.product_categories (
  id bigserial primary key,
  name text not null,
  value text generated always as (lower(trim(name))) stored,
  vendor_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint product_categories_name_not_blank check (length(trim(name)) > 0)
);

create unique index if not exists product_brands_vendor_value_unique
  on public.product_brands (coalesce(upper(trim(vendor_code)), ''), value);

create unique index if not exists product_categories_vendor_value_unique
  on public.product_categories (coalesce(upper(trim(vendor_code)), ''), value);

create index if not exists product_brands_vendor_code_idx
  on public.product_brands (vendor_code);

create index if not exists product_categories_vendor_code_idx
  on public.product_categories (vendor_code);

-- Keep updated_at fresh on updates.
create or replace function public.set_product_lookup_updated_at_timestamp()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_product_brands_set_updated_at on public.product_brands;
create trigger trg_product_brands_set_updated_at
before update on public.product_brands
for each row
execute function public.set_product_lookup_updated_at_timestamp();

drop trigger if exists trg_product_categories_set_updated_at on public.product_categories;
create trigger trg_product_categories_set_updated_at
before update on public.product_categories
for each row
execute function public.set_product_lookup_updated_at_timestamp();

-- Backfill lookup tables from existing products.
insert into public.product_brands (name, vendor_code)
select distinct
  trim(p.brand) as name,
  nullif(upper(trim(p.vendor_code)), '') as vendor_code
from public.products p
where p.brand is not null and length(trim(p.brand)) > 0
on conflict do nothing;

insert into public.product_categories (name, vendor_code)
select distinct
  trim(p.category) as name,
  nullif(upper(trim(p.vendor_code)), '') as vendor_code
from public.products p
where p.category is not null and length(trim(p.category)) > 0
on conflict do nothing;
