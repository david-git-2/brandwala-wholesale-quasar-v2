# Global Stock & Item Splits API Specification

This document details the API operations for managing shipment item stock splits in `global_stocks`.

---

## 1. List Stock Splits by Shipment / Item

* **Endpoint / Query**: `supabase.from('global_stocks').select('*, global_stock_types(*)').in('shipment_item_id', itemIds)`

### Request Example
```typescript
const { data, error } = await supabase
  .from('global_stocks')
  .select('*, global_stock_types(*)')
  .in('shipment_item_id', [501, 502]);
```

### Response Payload
```json
[
  {
    "id": 1001,
    "parent_tenant_id": 12,
    "shipment_item_id": 501,
    "stock_type_id": 1,
    "quantity": 20,
    "is_usable": true,
    "created_at": "2026-08-02T10:00:00Z",
    "updated_at": "2026-08-02T10:00:00Z",
    "global_stock_types": {
      "id": 1,
      "description": "Standard Sellable",
      "is_sellable": true
    }
  },
  {
    "id": 1002,
    "parent_tenant_id": 12,
    "shipment_item_id": 501,
    "stock_type_id": 2,
    "quantity": 5,
    "is_usable": false,
    "created_at": "2026-08-02T10:00:00Z",
    "updated_at": "2026-08-02T10:00:00Z",
    "global_stock_types": {
      "id": 2,
      "description": "Damaged",
      "is_sellable": false
    }
  }
]
```

---

## 2. Insert / Upsert Stock Splits for Item

* **Endpoint / Query**: `supabase.from('global_stocks').upsert(payload)`

### Request Payload
```json
[
  {
    "parent_tenant_id": 12,
    "shipment_item_id": 501,
    "stock_type_id": 1,
    "quantity": 25,
    "is_usable": true
  }
]
```

---

## 3. Auto Accept Splits (Bulk Replacement)

* **Operation**: For items that do not have 100% of their ordered quantity allocated into stock splits, existing incomplete split records are cleared for those items and replaced with 100% quantity allocated to the `"Standard Sellable"` stock type.

### Execution Steps:
1. **Delete incomplete split rows**:
   ```typescript
   await supabase
     .from('global_stocks')
     .delete()
     .in('shipment_item_id', pendingItemIds);
   ```

2. **Bulk insert full default split rows**:
   ```typescript
   await supabase
     .from('global_stocks')
     .insert(
       pendingItems.map((item) => ({
         parent_tenant_id: tenantId,
         shipment_item_id: item.id,
         stock_type_id: defaultStockTypeId,
         quantity: item.ordered_quantity,
         is_usable: true,
       }))
     );
   ```

---

## 4. Delete Stock Split

* **Endpoint / Query**: `supabase.from('global_stocks').delete().eq('id', 1002)`
* **Bulk Delete by Shipment Item**:
  ```typescript
  await supabase
    .from('global_stocks')
    .delete()
    .in('shipment_item_id', itemIds);
  ```
