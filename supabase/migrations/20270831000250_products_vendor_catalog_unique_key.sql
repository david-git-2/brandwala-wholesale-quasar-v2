-- Prevent duplicate vendor catalog rows when the full natural key is present.
-- Incomplete rows (null/empty barcode or product_code) stay outside the index.

create unique index if not exists uq_products_vendor_catalog_full_key
  on public.products (parent_tenant_id, vendor_id, market_code, barcode, product_code)
  where vendor_id is not null
    and parent_tenant_id is not null
    and market_code is not null
    and btrim(coalesce(barcode, '')) <> ''
    and btrim(coalesce(product_code, '')) <> '';
