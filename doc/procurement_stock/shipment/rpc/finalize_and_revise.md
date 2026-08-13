# RPC: `finalize_global_shipment`

Stamp `landed_cost_bdt` from cost entries (server-side). Optional stock post. **No wallet posts.**

```typescript
const { data, error } = await supabase.rpc('finalize_global_shipment', {
  p_shipment_id: 881,
  p_stock_rows: [
    {
      shipment_item_id: 501,
      stock_type_id: 1,
      quantity: 10,
      is_usable: true,
    },
  ],
});
// { shipment_id, items_stamped, stock_rows_posted, stock_ready, wallet_posted: false }
```

Omit `p_stock_rows` to stamp only (does not set Ready Stock). With rows: upserts `global_stocks` and sets `status = Ready Stock`, `stock_ready = true`.

Already finalized → error; use `revise_global_shipment_costs`.

---

# RPC: `revise_global_shipment_costs`

Replace cost entries and re-stamp. No wallet. Does not rewrite invoice snapshots.

```typescript
const { data, error } = await supabase.rpc('revise_global_shipment_costs', {
  p_shipment_id: 881,
  p_entries: [
    { cost_type: 'product', amount: 1000, exchange_rate: 172 },
    { cost_type: 'cargo', amount: 97.5, exchange_rate: 1 },
  ],
});
```
