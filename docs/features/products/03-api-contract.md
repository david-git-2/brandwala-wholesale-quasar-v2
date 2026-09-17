# Products & Tag Catalog — API Contract & RPC Signatures

> **RPC Functions Target**: Product Search, Bulk Batch Creation & Universal Tag Queries  
> **Security Level**: `SECURITY DEFINER`

---

## 1. Catalog Listing RPC: `list_products_paginated`

Returns master products with brand details, category names, list pricing, and total count.

### Signature
```sql
create or replace function public.list_products_paginated(
  p_tenant_id uuid,
  p_search text default null,
  p_brand_id uuid default null,
  p_category_id uuid default null,
  p_limit int default 50,
  p_offset int default 0
)
returns table (
  id uuid,
  name text,
  product_code text,
  barcode text,
  brand_name text,
  category_name text,
  list_price_amount numeric,
  list_price_currency text,
  unit_weight_kg numeric,
  image_url text,
  is_active boolean,
  total_count bigint
)
language plpgsql security definer;
```

---

## 2. Universal Tag Queries

### 2.1 List Tag Categories: `list_tag_categories`
```sql
create or replace function public.list_tag_categories(
  p_module_key text default null
)
returns table (
  id uuid,
  name text,
  code text,
  module_key text,
  is_system boolean
)
language plpgsql security definer;
```

### 2.2 List Tags in Category: `list_tags_for_category`
```sql
create or replace function public.list_tags_for_category(
  p_module_key text default null,
  p_code text default null
)
returns table (
  id uuid,
  name text,
  slug text,
  color text,
  metadata jsonb
)
language plpgsql security definer;
```
