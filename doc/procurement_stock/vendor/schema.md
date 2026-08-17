# Vendor Database Schema

## 1. Schema Fields

### 1.1 `vendors`
| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `tenant_id` | BIGINT | Yes | FK to `tenants.id` (Tenant scope anchor) |
| `parent_tenant_id` | BIGINT | No | Resolved parent warehouse tenant (`tenant_id` when parent; else `tenants.parent_id`) |
| `name` | TEXT | Yes | Vendor business/display name |
| `code` | TEXT | Yes | Unique vendor identifier/shortcode per tenant. Reserved: `DEFAULT` for the system default vendor |
| `market_code` | TEXT | Yes | FK to `markets.code` (ISO market codes, e.g. `GB`, `BD`) |
| `is_default` | BOOLEAN | Yes | `true` for the tenant’s system default vendor. Default `false`. At most one `true` per `tenant_id` (partial unique index `vendors_one_default_per_tenant_idx`) |
| `email` | TEXT | No | Vendor contact email address |
| `phone` | TEXT | No | Vendor primary contact phone number |
| `address` | TEXT | No | Physical/billing address |
| `website` | TEXT | No | Vendor official website URL |
| `created_at` | TIMESTAMPTZ | No | Timestamp of creation |
| `updated_at` | TIMESTAMPTZ | No | Timestamp of last update |

### 1.2 Default vendor rules
* **Per parent tenant** — not a shared global row. Child tenants do not own a default vendor.
* Reserved `code = 'DEFAULT'`, display name `Default Vendor`.
* Provisioned by `ensure_default_vendor(p_tenant_id)` (idempotent) and on parent `create_tenant_for_superadmin`.
* Used as shipment-header fallback / create-dialog prefill when no vendor is chosen.

---

## 2. Wallet & Entity Relations

* **Wallet Anchor**: Each vendor maps 1-to-1 to a record in `wallet_accounts` where `entity_type = 'vendor'` and `entity_id = vendors.id`.
* **Currency Binding**: Vendor transactions and wallet ledgers operate under `currency_code` on `wallet_accounts` (default `BDT` on create).
* **Cascading & Safety Controls**:
  * Deleting a vendor is permitted if `available_balance = 0` in `wallet_accounts` (`ON DELETE CASCADE`).
  * If `available_balance > 0`, hard deletion is blocked by FK/trigger constraints to protect audit history.
  * Do **not** delete the `is_default` / `code = 'DEFAULT'` vendor — it is required for shipment header fallback.
