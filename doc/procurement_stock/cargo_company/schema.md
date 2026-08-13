# Cargo Company Database Schema

Inbound freight / logistics providers for procurement shipments (`global_shipments.cargo_company_id`).

**Not** last-mile COD couriers (`entity_type = 'courier'` under reporting/treasury). Those are a separate domain.

---

## 1. Schema Fields

### 1.1 `cargo_companies`

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `tenant_id` | BIGINT | Yes | FK to `tenants.id` (Tenant scope anchor) |
| `parent_tenant_id` | BIGINT | No | Resolved parent warehouse tenant (`tenant_id` when parent; else `tenants.parent_id`) |
| `name` | TEXT | Yes | Display name |
| `code` | TEXT | Yes | Unique shortcode per tenant. Reserved: `DEFAULT` for the system default cargo company |
| `is_default` | BOOLEAN | Yes | `true` for the tenant’s system default. Default `false`. At most one `true` per `tenant_id` (partial unique index `cargo_companies_one_default_per_tenant_idx`) |
| `is_active` | BOOLEAN | Yes | Soft-disable for pickers. Default `true` |
| `phone` | TEXT | No | Primary contact phone |
| `email` | TEXT | No | Contact email |
| `address` | TEXT | No | Physical / billing address |
| `notes` | TEXT | No | Free-form ops notes |
| `wallet_entity_id` | BIGINT | No | Optional denormalized pointer. **SSOT** for balances is `wallet_accounts` (`entity_type = 'cargo_company'`, `entity_id = cargo_companies.id`). Prefer leaving null or syncing to wallet account id — do not invent a second ledger |
| `created_at` | TIMESTAMPTZ | No | Timestamp of creation |
| `updated_at` | TIMESTAMPTZ | No | Timestamp of last update |

> **Live:** `is_default` + `ensure_default_cargo_company` / `create_cargo_company_with_wallet` via migration `20270803000040_cargo_companies_is_default.sql`.

### 1.2 Default cargo company rules

* **Per parent tenant** — not a shared global row. Child tenants do not own a default cargo company.
* Reserved `code = 'DEFAULT'`, display name `Default Cargo Company`.
* Provisioned by `ensure_default_cargo_company(p_tenant_id)` (idempotent) and on parent `create_tenant_for_superadmin` (same hook as default vendor).
* Used as shipment-header create-dialog prefill / draft RPC fallback when no cargo company is chosen.

---

## 2. Wallet & Entity Relations

* **Wallet Anchor**: Each cargo company maps 1-to-1 to `wallet_accounts` where `entity_type = 'cargo_company'` and `entity_id = cargo_companies.id`.
* **Currency Binding**: Default create uses `currency_code = 'BDT'` (same as vendor).
* **Distinction**: Last-mile COD remittance uses `entity_type = 'courier'` — do not reuse cargo-company ids there.
* **Cascading & Safety Controls**:
  * Deleting a cargo company is permitted if wallet `available_balance = 0`.
  * If `available_balance > 0`, hard deletion is blocked to protect audit history.
  * Do **not** delete the `is_default` / `code = 'DEFAULT'` row — required for shipment create prefill / header fallback.
  * Shipments reference via `cargo_company_id` (`ON DELETE SET NULL` live) — clearing the FK must not orphan required financial history on the wallet.

---

## 3. Shipment relation

| Column | Table | Notes |
| :--- | :--- | :--- |
| `cargo_company_id` | `global_shipments` | Nullable FK → `cargo_companies.id`. Create dialog / `create_shipment_draft` prefills default when omitted. See [../shipment/schema.md](../shipment/schema.md) |
