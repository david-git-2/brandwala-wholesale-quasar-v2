-- Phase 5: drop products.tenant_id and products.tariff_code.
-- Excel/Python sync still sends those fields and will fail until that follow-up.

create or replace function public.set_products_catalog_parent_tenant_id()
returns trigger
language plpgsql
security definer
set search_path to public
as $$
begin
  if new.parent_tenant_id is not null then
    new.parent_tenant_id := public.resolve_parent_tenant_id(new.parent_tenant_id);
  elsif new.inserted_by_tenant_id is not null then
    new.parent_tenant_id := public.resolve_parent_tenant_id(new.inserted_by_tenant_id);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_products_set_tenant_id on public.products;

alter table public.products
  drop constraint if exists products_tenant_id_fkey;

drop index if exists public.products_tenant_id_idx;

alter table public.products
  drop column if exists tenant_id;

alter table public.products
  drop column if exists tariff_code;
