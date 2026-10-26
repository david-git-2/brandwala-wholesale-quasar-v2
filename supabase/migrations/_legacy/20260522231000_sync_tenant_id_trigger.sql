-- =========================================================
-- Trigger to automatically sync tenant_id from vendor_id
-- =========================================================

begin;

create or replace function public.sync_lookup_tenant_id()
returns trigger
language plpgsql
as $$
declare
  v_tenant_id bigint;
begin
  if new.vendor_id is not null then
    select tenant_id into v_tenant_id
    from public.vendors
    where id = new.vendor_id;
    
    if v_tenant_id is not null then
      new.tenant_id := v_tenant_id;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_product_brands_sync_tenant_id on public.product_brands;
create trigger trg_product_brands_sync_tenant_id
before insert or update of vendor_id on public.product_brands
for each row execute function public.sync_lookup_tenant_id();

drop trigger if exists trg_product_categories_sync_tenant_id on public.product_categories;
create trigger trg_product_categories_sync_tenant_id
before insert or update of vendor_id on public.product_categories
for each row execute function public.sync_lookup_tenant_id();

commit;
