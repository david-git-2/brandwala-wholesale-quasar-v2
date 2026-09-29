# Products & Tag Catalog — API Contract & RPC Signatures

> **RPC Functions Target**: Product Search, Bulk Batch Creation & Universal Tag Queries  
> **Security Level**: `SECURITY DEFINER`

---

## 1. Catalog Listing RPC: `list_products_paginated`

Keyset list of master products (sort by `name`, then `id`). No total count.

### Signature
```sql
list_products_paginated(
  p_tenant_id bigint default null,
  p_search text default null,
  p_search_field text default 'name',
  p_category text default null,
  p_brand text default null,
  p_vendor_code text default null,
  p_market_code text default null,
  p_is_available boolean default null,
  p_sort_dir text default 'asc',
  p_limit integer default 20,
  p_cursor_name text default null,
  p_cursor_id bigint default null
) returns jsonb
```

### Response
```json
{
  "data": [ /* product rows */ ],
  "meta": {
    "has_more": true,
    "next_cursor": { "name": "Widget", "id": 123 },
    "limit": 20
  }
}
```

Pass `p_cursor_name` and `p_cursor_id` from the previous page’s `next_cursor` for the next page.

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
