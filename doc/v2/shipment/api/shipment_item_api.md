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

## 2. Update / Bulk Upsert Shipment Items

* **Endpoint / Query**: `supabase.from('shipment_items').upsert(payload)`

### Request Payload (Partial / Update)
```json
[
  {
    "id": 501,
    "shipment_id": 88,
    "quantity": 25,
    "unit_purchase_price": 12.50,
    "product_weight_gm": 260.00
  },
  {
    "id": 502,
    "shipment_id": 88,
    "unit_purchase_price": 7.50
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
    "product_weight_gm": 260.00
  },
  {
    "id": 502,
    "shipment_id": 88,
    "quantity": 50,
    "unit_purchase_price": 7.50,
    "product_weight_gm": 180.00
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
    "package_weight_gm": 10.0
  }
]
```
