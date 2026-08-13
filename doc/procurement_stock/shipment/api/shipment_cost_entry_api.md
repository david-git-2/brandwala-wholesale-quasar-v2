# Shipment Cost Entries API

CRUD for `shipment_cost_entries` — all money inputs (product FX, cargo, and stub types).  
**Replaces:** older `shipment_payments` sketch.  
**Schema:** [schema.md](../schema.md) §1.2

---

## 1. Create / seed entries

* **Endpoint:** `supabase.from('shipment_cost_entries').insert(payload)`

Day-one UX often seeds **one `product` + one `cargo`** when the user opens rates (draft create does **not** require pre-insert — see [create_shipment_draft.md](../rpc/create_shipment_draft.md)).

### Request — current behaviour (single FX + freight total)

```json
[
  {
    "tenant_id": 12,
    "shipment_id": 88,
    "cost_type": "product",
    "amount": 1000.0,
    "currency_id": 1,
    "exchange_rate": 124.5,
    "payment_source": "cash"
  },
  {
    "tenant_id": 12,
    "shipment_id": 88,
    "cost_type": "cargo",
    "amount": 97.5,
    "currency_id": 1,
    "exchange_rate": 1.0,
    "payment_source": "cash",
    "allocation": "by_weight",
    "metadata": { "per_kg_rate": 6.5, "note": "amount = cargo_kg × per_kg_rate" }
  }
]
```

`amount` for cargo is the **freight total**. UI may compute `amount = total_weight_kg × per_kg_rate` before insert/update.

### Request — multi-payment FX (same table)

```json
[
  {
    "shipment_id": 88,
    "cost_type": "product",
    "amount": 700.0,
    "exchange_rate": 124.5,
    "payment_source": "cash"
  },
  {
    "shipment_id": 88,
    "cost_type": "product",
    "amount": 300.0,
    "exchange_rate": 126.0,
    "payment_source": "credit"
  }
]
```

### Response

Array of rows with `id`, timestamps, and echoed fields.

---

## 2. Upsert / update entries

* **Endpoint:** `supabase.from('shipment_cost_entries').upsert(payload)`

```json
[
  {
    "id": 1,
    "shipment_id": 88,
    "cost_type": "product",
    "amount": 1000.0,
    "exchange_rate": 126.0
  },
  {
    "id": 2,
    "shipment_id": 88,
    "cost_type": "cargo",
    "amount": 105.0,
    "exchange_rate": 1.0
  }
]
```

After finalize, **do not** silent-upsert. Use the **cost revision** RPC: recompute + re-stamp `shipment_items.landed_cost_bdt`. Posted invoice snapshots stay frozen; actual P&L joins the new stamp ([schema.md](../schema.md) §4).

---

## 3. Delete entry

* **Endpoint:** `supabase.from('shipment_cost_entries').delete().eq('id', 1)`

Blocked or revision-gated once `inventory_added = true` (product policy).

```json
{ "success": true, "deleted_id": 1 }
```

---

## 4. List by shipment

* **Endpoint:** `supabase.from('shipment_cost_entries').select('*').eq('shipment_id', 88).order('id')`

```json
[
  {
    "id": 1,
    "tenant_id": 12,
    "shipment_id": 88,
    "cost_type": "product",
    "amount": 1000.0,
    "currency_id": 1,
    "exchange_rate": 124.5,
    "payment_source": "cash",
    "entity_type": null,
    "entity_id": null,
    "allocation": null,
    "metadata": null
  },
  {
    "id": 2,
    "tenant_id": 12,
    "shipment_id": 88,
    "cost_type": "cargo",
    "amount": 97.5,
    "currency_id": 1,
    "exchange_rate": 1.0,
    "payment_source": "cash",
    "allocation": "by_weight",
    "metadata": { "per_kg_rate": 6.5 }
  }
]
```

---

## 5. Stub fields (optional on write)

| Field | When to send |
| :--- | :--- |
| `payment_source` | `'cash'` \| `'credit'` \| `'wallet'` — settlement mode for this cost slice |
| `entity_type` / `entity_id` | Payee (`vendor`, cargo agent, …). **Never** `shipment`. Settlement **intent** only day one — no auto wallet post on finalize ([issues §3](../../../PROCUREMENT_STOCK_ISSUES.md)) |
| `allocation` | Non-default spread for duty/labor later |
| `cost_type` beyond product/cargo | When UI enables duty, insurance, etc. |

Live preview and finalize consume these via [shipment_engine.md](../shipment_engine.md). Costing does not require wallet. Wallet ownership / return-for-credit: [PROCUREMENT_STOCK_ISSUES.md](../../../PROCUREMENT_STOCK_ISSUES.md) §3 · [schema.md](../schema.md) §1.2 money handoff. After finalize, mutation goes through cost revision (re-stamp), not silent upsert.
