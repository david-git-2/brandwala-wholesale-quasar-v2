# Shipment API Specification

Core `shipments` header — ops / identity only. **No rate fields.** Money → [shipment_cost_entry_api.md](./shipment_cost_entry_api.md).  
**Schema:** [schema.md](../schema.md) §1.1

---

## 1. Create Shipment (Draft)

* **Endpoint:** `supabase.from('shipments').insert(payload)`  
* Prefer RPC: [create_shipment_draft.md](../rpc/create_shipment_draft.md) (header only; no cost entries required)
* Omit `vendor_id` / `cargo_company_id` to use tenant **defaults** ([../../vendor/](../../vendor/) · [../../cargo_company/](../../cargo_company/))

### Request Payload

```json
{
  "tenant_id": 12,
  "tenant_shipment_id": 104,
  "name": "UK Apparel Batch #40",
  "shipment_type": "international",
  "vendor_id": 2,
  "cargo_company_id": 5
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
  "total_weight_kg": null,
  "inventory_added": false,
  "created_at": "2026-08-01T22:00:00Z"
}
```

---

## 2. Update Shipment Header

* **Endpoint:** `supabase.from('shipments').update(payload).eq('id', 88)`

### Request — cargo invoice weight (explicit save)

```json
{
  "name": "UK Apparel Batch #40 (Revised)",
  "status": "in_transit",
  "total_weight_kg": 42.5
}
```

`total_weight_kg` = cargo **invoice** weight (live `received_weight`). Weight-balance **apply** must not overwrite this field.

### Response

```json
{
  "id": 88,
  "tenant_id": 12,
  "name": "UK Apparel Batch #40 (Revised)",
  "status": "in_transit",
  "total_weight_kg": 42.5,
  "updated_at": "2026-08-01T22:06:00Z"
}
```

---

## 3. Delete Shipment

* **Endpoint:** `supabase.from('shipments').delete().eq('id', 88)`

### Cascade

* **CASCADE:** `shipment_cost_entries`, `shipment_items`, `shipment_boxes`
* **Blocked** if `inventory_added = true` (`received` / stock posted)

```json
{ "success": true, "deleted_id": 88 }
```

---

## 4. List / Query Shipments

```typescript
const { data, error } = await supabase
  .from('shipments')
  .select(`
    *,
    shipment_items(*),
    shipment_cost_entries(*),
    shipment_boxes(*)
  `)
  .eq('tenant_id', 12)
  .order('created_at', { ascending: false });
```

### Filters

* Columns: `status`, `vendor_id`, `cargo_company_id`, `tenant_id`, `shipment_type`
* Progress flow: filter by `progress_flow_id` when you need one named customer journey only
* Progress stage: filter by `progress_tag_id` (current stage inside the selected flow) — see [../schema.md](../schema.md)

---

## 5. Optimized Query & Caching (TanStack Query)

To avoid network waterfalls and duplicate requests when opening shipment details:

- **Reference / Master Data Queries** (`staleTime: 5-15m`):
  - Currencies: `['reference', 'currencies']`
  - Cargo Companies: `procurementStockQueryKeys.cargoCompanies(tenantId)`
  - Vendors: `['vendor', 'list', { tenantId }]`
  - Progress Flows & Stages: `['procurementStock', 'progressFlows', { tenantId }]`, `['procurementStock', 'progressStages', { flowId }]`
- **Shipment Overview / Detail Query** (`staleTime: 30s`):
  - Key: `procurementStockQueryKeys.shipmentDetail(tenantId, shipmentId)`
  - Prefer consolidated RPC or nested query over multiple uncoordinated REST requests.
  - Dedupes in-flight requests and eliminates waterfall calls from child components on mount.