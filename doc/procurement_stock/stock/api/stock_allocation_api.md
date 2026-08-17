# Shipment → child assign / listing permission API

**Target:** Permission for a child shop to list a parent shipment batch. **Not** a qty allocation ledger.

**Design lock:** [../schema.md](../schema.md) · [../schema.md](../schema.md) §0 / §2.2.

**Consumers:** stock-backed shop / dropship listings. Display = real ATP from shipment stock **or** dummy override. Checkout deducts parent `global_stocks`.

**Live:** `global_stock_allocations` qty CRUD still exists — migrate away; do not add new soft-qty features.

---

## 1. Assign shipment to child

Prefer header field or small assign table (see schema §2.2).

```typescript
// Option A — header
await supabase
  .from('shipments')
  .update({ assigned_child_tenant_id: 5 })
  .eq('id', 88)
  .eq('tenant_id', 12);
```

---

## 2. List shipments assigned to a child

```typescript
const { data, error } = await supabase
  .from('shipments')
  .select('id, name, vendor_id, status, assigned_child_tenant_id')
  .eq('assigned_child_tenant_id', 5);
```

Shop then loads `global_stocks` for those `shipment_id`s for **real** qty.

---

## 3. Clear assign

```typescript
await supabase
  .from('shipments')
  .update({ assigned_child_tenant_id: null })
  .eq('id', 88);
```

---

## 4. Legacy allocation qty API

Direct upsert/delete on `global_stock_allocations.quantity` is **legacy**. Do not use for new shop ATP design.
