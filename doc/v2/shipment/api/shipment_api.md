# Shipment API Specification

This document details the API operations for the core `shipments` header record.

## 1. Create Shipment (Draft)

* **Endpoint / Query**: `supabase.from('shipments').insert(payload)`

### Request Payload
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

### Response Payload
```json
{
  "id": 88,
  "tenant_id": 12,
  "tenant_shipment_id": 104,
  "name": "UK Apparel Batch #40",
  "status": "draft",
  "shipment_type": "international",
  "vendor_id": 2,
  "cargo_company_id": 5,
  "shipment_purchase_currency_id": 1,
  "shipment_cost_currency_id": 2,
  "inventory_added": false,
  "created_at": "2026-08-01T22:00:00Z"
}
```

---

## 2. Update Shipment Header

* **Endpoint / Query**: `supabase.from('shipments').update(payload).eq('id', 88)`

### Request Payload (Partial Update)
```json
{
  "name": "UK Apparel Batch #40 (Revised)",
  "status": "in_transit",
  "total_weight_kg": 42.50
}
```

### Response Payload
```json
{
  "id": 88,
  "tenant_id": 12,
  "name": "UK Apparel Batch #40 (Revised)",
  "status": "in_transit",
  "total_weight_kg": 42.50,
  "updated_at": "2026-08-01T22:06:00Z"
}
```

---

## 3. Delete Shipment

* **Endpoint / Query**: `supabase.from('shipments').delete().eq('id', 88)`

### Request
* Parameter: `id = 88`

### Response Payload
```json
{
  "success": true,
  "deleted_id": 88
}
```

### Cascade & Impact Rules:
* **Child Tables (`CASCADE`)**: `shipment_payments`, `shipment_items`, and `shipment_boxes` are deleted automatically on database cascade.
* **Inventory Constraint**: Deletion is blocked if `inventory_added = true` (`received` status).

---

## 4. List / Query Shipments

* **Endpoint / Query**: `supabase.from('shipments').select('*, shipment_items(*), shipment_payments(*), shipment_boxes(*)')`

### Query Parameters / Filters
* `status`: Filter by shipment status (e.g. `draft`, `in_transit`, `received`)
* `vendor_id`: Filter by vendor
* `cargo_company_id`: Filter by cargo company
* `tenant_id`: Scope to tenant

### Request Example
```typescript
const { data, error } = await supabase
  .from('shipments')
  .select(`
    *,
    shipment_items(*),
    shipment_payments(*),
    shipment_boxes(*)
  `)
  .eq('tenant_id', 12)
  .order('created_at', { ascending: false });
```

### Response Payload
```json
[
  {
    "id": 88,
    "tenant_id": 12,
    "tenant_shipment_id": 104,
    "name": "UK Apparel Batch #40",
    "status": "draft",
    "shipment_type": "international",
    "vendor_id": 2,
    "cargo_company_id": 5,
    "shipment_purchase_currency_id": 1,
    "shipment_cost_currency_id": 2,
    "inventory_added": false,
    "created_at": "2026-08-01T22:00:00Z",
    "updated_at": "2026-08-01T22:06:00Z",
    "shipment_items": [],
    "shipment_payments": [],
    "shipment_boxes": []
  }
]
```
