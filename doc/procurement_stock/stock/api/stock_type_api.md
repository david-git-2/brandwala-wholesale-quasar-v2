# Stock Types API Specification

This document details the API operations for managing stock pool classification types in `global_stock_types`.

---

## 1. List Stock Types

* **Endpoint / Query**: `supabase.from('global_stock_types').select('*').order('sort_order', { ascending: true })`

### Request Example
```typescript
const { data, error } = await supabase
  .from('global_stock_types')
  .select('*')
  .or(`parent_tenant_id.eq.${tenantId},parent_tenant_id.is.null`)
  .order('sort_order', { ascending: true });
```

### Response Payload
```json
[
  {
    "id": 1,
    "parent_tenant_id": null,
    "description": "Standard Sellable",
    "is_sellable": true,
    "sort_order": 1,
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:00:00Z"
  },
  {
    "id": 2,
    "parent_tenant_id": null,
    "description": "Damaged",
    "is_sellable": false,
    "sort_order": 2,
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:00:00Z"
  }
]
```

---

## 2. Create Stock Type

* **Endpoint / Query**: `supabase.from('global_stock_types').insert(payload)`

### Request Payload
```json
{
  "parent_tenant_id": 12,
  "description": "Display Sample",
  "is_sellable": false,
  "sort_order": 3
}
```

### Response Payload
```json
{
  "id": 5,
  "parent_tenant_id": 12,
  "description": "Display Sample",
  "is_sellable": false,
  "sort_order": 3,
  "created_at": "2026-08-02T10:00:00Z",
  "updated_at": "2026-08-02T10:00:00Z"
}
```

---

## 3. Update Stock Type

* **Endpoint / Query**: `supabase.from('global_stock_types').update(payload).eq('id', 5)`

### Request Payload (Partial Update)
```json
{
  "description": "Showroom Sample",
  "is_sellable": false
}
```

---

## 4. Delete Stock Type

* **Endpoint / Query**: `supabase.from('global_stock_types').delete().eq('id', 5)`
