# Global Reference Database Schema

## 1. Overview
The Global Reference domain manages core system lookup and reference data:
* `markets`: Geographic/regional ISO markets reference catalog (e.g., `BD_LOCAL`, `UK_MARKET`, `US_MARKET`).
* `global_currencies`: Fiat and transaction currency catalog (e.g., `BDT`, `USD`, `GBP`, `EUR`).
* `payment_methods`: System-supported payment channels (e.g., `BKASH`, `BANK_TRANSFER`, `CASH`).
* `units_of_measure`: Standard units for weight, count, volume, length, and packaging (e.g., `KG`, `PCS`, `PAIR`, `MTR`).

> **Read-Only Reference Data**: Global Reference tables are system-managed lookup data. Dynamic `INSERT`, `UPDATE`, or `DELETE` operations are **not permitted** via standard user workflows.

---

## 2. Schema Fields

### 2.1 `markets`
| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `code` | TEXT | Yes | Unique market identifier/code (FK reference target, e.g. `BD_LOCAL`, `UK_MARKET`) |
| `name` | TEXT | Yes | Human-readable market display name (e.g. `Bangladesh Local Market`) |
| `region` | TEXT | Yes | Geographic region identifier (e.g. `ASIA`, `EUROPE`, `NORTH_AMERICA`) |
| `is_active` | BOOLEAN | Yes | Active state status (`true` / `false`) |
| `is_system` | BOOLEAN | Yes | System protection flag (`true` for core default markets) |
| `created_at` | TIMESTAMPTZ | No | Timestamp of record creation |
| `updated_at` | TIMESTAMPTZ | No | Timestamp of last record update |

### 2.2 `global_currencies`
| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `code` | TEXT | Yes | Unique ISO 4217 currency code (e.g., `BDT`, `USD`, `GBP`) |
| `name` | TEXT | Yes | Full currency name (e.g., `Bangladeshi Taka`, `US Dollar`) |
| `symbol` | TEXT | Yes | Currency symbol (e.g., `৳`, `$`, `£`) |
| `country` | TEXT | Yes | Primary country or territory (e.g., `Bangladesh`, `United States`) |
| `is_active` | BOOLEAN | Yes | Active state status (`true` / `false`) |
| `is_system` | BOOLEAN | Yes | System protection flag |
| `created_at` | TIMESTAMPTZ | No | Timestamp of record creation |
| `updated_at` | TIMESTAMPTZ | No | Timestamp of last record update |

### 2.3 `payment_methods`
| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `code` | TEXT | Yes | Unique payment method code (e.g., `BKASH`, `BANK_TRANSFER`) |
| `name` | TEXT | Yes | Display name (e.g., `bKash Mobile Wallet`) |
| `category` | TEXT | Yes | Category (`bd_mobile_wallet`, `bd_bank`, `bd_cash`, `card`, `international`) |
| `scope` | TEXT | Yes | Scope (`bd`, `international`, `both`) |
| `sort_order` | INTEGER | Yes | Ordering sequence for display |
| `is_active` | BOOLEAN | Yes | Active state status |
| `is_system` | BOOLEAN | Yes | System protection flag |
| `created_at` | TIMESTAMPTZ | No | Timestamp of record creation |
| `updated_at` | TIMESTAMPTZ | No | Timestamp of last record update |

### 2.4 `units_of_measure`
| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `code` | TEXT | Yes | Unique unit code (e.g., `KG`, `PCS`, `PAIR`, `LITRE`) |
| `name` | TEXT | Yes | Display name (e.g., `Kilogram`, `Pieces`) |
| `unit_type` | TEXT | Yes | Unit category (`weight`, `count`, `length`, `volume`, `packaging`) |
| `symbol` | TEXT | No | Unit symbol abbreviation (e.g., `kg`, `pcs`) |
| `sort_order` | INTEGER | Yes | Ordering sequence for display |
| `is_active` | BOOLEAN | Yes | Active state status |
| `is_system` | BOOLEAN | Yes | System protection flag |
| `created_at` | TIMESTAMPTZ | No | Timestamp of record creation |
| `updated_at` | TIMESTAMPTZ | No | Timestamp of last record update |

---

## 3. Entity Relationships
* **`vendors.market_code`** $\rightarrow$ `markets.code`
* **`shipments.market_code`** $\rightarrow$ `markets.code`
* **`products.market_code`** $\rightarrow$ `markets.code`
* **`product_based_costing_items.market_code`** $\rightarrow$ `markets.code`
* **`vendors.currency_id`** $\rightarrow$ `global_currencies.id`
* **`shipments.currency_code`** $\rightarrow$ `global_currencies.code`
* **`tenant_wallets.currency_code`** $\rightarrow$ `global_currencies.code`

---

## 4. Initial Database Seeder
The seed values for all four global reference tables are maintained in [seeder.sql](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/global_reference/seeder.sql).

