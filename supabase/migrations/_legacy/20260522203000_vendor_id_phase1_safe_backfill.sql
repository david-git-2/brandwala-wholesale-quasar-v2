begin;

-- 1) Add vendor_id columns (nullable, backwards compatible).
alter table public.products add column if not exists vendor_id bigint null;
alter table public.shipments add column if not exists vendor_id bigint null;
alter table public.stores add column if not exists vendor_id bigint null;
alter table public.product_based_costing_files add column if not exists vendor_id bigint null;
alter table public.product_based_costing_items add column if not exists vendor_id bigint null;
alter table public.product_brands add column if not exists vendor_id bigint null;
alter table public.product_categories add column if not exists vendor_id bigint null;
alter table public.product_sync_snapshots add column if not exists vendor_id bigint null;

-- 2) Backfill vendor_id from vendor_code.
update public.products p
set vendor_id = v.id
from public.vendors v
where p.vendor_id is null
  and p.vendor_code is not null
  and upper(trim(p.vendor_code)) = upper(trim(v.code));

update public.shipments s
set vendor_id = v.id
from public.vendors v
where s.vendor_id is null
  and s.vendor_code is not null
  and upper(trim(s.vendor_code)) = upper(trim(v.code));

update public.stores s
set vendor_id = v.id
from public.vendors v
where s.vendor_id is null
  and s.vendor_code is not null
  and upper(trim(s.vendor_code)) = upper(trim(v.code));

update public.product_based_costing_files f
set vendor_id = v.id
from public.vendors v
where f.vendor_id is null
  and f.vendor_code is not null
  and upper(trim(f.vendor_code)) = upper(trim(v.code));

update public.product_based_costing_items i
set vendor_id = v.id
from public.vendors v
where i.vendor_id is null
  and i.vendor_code is not null
  and upper(trim(i.vendor_code)) = upper(trim(v.code));

update public.product_brands b
set vendor_id = v.id
from public.vendors v
where b.vendor_id is null
  and b.vendor_code is not null
  and upper(trim(b.vendor_code)) = upper(trim(v.code));

update public.product_categories c
set vendor_id = v.id
from public.vendors v
where c.vendor_id is null
  and c.vendor_code is not null
  and upper(trim(c.vendor_code)) = upper(trim(v.code));

update public.product_sync_snapshots s
set vendor_id = v.id
from public.vendors v
where s.vendor_id is null
  and s.vendor_code is not null
  and upper(trim(s.vendor_code)) = upper(trim(v.code));

-- 3) Backfill vendor_code from vendor_id where missing.
update public.products p
set vendor_code = v.code
from public.vendors v
where p.vendor_code is null
  and p.vendor_id = v.id;

update public.shipments s
set vendor_code = v.code
from public.vendors v
where s.vendor_code is null
  and s.vendor_id = v.id;

update public.stores s
set vendor_code = v.code
from public.vendors v
where s.vendor_code is null
  and s.vendor_id = v.id;

update public.product_based_costing_files f
set vendor_code = v.code
from public.vendors v
where f.vendor_code is null
  and f.vendor_id = v.id;

update public.product_based_costing_items i
set vendor_code = v.code
from public.vendors v
where i.vendor_code is null
  and i.vendor_id = v.id;

update public.product_brands b
set vendor_code = v.code
from public.vendors v
where b.vendor_code is null
  and b.vendor_id = v.id;

update public.product_categories c
set vendor_code = v.code
from public.vendors v
where c.vendor_code is null
  and c.vendor_id = v.id;

update public.product_sync_snapshots s
set vendor_code = v.code
from public.vendors v
where s.vendor_code is null
  and s.vendor_id = v.id;

-- 4) Indexes.
create index if not exists products_vendor_id_idx on public.products (vendor_id);
create index if not exists shipments_vendor_id_idx on public.shipments (vendor_id);
create index if not exists stores_vendor_id_idx on public.stores (vendor_id);
create index if not exists product_based_costing_files_vendor_id_idx on public.product_based_costing_files (vendor_id);
create index if not exists product_based_costing_items_vendor_id_idx on public.product_based_costing_items (vendor_id);
create index if not exists product_brands_vendor_id_idx on public.product_brands (vendor_id);
create index if not exists product_categories_vendor_id_idx on public.product_categories (vendor_id);
create index if not exists product_sync_snapshots_vendor_id_idx on public.product_sync_snapshots (vendor_id);

-- Keep lookup querying fast by vendor_id during transition.
create index if not exists product_brands_vendor_id_value_idx
  on public.product_brands (vendor_id, value);

create index if not exists product_categories_vendor_id_value_idx
  on public.product_categories (vendor_id, value);

