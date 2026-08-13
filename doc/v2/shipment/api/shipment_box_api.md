# Shipment Box API Specification

Physical box weights for **verification / audit only**.  
They do **not** set `shipments.total_weight_kg`, do **not** drive weight-balance apply, and do **not** enter cargo costing. See [schema.md](../schema.md) §1.4 · §2.

## 1. Create / Add Box

* **Endpoint / Query**: `supabase.from('shipment_boxes').insert(payload)`

### Request Payload
```json
{
  "shipment_id": 88,
  "box_number": "BOX-01",
  "weight_kg": 15.50,
  "dimensions": "40x30x20 cm",
  "notes": "Fragile items included"
}
```

### Response Payload
```json
{
  "id": 10,
  "shipment_id": 88,
  "box_number": "BOX-01",
  "weight_kg": 15.50,
  "dimensions": "40x30x20 cm",
  "notes": "Fragile items included",
  "created_at": "2026-08-01T22:10:00Z"
}
```

---

## 2. Update / Upsert Shipment Box

* **Endpoint / Query**: `supabase.from('shipment_boxes').update(payload).eq('id', 10)`

### Request Payload
```json
{
  "weight_kg": 16.00,
  "notes": "Repacked & verified"
}
```

### Response Payload
```json
{
  "id": 10,
  "shipment_id": 88,
  "box_number": "BOX-01",
  "weight_kg": 16.00,
  "dimensions": "40x30x20 cm",
  "notes": "Repacked & verified",
  "updated_at": "2026-08-01T22:12:00Z"
}
```

---

## 3. Delete Shipment Box

* **Endpoint / Query**: `supabase.from('shipment_boxes').delete().eq('id', 10)`

### Request
* Parameter: `id = 10`

### Response Payload
```json
{
  "success": true,
  "deleted_id": 10
}
```

---

## 4. List / Query Boxes by Shipment

* **Endpoint / Query**: `supabase.from('shipment_boxes').select('*').eq('shipment_id', 88)`

### Response Payload
```json
[
  {
    "id": 10,
    "shipment_id": 88,
    "box_number": "BOX-01",
    "weight_kg": 16.00,
    "dimensions": "40x30x20 cm",
    "notes": "Repacked & verified"
  }
]
```
