# RPC: `list_global_shipment_cost_entries`

List cost entries for a shipment.

```typescript
const { data, error } = await supabase.rpc('list_global_shipment_cost_entries', {
  p_shipment_id: 881,
});
```

---

# RPC: `upsert_global_shipment_cost_entry`

Insert or update one cost entry. **Blocked** when `stock_ready` / Ready Stock — use `revise_global_shipment_costs`.

```typescript
const { data, error } = await supabase.rpc('upsert_global_shipment_cost_entry', {
  p_shipment_id: 881,
  p_cost_type: 'product',
  p_amount: 1000,
  p_exchange_rate: 124.5,
  p_id: null, // set to update existing
});
```

---

# RPC: `delete_global_shipment_cost_entry`

Delete one entry (pre-finalize only).

```typescript
await supabase.rpc('delete_global_shipment_cost_entry', { p_id: 12 });
```
