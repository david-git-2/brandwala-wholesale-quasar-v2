# RPC: assign shipment to child (was `bulk_allocate_shipment_stock`)

**Target behavior:** Assign a Ready Stock **shipment** to one child tenant so that child’s shop may **list** the batch. Does not move warehouse ownership and does **not** write soft qty slices.

**Design lock:** [../schema.md](../schema.md).

**Live today:** `bulk_allocate_shipment_stock` still dumps remaining sellable stock qty into `global_stock_allocations`. Treat that as legacy until cutover.

---

## 1. Target behavior

* Set `shipments.assigned_child_tenant_id = p_child_tenant_id` (or upsert `shipment_assignments`).
* Verify child belongs to parent (or child = parent for standalone).
* Shipment must be Ready / `received` with stock posted.
* **No** allocation qty rows required for sell truth — shop ATP reads `global_stocks` for this `shipment_id`.

---

## 2. Example (target)

```typescript
const { data, error } = await supabase.rpc('assign_shipment_to_child', {
  p_parent_tenant_id: 12,
  p_child_tenant_id: 5,
  p_shipment_id: 88
});
```

---

## 3. Parameters

| Parameter | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `p_parent_tenant_id` | BIGINT | Yes | Stock owner |
| `p_child_tenant_id` | BIGINT | Yes | Shop tenant that may list this shipment |
| `p_shipment_id` | BIGINT | Yes | Batch to assign |

### Return
* Assigned shipment id / row count.

---

## 4. Legacy note

Until rename/cutover, docs may still mention `bulk_allocate_shipment_stock` — implementers should follow §1 target, not soft-qty upsert.