-- 5) Add vendor_id foreign keys without breaking existing vendor_code references.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'products_vendor_id_fkey'
  ) then
    alter table public.products
      add constraint products_vendor_id_fkey
      foreign key (vendor_id) references public.vendors(id)
      on update cascade
      on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'shipments_vendor_id_fkey'
  ) then
    alter table public.shipments
      add constraint shipments_vendor_id_fkey
      foreign key (vendor_id) references public.vendors(id)
      on update cascade
      on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'stores_vendor_id_fkey'
  ) then
    alter table public.stores
      add constraint stores_vendor_id_fkey
      foreign key (vendor_id) references public.vendors(id)
      on update cascade
      on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'product_based_costing_files_vendor_id_fkey'
  ) then
    alter table public.product_based_costing_files
      add constraint product_based_costing_files_vendor_id_fkey
      foreign key (vendor_id) references public.vendors(id)
      on update cascade
      on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'product_based_costing_items_vendor_id_fkey'
  ) then
    alter table public.product_based_costing_items
      add constraint product_based_costing_items_vendor_id_fkey
      foreign key (vendor_id) references public.vendors(id)
      on update cascade
      on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'product_brands_vendor_id_fkey'
  ) then
    alter table public.product_brands
      add constraint product_brands_vendor_id_fkey
      foreign key (vendor_id) references public.vendors(id)
      on update cascade
      on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'product_categories_vendor_id_fkey'
  ) then
    alter table public.product_categories
      add constraint product_categories_vendor_id_fkey
      foreign key (vendor_id) references public.vendors(id)
      on update cascade
      on delete set null;
  end if;

  if not exists (
    select 1 from pg_constraint where conname = 'product_sync_snapshots_vendor_id_fkey'
  ) then
    alter table public.product_sync_snapshots
      add constraint product_sync_snapshots_vendor_id_fkey
      foreign key (vendor_id) references public.vendors(id)
      on update cascade
      on delete set null;
  end if;
end
$$;

-- 6) Trigger function to keep vendor_id <-> vendor_code aligned during transition.
create or replace function public.sync_vendor_reference_fields()
returns trigger
language plpgsql
as $$
declare
  v_id bigint;
  v_code text;
begin
  if new.vendor_id is not null then
    select id, code
    into v_id, v_code
    from public.vendors
    where id = new.vendor_id
    limit 1;

    if v_id is null then
      raise exception 'invalid vendor_id: %', new.vendor_id;
    end if;

    new.vendor_id := v_id;
    new.vendor_code := v_code;
    return new;
  end if;

  if new.vendor_code is not null and length(trim(new.vendor_code)) > 0 then
    select id, code
    into v_id, v_code
    from public.vendors
    where upper(trim(code)) = upper(trim(new.vendor_code))
    order by id asc
    limit 1;

    if v_id is not null then
      new.vendor_id := v_id;
      new.vendor_code := v_code;
    else
      new.vendor_id := null;
      new.vendor_code := upper(trim(new.vendor_code));
    end if;

    return new;
  end if;

  new.vendor_id := null;
  new.vendor_code := null;
  return new;
end;
$$;

drop trigger if exists trg_products_sync_vendor_reference_fields on public.products;
create trigger trg_products_sync_vendor_reference_fields
before insert or update on public.products
for each row execute function public.sync_vendor_reference_fields();

drop trigger if exists trg_shipments_sync_vendor_reference_fields on public.shipments;
create trigger trg_shipments_sync_vendor_reference_fields
before insert or update on public.shipments
for each row execute function public.sync_vendor_reference_fields();

drop trigger if exists trg_stores_sync_vendor_reference_fields on public.stores;
create trigger trg_stores_sync_vendor_reference_fields
before insert or update on public.stores
for each row execute function public.sync_vendor_reference_fields();

drop trigger if exists trg_product_based_costing_files_sync_vendor_reference_fields on public.product_based_costing_files;
create trigger trg_product_based_costing_files_sync_vendor_reference_fields
before insert or update on public.product_based_costing_files
for each row execute function public.sync_vendor_reference_fields();

drop trigger if exists trg_product_based_costing_items_sync_vendor_reference_fields on public.product_based_costing_items;
create trigger trg_product_based_costing_items_sync_vendor_reference_fields
before insert or update on public.product_based_costing_items
for each row execute function public.sync_vendor_reference_fields();

drop trigger if exists trg_product_brands_sync_vendor_reference_fields on public.product_brands;
create trigger trg_product_brands_sync_vendor_reference_fields
before insert or update on public.product_brands
for each row execute function public.sync_vendor_reference_fields();

drop trigger if exists trg_product_categories_sync_vendor_reference_fields on public.product_categories;
create trigger trg_product_categories_sync_vendor_reference_fields
before insert or update on public.product_categories
for each row execute function public.sync_vendor_reference_fields();

drop trigger if exists trg_product_sync_snapshots_sync_vendor_reference_fields on public.product_sync_snapshots;
create trigger trg_product_sync_snapshots_sync_vendor_reference_fields
before insert or update on public.product_sync_snapshots
for each row execute function public.sync_vendor_reference_fields();

commit;
