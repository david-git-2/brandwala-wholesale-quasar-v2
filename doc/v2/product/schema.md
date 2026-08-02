# Product Database Schema

## 1. Schema Fields

### 1.1 `products`
| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `tenant_id` | BIGINT | No | FK to `tenants.id` (Tenant anchor) |
| `parent_tenant_id` | BIGINT | No | FK to `tenants.id` (Parent tenant / platform scope) |
| `product_code` | TEXT | No | Product SKU / unique item identifier |
| `barcode` | TEXT | No | UPC / EAN / GTIN Barcode string |
| `name` | TEXT | No | Product display name |
| `brand` | TEXT | No | Brand name reference string |
| `category` | TEXT | No | Category name reference string |
| `vendor_id` | BIGINT | No | FK to `vendors.id` |
| `vendor_code` | TEXT | No | Vendor short code |
| `market_code` | TEXT | No | FK to `markets.code` (e.g. `BD_LOCAL`, `UK_MARKET`) |
| `list_price_amount` | NUMERIC | No | Product retail / list selling price |
| `list_price_currency_id` | BIGINT | No | FK to `global_currencies.id` for list price |
| `reference_cost_amount` | NUMERIC | No | Supplier / foreign cost price |
| `reference_cost_currency_id` | BIGINT | No | FK to `global_currencies.id` for cost price |
| `available_units` | INT | No | Available inventory count |
| `minimum_order_quantity` | INT | No | Minimum order batch size (MOQ) |
| `product_weight` | NUMERIC | No | Net weight of single unit (in kg or gm) |
| `package_weight` | NUMERIC | No | Weight of packaging / box contribution |
| `country_of_origin` | TEXT | No | Origin country (e.g. `UK`, `CN`) |
| `tariff_code` | TEXT | No | HS / Tariff code for international shipping |
| `languages` | TEXT | No | Supported / packaging languages |
| `batch_code_manufacture_date` | TEXT | No | Batch code or manufacturing info |
| `expire_date` | DATE/TEXT | No | Expiration date string |
| `image_url` | TEXT | No | Primary product image URL |
| `is_available` | BOOLEAN | No | Active availability status flag |
| `source` | TEXT | No | Source system / catalog origin |
| `hazardous` | BOOLEAN | No | Flag indicating hazardous / restricted goods |
| `created_at` | TIMESTAMPTZ | Yes | Timestamp of creation |
| `updated_at` | TIMESTAMPTZ | Yes | Timestamp of last update |

---

### 1.2 `product_brands`
| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `tenant_id` | BIGINT | No | FK to `tenants.id` |
| `parent_tenant_id` | BIGINT | No | FK to `tenants.id` |
| `name` | TEXT | Yes | Brand display name |
| `value` | TEXT | No | Normalized brand slug / identifier |
| `vendor_id` | BIGINT | No | FK to `vendors.id` |
| `vendor_code` | TEXT | No | Associated vendor code |
| `created_at` | TIMESTAMPTZ | Yes | Timestamp of creation |
| `updated_at` | TIMESTAMPTZ | Yes | Timestamp of last update |

---

### 1.3 `product_categories`
| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `tenant_id` | BIGINT | No | FK to `tenants.id` |
| `parent_tenant_id` | BIGINT | No | FK to `tenants.id` |
| `name` | TEXT | Yes | Category display name |
| `value` | TEXT | No | Normalized category slug / identifier |
| `vendor_id` | BIGINT | No | FK to `vendors.id` |
| `vendor_code` | TEXT | No | Associated vendor code |
| `created_at` | TIMESTAMPTZ | Yes | Timestamp of creation |
| `updated_at` | TIMESTAMPTZ | Yes | Timestamp of last update |

---

## 2. Foreign Keys & Entity Relationships

* **Vendor Anchor**: `products.vendor_id` -> `vendors.id` (`products_vendor_id_fkey`)
* **Market Reference**: `products.market_code` -> `markets.code` (`products_market_code_fkey`)
* **Tenant Scope**: `products.tenant_id` -> `tenants.id` (`products_tenant_id_fkey`)
* **Currency Bindings**:
  * `products.list_price_currency_id` -> `global_currencies.id`
  * `products.reference_cost_currency_id` -> `global_currencies.id`
* **Shipment Linkage**: `shipment_items.product_id` references `products.id`. Weight metrics (`product_weight`, `package_weight`) can sync directly between `shipment_items` and `products`.
