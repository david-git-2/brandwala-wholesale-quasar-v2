# Shipment Payments API Specification

This document details the API operations for `shipment_payments`.

## 1. Create Payment / Initialize Payment Record

* **Endpoint / Query**: `supabase.from('shipment_payments').insert(payload)`

### Request Payload
```json
{
  "shipment_id": 88,
  "payment_target": "product",
  "payment_source": "cash",
  "purchase_amount": 1250.00,
  "exchange_rate": 168.50
}
```

### Response Payload
```json
{
  "id": 1,
  "shipment_id": 88,
  "payment_target": "product",
  "payment_source": "cash",
  "purchase_amount": 1250.00,
  "exchange_rate": 168.50,
  "created_at": "2026-08-01T22:00:00Z"
}
```

---

## 2. Update / Upsert Shipment Payments & Exchange Rates

* **Endpoint / Query**: `supabase.from('shipment_payments').upsert(payload)`

### Request Payload
```json
[
  {
    "id": 1,
    "shipment_id": 88,
    "exchange_rate": 170.00,
    "purchase_amount": 1300.00
  },
  {
    "id": 2,
    "shipment_id": 88,
    "payment_target": "cargo",
    "payment_source": "wallet",
    "purchase_amount": 150.00,
    "exchange_rate": 1.00
  }
]
```

### Response Payload
```json
[
  {
    "id": 1,
    "shipment_id": 88,
    "payment_target": "product",
    "payment_source": "cash",
    "purchase_amount": 1300.00,
    "exchange_rate": 170.00
  },
  {
    "id": 2,
    "shipment_id": 88,
    "payment_target": "cargo",
    "payment_source": "wallet",
    "purchase_amount": 150.00,
    "exchange_rate": 1.00
  }
]
```

---

## 3. Delete Shipment Payment

* **Endpoint / Query**: `supabase.from('shipment_payments').delete().eq('id', 1)`

### Request
* Parameter: `id = 1`

### Response Payload
```json
{
  "success": true,
  "deleted_id": 1
}
```

---

## 4. List / Query Payments by Shipment

* **Endpoint / Query**: `supabase.from('shipment_payments').select('*').eq('shipment_id', 88)`

### Response Payload
```json
[
  {
    "id": 1,
    "shipment_id": 88,
    "payment_target": "product",
    "payment_source": "cash",
    "purchase_amount": 1300.00,
    "exchange_rate": 170.00
  },
  {
    "id": 2,
    "shipment_id": 88,
    "payment_target": "cargo",
    "payment_source": "wallet",
    "purchase_amount": 150.00,
    "exchange_rate": 1.00
  }
]
```
