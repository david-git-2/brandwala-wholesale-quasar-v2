# Vendor Database Schema

## 1. Schema Fields

### 1.1 `vendors`
| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `tenant_id` | BIGINT | Yes | FK to `tenants.id` (Tenant scope anchor) |
| `name` | TEXT | Yes | Vendor business/display name |
| `code` | TEXT | Yes | Unique vendor identifier/shortcode per tenant |
| `market_code` | TEXT | Yes | FK to `markets.code` (e.g., `BD_LOCAL`, `UK_MARKET`) |
| `email` | TEXT | No | Vendor contact email address |
| `phone` | TEXT | No | Vendor primary contact phone number |
| `address` | TEXT | No | Physical/billing address |
| `website` | TEXT | No | Vendor official website URL |
| `deleted_at` | TIMESTAMPTZ | No | Timestamp of soft deletion |
| `deleted_by` | UUID | No | FK to auth.users (soft deleted by) |
| `created_at` | TIMESTAMPTZ | No | Timestamp of creation |
| `updated_at` | TIMESTAMPTZ | No | Timestamp of last update |

---

## 2. Wallet & Entity Relations

* **Wallet Anchor**: Each vendor maps 1-to-1 to a record in `wallet_accounts` where `entity_type = 'vendor'` and `entity_id = vendors.id`.
* **Currency Binding**: Vendor transactions and wallet ledgers operate under `currency_id`.
* **Cascading & Safety Controls**:
  * Deleting a vendor is permitted if `available_balance = 0` in `wallet_accounts` (`ON DELETE CASCADE`).
  * If `available_balance > 0`, hard deletion is blocked by FK/trigger constraints to protect audit history.
