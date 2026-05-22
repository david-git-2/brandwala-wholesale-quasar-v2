begin;

-- vendor_code FKs depend on global unique vendors.code; drop them first.
alter table public.products
  drop constraint if exists products_vendor_code_fkey;

alter table public.product_based_costing_files
  drop constraint if exists product_based_costing_files_vendor_code_fkey;

alter table public.shipments
  drop constraint if exists shipments_vendor_code_fkey;

-- Ensure vendor_id FKs exist (backward-safe).
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'products_vendor_id_fkey') then
    alter table public.products
      add constraint products_vendor_id_fkey
      foreign key (vendor_id) references public.vendors(id)
      on update cascade
      on delete set null;
  end if;

  if not exists (select 1 from pg_constraint where conname = 'product_based_costing_files_vendor_id_fkey') then
    alter table public.product_based_costing_files
      add constraint product_based_costing_files_vendor_id_fkey
      foreign key (vendor_id) references public.vendors(id)
      on update cascade
      on delete set null;
  end if;

  if not exists (select 1 from pg_constraint where conname = 'shipments_vendor_id_fkey') then
    alter table public.shipments
      add constraint shipments_vendor_id_fkey
      foreign key (vendor_id) references public.vendors(id)
      on update cascade
      on delete set null;
  end if;
end
$$;

-- Remove legacy global unique constraint on vendor code.
alter table public.vendors
  drop constraint if exists vendors_code_key;

-- Enforce uniqueness per tenant for tenant-owned vendors.
create unique index if not exists vendors_tenant_code_unique_idx
  on public.vendors (tenant_id, upper(trim(code)))
  where tenant_id is not null;

-- Keep global (tenant_id is null) vendor codes unique among themselves (optional).
create unique index if not exists vendors_global_code_unique_idx
  on public.vendors (upper(trim(code)))
  where tenant_id is null;

commit;
