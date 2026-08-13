# RPC: `create_shipment_draft`

Initializes a **draft shipment header only**. Cost entries are **not** required at create — add via [shipment_cost_entry_api.md](../api/shipment_cost_entry_api.md) when entering rates (typically one `product` + one `cargo` for current behaviour).

---

## 1. APIs Called (Internal)

* [shipment_api.md](../api/shipment_api.md) — `shipments` insert

---

## 2. Main RPC Payload

```typescript
supabase.rpc('create_shipment_draft', {
  p_tenant_id: 12,
  p_tenant_shipment_id: 104,
  p_name: 'UK Apparel Batch #40',
  p_shipment_type: 'international',
  p_vendor_id: 2,
  p_cargo_company_id: 5,
});
```

---

## 3. Internal payload (`shipments`)

```json
{
  "tenant_id": 12,
  "tenant_shipment_id": 104,
  "name": "UK Apparel Batch #40",
  "shipment_type": "international",
  "vendor_id": 2,
  "cargo_company_id": 5,
  "status": "draft",
  "total_weight_kg": null,
  "inventory_added": false
}
```

### Optional (product policy)

If UX wants empty rate rows immediately, the RPC **may** also insert:

```json
[
  { "cost_type": "product", "amount": 0, "exchange_rate": 1.0 },
  { "cost_type": "cargo", "amount": 0, "exchange_rate": 1.0 }
]
```

Default sketch: **header only** — matches [workflow_flow.md](../workflow_flow.md) Stage 1.
