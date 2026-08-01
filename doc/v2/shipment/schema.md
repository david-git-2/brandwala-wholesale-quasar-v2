# Shipment Database Schema

## 1. Schema Fields

### 1.1 `shipments`
| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `tenant_id` | BIGINT | Yes | FK to `tenants.id` (Tenant Wallet anchor) |
| `tenant_shipment_id` | BIGINT | Yes | Sequential shipment # per tenant |
| `name` | TEXT | Yes | Shipment name/batch title |
| `status` | TEXT | Yes | Status (`draft`, `received`, etc.) |
| `shipment_type` | TEXT | Yes | Type (`'international'` or `'local'`) |
| `vendor_id` | BIGINT | Yes | FK to `vendors.id` (Vendor Wallet anchor) |
| `cargo_company_id` | BIGINT | No | FK to `cargo_companies.id` (Cargo Wallet anchor) |
| `shipment_purchase_currency_id` | BIGINT | No | FK to `currencies.id` (e.g. GBP, USD) |
| `shipment_cost_currency_id` | BIGINT | No | FK to `currencies.id` for cargo |
| `vendor_invoice_total` | NUMERIC | No | Total invoice amount billed by vendor (in purchase currency) |
| `cargo_invoice_total` | NUMERIC | No | Total invoice amount billed by cargo company (in cost currency) |
| `product_conversion_rate` | NUMERIC | No | **Effective Rate for Products** (Calculated weighted average from `shipment_payments`) |
| `cargo_conversion_rate` | NUMERIC | No | **Effective Rate for Cargo** (Calculated weighted average from `shipment_payments`) |
| `transaction_rate` | NUMERIC | No | Exchange rate multiplier used for batch costing / BDT conversion |
| `total_weight_kg` | NUMERIC | No | Total weight in kg |
| `inventory_added` | BOOLEAN | No | Flag if inventory has been posted |
| `metadata` | JSONB | No | Flexible JSON object for custom attributes or future metadata |

### 1.2 `shipment_payments` (Single Source of Rate Inputs & Payment Allocations)
Stores payment source, foreign purchase amount, and exchange rate for each expense target.

* **Creation Default**: When a shipment is created, 2 default entries are initialized automatically:
  1. **Vendor Product Entry**: `payment_target: 'product'`, `payment_source: 'cash'`, `purchase_amount: null`, `exchange_rate: 0`
  2. **Cargo Freight Entry**: `payment_target: 'cargo'`, `payment_source: 'cash'`, `purchase_amount: null`, `exchange_rate: 0`
* **Supported Payment Sources**:
  * `'cash'` (Direct payment / cash)
  * `'credit'` (Wallet balance / credit balance)
* **Flexible Updates**: `purchase_amount` and `exchange_rate` can be updated later as actual numbers are finalized.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `tenant_id` | BIGINT | Yes | Tenant ID |
| `shipment_id` | BIGINT | Yes | FK to `shipments.id` |
| `payment_target` | TEXT | Yes | Target expense (`'product'` for vendor, `'cargo'` for cargo) |
| `payment_source` | TEXT | Yes | Source (`'cash'` or `'credit'`) |
| `purchase_amount` | NUMERIC | No | Purchase currency amount (default `null`) |
| `exchange_rate` | NUMERIC | No | Exchange rate (default `0`) |

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
| `metadata` | JSONB | No | Flexible JSON object for item-level metadata/attributes |

### 1.4 `shipment_boxes` (Box Details & Weights)
| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `shipment_id` | BIGINT | Yes | FK to `shipments.id` |
| `box_number` | TEXT | Yes | Box identifier (e.g. `"BOX-01"`, `"CTN-02"`) |
| `weight_kg` | NUMERIC | Yes | Box weight in kg |
| `metadata` | JSONB | No | Flexible JSON object for box-level metadata/attributes |
