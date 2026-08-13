# Shipment Items API Specification

This document details the API operations for `shipment_items`.

## 1. Add Items (Single or Bulk)

* **Endpoint / Query**: `supabase.from('shipment_items').insert(payload)`
* **Unified API Design**: Accepts a JSON array payload `[...]` for both single item insertion (array of 1 element) and bulk item insertion (array of N elements).

### Request Payload (Supports Single `[ { ... } ]` or Bulk `[ { ... }, { ... } ]`)
```json
[
  {
    "shipment_id": 88,
    "product_id": 105,
    "quantity": 20,
    "unit_purchase_price": 12.50,
    "product_weight_gm": 250,
    "package_weight_gm": 10
  },
  {
    "shipment_id": 88,
    "product_id": 106,
    "quantity": 50,
    "unit_purchase_price": 8.00,
    "product_weight_gm": 180,
    "package_weight_gm": 10
  }
]
```

### Response Payload
```json
[
  {
    "id": 501,
    "shipment_id": 88,
    "product_id": 105,
    "quantity": 20,
    "unit_purchase_price": 12.50,
    "product_weight_gm": 250.0,
    "package_weight_gm": 10.0,
    "created_at": "2026-08-01T22:05:00Z"
  },
  {
    "id": 502,
    "shipment_id": 88,
    "product_id": 106,
    "quantity": 50,
    "unit_purchase_price": 8.00,
    "product_weight_gm": 180.0,
    "package_weight_gm": 10.0,
    "created_at": "2026-08-01T22:05:00Z"
  }
]
```

---

## 2. Update / Bulk Upsert Shipment Items (Bulk Price & Weight Balancing)

* **Endpoint / Query**: `supabase.from('shipment_items').upsert(payload)`
* **Use Cases**:
  * **Bulk Price Update**: Batch update `unit_purchase_price` when vendor invoice is finalized.
  * **Bulk Weight Balancing**: Adjust `package_weight_gm` so Σ line gross weight matches header **`total_weight_kg`** (cargo invoice weight). Do **not** change `product_weight_gm` unless product policy says otherwise; do **not** write invoice weight onto boxes. Engine: [shipment_engine.md](../shipment_engine.md) §5.

### Request Payload (Batch Partial Update / Price & Weight Balance)
```json
[
  {
    "id": 501,
    "shipment_id": 88,
    "unit_purchase_price": 12.50,
    "product_weight_gm": 260.00,
    "package_weight_gm": 15.00
  },
  {
    "id": 502,
    "shipment_id": 88,
    "unit_purchase_price": 7.50,
    "product_weight_gm": 180.00,
    "package_weight_gm": 12.00
  }
]
```

### Response Payload
```json
[
  {
    "id": 501,
    "shipment_id": 88,
    "quantity": 25,
    "unit_purchase_price": 12.50,
    "product_weight_gm": 260.00,
    "package_weight_gm": 15.00
  },
  {
    "id": 502,
    "shipment_id": 88,
    "quantity": 50,
    "unit_purchase_price": 7.50,
    "product_weight_gm": 180.00,
    "package_weight_gm": 12.00
  }
]
```

---

## 3. Delete Shipment Item

* **Endpoint / Query**: `supabase.from('shipment_items').delete().eq('id', 501)`

### Request
* Parameter: `id = 501`

### Response Payload
```json
{
  "success": true,
  "deleted_id": 501
}
```

---

## 4. List / Query Items by Shipment

* **Endpoint / Query**: `supabase.from('shipment_items').select('*').eq('shipment_id', 88)`

### Response Payload
```json
[
  {
    "id": 501,
    "shipment_id": 88,
    "product_id": 105,
    "quantity": 25,
    "unit_purchase_price": 12.50,
    "product_weight_gm": 260.0,
    "package_weight_gm": 10.0,
    "landed_cost_bdt": 2400.0
  }
]
```

`landed_cost_bdt` is **null** until finalize / cost revision. Clients must **not** write this column — server stamp only ([schema.md](../schema.md) §4, [workflow_flow.md](../workflow_flow.md) Stages 3–4).
