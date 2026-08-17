-- Catalog shops may be created without a vendor. Vendor is required only when the shop is public.

update public.shops
set is_active = false
where shop_type = 'vendor_catalog'
  and is_active = true
  and vendor_code is null
  and (vendor_filters is null or jsonb_array_length(vendor_filters) = 0);

alter table public.shops drop constraint if exists shops_vendor_catalog_requires_vendor_code;

alter table public.shops add constraint shops_vendor_catalog_requires_vendor_code check (
  shop_type <> 'vendor_catalog'
  or is_active = false
  or vendor_code is not null
  or (vendor_filters is not null and jsonb_array_length(vendor_filters) > 0)
);
