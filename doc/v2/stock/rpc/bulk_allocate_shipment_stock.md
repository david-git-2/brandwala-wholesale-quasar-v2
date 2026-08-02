# RPC: `bulk_allocate_shipment_stock`

Allocates shipment stock from a parent tenant to a child/shop tenant in bulk across all stock entries associated with a shipment.

---

## 1. Description & Behavior

* **Function Name**: `bulk_allocate_shipment_stock`
* **Purpose**: Performs batch allocation of `global_stocks` into `global_stock_allocations` for a specific child tenant when a shipment arrives or stock distribution is triggered.
* **Internal Operations**:
  * Finds all `global_stocks` associated with the items in `p_shipment_id`.
  * Inserts or updates corresponding rows in `global_stock_allocations` matching `p_child_tenant_id` and `p_parent_tenant_id`.

---

## 2. RPC Execution Example

```typescript
const { data, error } = await supabase.rpc('bulk_allocate_shipment_stock', {
  p_parent_tenant_id: 12,
  p_child_tenant_id: 5,
  p_shipment_id: 88
});
```

---

## 3. Parameters & Return Type

| Parameter | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `p_parent_tenant_id` | BIGINT | Yes | Source parent tenant ID |
| `p_child_tenant_id` | BIGINT | Yes | Destination child/shop tenant ID |
| `p_shipment_id` | BIGINT | Yes | Target shipment ID |

### Return Value
* Returns `INT` representing total allocated row count or total quantity processed.
