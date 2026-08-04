# Shipment Database Schema

## 1. Schema Fields

### 1.1 `shipments` (Universal Header)
Generic shipment container — works for `international`, `local`, `thrift`, `transfer`. Contains **zero financial/rate fields**.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `tenant_id` | BIGINT | Yes | FK to `tenants.id` |
| `tenant_shipment_id` | BIGINT | Yes | Sequential shipment # per tenant |
| `name` | TEXT | Yes | Shipment name / batch title |
| `status` | TEXT | Yes | Status (`draft`, `in_transit`, `received`, `cancelled`) |
| `shipment_type` | TEXT | Yes | Type (`'international'`, `'local'`, `'thrift'`, `'transfer'`) |
| `vendor_id` | BIGINT | No | FK to `vendors.id` |
| `cargo_company_id` | BIGINT | No | FK to `cargo_companies.id` |
| `total_weight_kg` | NUMERIC | No | Total received weight in kg |
| `inventory_added` | BOOLEAN | No | Flag if inventory has been posted |
| `metadata` | JSONB | No | Flexible JSON for custom attributes |
| `deleted_at` | TIMESTAMPTZ | No | Timestamp of soft deletion |
| `deleted_by` | UUID | No | FK to auth.users (soft deleted by) |
| `created_at` | TIMESTAMPTZ | Yes | Timestamp of creation |
| `updated_at` | TIMESTAMPTZ | Yes | Timestamp of last update |

### 1.2 `shipment_cost_entries` (Rate & Cost Engine Inputs)
Every financial aspect of a shipment is a **cost entry row**. Stores raw inputs — effective rates are computed by the cost engine, never stored.

* **Flexible Cost Types**: `'product'`, `'cargo'`, `'duty'`, `'insurance'`, `'labor'`, `'washing'`, `'transport'`, `'handling'` — adding new types requires zero schema changes.
* **Payment Sources**: `'cash'`, `'credit'`, `'wallet'`
* **Currency Per Entry**: Each entry carries its own currency and exchange rate. Local entries use `exchange_rate: 1.00`.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `tenant_id` | BIGINT | Yes | Tenant anchor |
| `shipment_id` | BIGINT | Yes | FK to `shipments.id` |
| `cost_type` | TEXT | Yes | Expense category (`'product'`, `'cargo'`, `'duty'`, `'labor'`, etc.) |
| `entity_type` | TEXT | No | Target wallet entity type if `payment_source` = `'wallet'` (e.g. `'vendor'`, `'courier'`) |
| `entity_id` | BIGINT | No | Target wallet entity ID if `payment_source` = `'wallet'` |
| `currency_id` | BIGINT | No | FK to `currencies.id` — currency of `amount` |
| `amount` | NUMERIC | No | Cost amount in the source currency |
| `exchange_rate` | NUMERIC | No | Conversion rate to base currency (BDT). Default `1.00` |
| `payment_source` | TEXT | No | How it was funded (`'cash'`, `'credit'`, `'wallet'`) |
| `metadata` | JSONB | No | Notes, reference numbers, invoice details |

#### Cost Engine — Computed Outputs (never stored)
The cost engine derives these from `shipment_cost_entries` + `shipment_items`:

| Output | Formula |
| :--- | :--- |
| Effective product rate | `Σ(amount × exchange_rate) / Σ(amount)` where `cost_type = 'product'` |
| Effective cargo rate | Same weighted average for `cost_type = 'cargo'` |
| Total cost (BDT) per type | `Σ(amount × exchange_rate)` grouped by `cost_type` |
| Cargo cost per kg | `total_cargo_cost_bdt / total_weight_kg` |
| Per-item landed cost | `(unit_purchase_price × effective_product_rate) + (item_weight_share × cargo_cost_per_kg)` |

### 1.3 `shipment_items`
| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `shipment_id` | BIGINT | Yes | FK to `shipments.id` |
| `product_id` | BIGINT | No | FK to product |
| `quantity` | INT | Yes | Quantity in shipment |
| `unit_purchase_price` | NUMERIC | No | Unit purchase price in foreign/purchase currency |
| `product_weight_gm` | NUMERIC | No | Weight per single product unit in grams (gm) |
| `package_weight_gm` | NUMERIC | No | Package/box weight contribution in grams (gm) |
| `landed_cost_bdt` | NUMERIC | No | Stamped per-unit landed cost in BDT. Computed by the cost engine at finalization or cost revision. Downstream consumers read this directly — no joins to cost entries needed. |
| `metadata` | JSONB | No | Flexible JSON object for item-level metadata/attributes |

### 1.4 `shipment_boxes` (Box Details & Weights)
| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `shipment_id` | BIGINT | Yes | FK to `shipments.id` |
| `box_number` | TEXT | Yes | Box identifier (e.g. `"BOX-01"`, `"CTN-02"`) |
| `weight_kg` | NUMERIC | Yes | Box weight in kg |
| `metadata` | JSONB | No | Flexible JSON object for box-level metadata/attributes |
