# Wallet Database Schema

## 1. Schema Fields

### 1.1 `wallet_accounts`
Stores current balance buckets (`available_balance`, `locked_balance`, `pending_balance`) per entity (`vendor`, `customer`, `courier`, `middleman`, `tenant`, `investor`).

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | BIGINT | Yes | Primary Key |
| `tenant_id` | BIGINT | Yes | FK to `tenants.id` (Tenant anchor) |
| `entity_type` | TEXT | Yes | Entity classification (`'vendor'`, `'customer'`, `'courier'`, `'middleman'`, `'tenant'`, `'investor'`) |
| `entity_id` | BIGINT | Yes | Primary Key ID of target entity |
| `currency_code` | TEXT | Yes | Currency code (Default: `'BDT'`) |
| `available_balance` | NUMERIC | Yes | Unrestricted funds ready for payout or transaction (Default: `0.00`) |
| `locked_balance` | NUMERIC | Yes | Funds locked for escrow, security, or active orders (Default: `0.00`) |
| `pending_balance` | NUMERIC | Yes | Unsettled incoming/outgoing funds awaiting release (Default: `0.00`) |
| `deleted_at` | TIMESTAMPTZ | No | Timestamp of soft deletion |
| `deleted_by` | UUID | No | FK to auth.users (soft deleted by) |
| `created_at` | TIMESTAMPTZ | No | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | No | Last update timestamp |

* **Unique Constraint**: `uq_wallet_account UNIQUE (tenant_id, entity_type, entity_id, currency_code)`

---

### 1.2 `universal_wallet_ledger`
Immutable double-entry transaction history log for auditing, reporting, and account statements.

| Field | Type | Required | Description |
| :--- | :--- | :---: | :--- |
| `id` | UUID | Yes | Primary Key (`gen_random_uuid()`) |
| `tenant_id` | BIGINT | Yes | FK to `tenants.id` |
| `entity_type` | TEXT | Yes | Entity classification (`'vendor'`, `'customer'`, `'courier'`, `'middleman'`, `'tenant'`, `'investor'`) |
| `entity_id` | BIGINT | Yes | Primary Key ID of target entity |
| `type` | TEXT | Yes | Transaction type (`'credit'` or `'debit'`) |
| `amount` | NUMERIC | Yes | Transaction amount in transaction currency |
| `base_amount` | NUMERIC | Yes | Calculated amount in tenant base currency (`amount * exchange_rate`) |
| `currency_code` | TEXT | Yes | Currency code (Default: `'BDT'`) |
| `exchange_rate` | NUMERIC | Yes | Conversion multiplier against base currency (Default: `1.000000`) |
| `balance_after` | NUMERIC | Yes | Snapshot of effective running balance after transaction |
| `source_type` | TEXT | Yes | Transaction origin (`'shop_order'`, `'vendor_purchase'`, `'shipment'`, `'shipment_return'`, `'payout'`, `'adjustment'`, `'bucket_transfer'`, `'shipment_invoice'`). Identifies the **trigger document**, not the wallet owner |
| `source_id` | TEXT | No | Reference ID of triggering record (e.g. invoice #, order #, shipment id, payment ID) |
| `metadata` | JSONB | No | Flexible JSON payload for context notes, references, and audit tags |
| `created_at` | TIMESTAMPTZ | No | Creation timestamp |

---

## 2. SQL Definitions

### 2.1 `wallet_accounts` DDL
```sql
CREATE TABLE wallet_accounts (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id         BIGINT NOT NULL REFERENCES tenants(id),
  entity_type       TEXT NOT NULL,
  entity_id         BIGINT NOT NULL,
  currency_code     TEXT NOT NULL DEFAULT 'BDT',
  available_balance NUMERIC NOT NULL DEFAULT 0.00,
  locked_balance    NUMERIC NOT NULL DEFAULT 0.00,
  pending_balance   NUMERIC NOT NULL DEFAULT 0.00,
  deleted_at        TIMESTAMPTZ,
  deleted_by        UUID,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT uq_wallet_account UNIQUE (tenant_id, entity_type, entity_id, currency_code)
);
```

### 2.2 `universal_wallet_ledger` DDL
```sql
CREATE TABLE universal_wallet_ledger (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tenant_id     BIGINT NOT NULL REFERENCES tenants(id),
  entity_type   TEXT NOT NULL,
  entity_id     BIGINT NOT NULL,
  type          TEXT NOT NULL,
  amount        NUMERIC NOT NULL,
  base_amount   NUMERIC NOT NULL,
  currency_code TEXT NOT NULL DEFAULT 'BDT',
  exchange_rate NUMERIC NOT NULL DEFAULT 1.000000,
  balance_after NUMERIC NOT NULL,
  source_type   TEXT NOT NULL,
  source_id     TEXT,
  metadata      JSONB DEFAULT '{}'::jsonb,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);
```
