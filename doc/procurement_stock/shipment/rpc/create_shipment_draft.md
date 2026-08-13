# RPC: `create_shipment_draft`

Initializes a **draft shipment header only**. Cost entries are **not** required at create — add via [shipment_cost_entry_api.md](../api/shipment_cost_entry_api.md) when entering rates (typically one `product` + one `cargo` for current behaviour).

**Defaults (parent / stock-owning tenant):**
* `p_vendor_id` null → `ensure_default_vendor` ([../../vendor/workflow_flow.md](../../vendor/workflow_flow.md))
* `p_cargo_company_id` null → `ensure_default_cargo_company` ([../../cargo_company/workflow_flow.md](../../cargo_company/workflow_flow.md))

---

## 1. APIs Called (Internal)

* [shipment_api.md](../api/shipment_api.md) — `shipments` insert
* `ensure_default_vendor` / `ensure_default_cargo_company` when ids omitted

---

## 2. Main RPC Payload

```typescript
supabase.rpc('create_shipment_draft', {
  p_parent_tenant_id: 12,
  p_name: 'UK Apparel Batch #40',
  p_type: 'international',
  p_vendor_id: 2,           // optional — defaults to tenant DEFAULT vendor
  p_cargo_company_id: 5,    // optional — defaults to tenant DEFAULT cargo company
});
```

---

## 3. Internal payload (`global_shipments`)

```json
{
  "parent_tenant_id": 12,
  "name": "UK Apparel Batch #40",
  "type": "international",
  "vendor_id": 2,
  "cargo_company_id": 5,
  "status": "Draft",
  "received_weight": null,
  "stock_ready": false
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
