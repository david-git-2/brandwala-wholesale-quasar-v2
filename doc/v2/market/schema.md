# Market Database Schema

## 1. Overview
The `markets` table serves as a global reference catalog for geographic/regional markets operating in the system (e.g., `BD_LOCAL`, `UK_MARKET`, `US_MARKET`). 

> **Read-Only Reference Data**: `markets` is system-managed lookup reference data. Dynamic `INSERT`, `UPDATE`, or `DELETE` operations are **not permitted** via standard user workflows.

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

---

## 3. Entity Relationships
* **`vendors.market_code`** $\rightarrow$ `markets.code`
* **`shipments.market_code`** $\rightarrow$ `markets.code`
* **`products.market_code`** $\rightarrow$ `markets.code`
* **`product_based_costing_items.market_code`** $\rightarrow$ `markets.code`
