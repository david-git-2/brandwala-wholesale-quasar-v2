# RPC: `create_shipment_draft`

Initializes a draft shipment header and auto-creates default payment target records (`product` and `cargo`).

---

## 1. APIs Called (Internal Table Operations)

* [shipment_api.md](../api/shipment_api.md) — `shipments` insert
* [shipment_payment_api.md](../api/shipment_payment_api.md) — `shipment_payments` bulk insert

---

## 2. Main RPC Payload

```typescript
supabase.rpc('create_shipment_draft', {
  p_tenant_id: 12,
  p_tenant_shipment_id: 104,
  p_name: "UK Apparel Batch #40",
  p_shipment_type: "international",
  p_vendor_id: 2,
  p_cargo_company_id: 5,
  p_shipment_purchase_currency_id: 1,
  p_shipment_cost_currency_id: 2
});
```

---

## 3. Internal API Payloads Executed

### A. Shipment Header Payload (`shipments`)
```json
{
  "tenant_id": 12,
  "tenant_shipment_id": 104,
  "name": "UK Apparel Batch #40",
  "shipment_type": "international",
  "vendor_id": 2,
  "cargo_company_id": 5,
  "shipment_purchase_currency_id": 1,
  "shipment_cost_currency_id": 2
}
```

### B. Shipment Payments Payload (`shipment_payments`)
```json
[
  {
    "payment_target": "product",
    "payment_source": "cash",
    "purchase_amount": 0,
    "exchange_rate": 1.00
  },
  {
    "payment_target": "cargo",
    "payment_source": "cash",
    "purchase_amount": 0,
    "exchange_rate": 1.00
  }
]
```

