# Stock Allocation API Specification

This document details the API operations for managing tenant/shop stock allocations in `global_stock_allocations`.

---

## 1. List Stock Allocations by Tenant / Stock ID

* **Endpoint / Query**: `supabase.from('global_stock_allocations').select('*').eq('parent_tenant_id', 12)`

### Request Example
```typescript
const { data, error } = await supabase
  .from('global_stock_allocations')
  .select('*')
  .eq('parent_tenant_id', 12)
  .eq('child_tenant_id', 5);
```

### Response Payload
```json
[
  {
    "id": 201,
    "parent_tenant_id": 12,
    "child_tenant_id": 5,
    "stock_id": 1001,
    "quantity": 10,
    "created_at": "2026-08-02T10:00:00Z",
    "updated_at": "2026-08-02T10:00:00Z"
  }
]
```

---

## 2. Upsert / Create Stock Allocation

* **Endpoint / Query**: `supabase.from('global_stock_allocations').upsert(payload)`

### Request Payload
```json
{
  "parent_tenant_id": 12,
  "child_tenant_id": 5,
  "stock_id": 1001,
  "quantity": 15
}
```

---

## 3. Delete Stock Allocation

* **Endpoint / Query**: `supabase.from('global_stock_allocations').delete().eq('id', 201)`
