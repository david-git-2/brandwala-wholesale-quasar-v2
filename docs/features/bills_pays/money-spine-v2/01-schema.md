# 01-schema

Tables + triggers. Implement DDL from this file. Invariants: [00-overview.md](00-overview.md).

**Schema layout:** operational tables and triggers live in `money_kernel`. Clients call `public.rpc_*` wrappers only (see [05-security.md](05-security.md)). Examples below use `money_kernel`; public views may `SELECT` from kernel tables under RLS.

**DDL completeness:** every index in table sections must appear as executable `CREATE INDEX` in [§7 Index DDL](#7-index-ddl-executable) and migrations.

---

## 0. Security and tenant integrity

| Topic | Rule |
| :--- | :--- |
| Parent uniqueness | `UNIQUE (tenant_id, id)` on `profiles`, `bills`, `pays`, `cashbook_point_pots`, … |
| Composite FKs | `bill_settlements.(tenant_id, bill_id)` → `bills.(tenant_id, id)`; same pattern for `pays_id`, `source_bill_id`, `bill_lines.bill_id`, pays→pots, pots→points→accounts |
| Profile FKs | `bills.from_profile_id`, `to_profile_id`, `counterparty_profile_id` → `profiles.(tenant_id, id)`; `counterparty_profile_id` must equal `from` or `to` (or RPC derives it) |
| `tenant_id` immutability | `BEFORE UPDATE OF tenant_id` trigger on every operational table → reject |
| Self-profile | `profiles.is_tenant_self` + partial unique `(tenant_id)` WHERE true; AR creditor = that profile |
| Cascades | `cashbook_accounts` → `points` → `pots`: **ON DELETE RESTRICT** (not CASCADE) |
| Direct DML | `REVOKE` on kernel tables from `authenticated`; `BEFORE DELETE` / `TRUNCATE` guards on `pays`, `bills`, `bill_settlements` |
| Pot minting | T3 `BEFORE INSERT`: `amount = 0` (I36); `BEFORE UPDATE`: require `current_setting('money.pot_writer', true) = '1'` set by `fn_pays_apply` (not depth alone) |
| Settlement delete | Only when linked pays is `voided`, or `meta.allow_settlement_delete` set by void RPC |

---

## 1. Design Principles

| # | Principle | Rationale |
|---|---|---|
| P1 | **Money is in typed numeric columns, extensions in jsonb** | Reporting/filtering works on money columns; kind-specific fields stay flexible |
| P2 | **Append-only where audit matters** (`bill_events`, `pays` effective) | Every state change is traceable |
| P3 | **Pot balances (`cashbook_point_pots.amount`) are never written directly** — only via `fn_pays_apply` / T1 | Eliminates pot vs pays drift. Does **not** apply to unused `cashbook_accounts.*_balance` columns (non-spine). |
| P4 | **One primitive per concern** — `pays` for movement, `bills` for documents, `bill_settlements` for allocation | Each table has exactly one job |
| P5 | **Registry-driven, not code-driven** — new bill kinds via registry INSERT | Zero code change to add a kind |
| P6 | **Tenant isolation at row level** — every operational table has `tenant_id` | RLS-scoped; cross-tenant only where explicitly modeled |
| P7 | **`kind` + `meta jsonb` beats typed columns per variant** | Avoids schema churn as the product grows |
| P8 | **Idempotency everywhere money moves** | Retry-safe by design |

---

## 2. Table Dependency Graph

Deployment order = top-to-bottom. Arrows point from FK → parent.

```
┌─────────────┐
│  profiles   │
└──────┬──────┘
       │
       ▼
┌─────────────────────┐
│ cashbook_accounts   │◄──────┐
└──────┬──────────────┘       │
       │                       │ (self-ref: default pot)
       ▼                       │
┌─────────────────┐            │
│ cashbook_points │            │
└──────┬──────────┘            │
       │                       │
       ▼                       │
┌────────────────────────┐     │
│ cashbook_point_pots    │─────┘
└──────┬─────────────────┘
       │
       ├──────────────────────────┐
       │                          │
       ▼                          ▼
┌─────────────┐          ┌──────────────────┐
│    pays     │          │ bill_settlements │
└──────┬──────┘          └────────┬─────────┘
       │                          │
       │                          ▼
       │                  ┌──────────────────┐
       │                  │      bills       │
       │                  └────────┬─────────┘
       │                           │
       │                 ┌─────────┼──────────┐
       │                 │         │          │
       │                 ▼         ▼          ▼
       │          ┌──────────┐ ┌────────┐ ┌───────────────┐
       │          │bill_lines│ │bill_   │ │bill_kind_     │
       │          │          │ │events  │ │registry (FK)  │
       │          └──────────┘ └────────┘ └───────────────┘
       │
       │
       ├──────────────────────────┐
       │                          │
       ▼                          ▼
(no downstream)          ┌───────────────────────┐
                         │ invoice_no_counters   │
                         │ (no FK — sequence)    │
                         └───────────────────────┘

Standalone:
┌───────────────────────────┐
│  books_exchange_rates     │
└───────────────────────────┘
```

---

## 3. Tables (14 + outbox)

Deployment order: 1 → 15. See [§5 Deployment Order](#5-deployment-order).

---

### 3.0 `currencies`

ISO 4217 reference; enforces valid `currency_code` on pots, pays, and bills (rejects `'bdt'` / `'bda'` junk).

```sql
CREATE TABLE money_kernel.currencies (
  code         text PRIMARY KEY CHECK (code ~ '^[A-Z]{3}$'),
  minor_units  smallint NOT NULL CHECK (minor_units BETWEEN 0 AND 4),
  name         text NOT NULL
);

INSERT INTO money_kernel.currencies (code, minor_units, name) VALUES
  ('BDT', 2, 'Bangladesh Taka'),
  ('USD', 2, 'US Dollar'),
  ('JPY', 0, 'Japanese Yen'),
  ('KWD', 3, 'Kuwaiti Dinar');
```

`cashbook_point_pots.currency_code`, `pays.currency_code`, `bills.currency_code` → FK `REFERENCES currencies(code)`.

---

### 3.1 `profiles`

**Purpose:** Master registry of every entity that can hold a cashbook (customer, vendor, courier, staff, etc.). One profile → one cashbook account.

```sql
CREATE TABLE public.profiles (
  id                 bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  tenant_id          bigint NOT NULL,
  profile_type       text   NOT NULL,
  name               text   NOT NULL,
  phone              text,
  phone_country_code text   NOT NULL DEFAULT '+880',
  email              text,
  address            text,
  is_active          boolean NOT NULL DEFAULT true,
  deleted_at         timestamptz,
  is_tenant_self     boolean NOT NULL DEFAULT false,
  meta               jsonb  NOT NULL DEFAULT '{}'::jsonb,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX uq_profiles_tenant_self
  ON money_kernel.profiles (tenant_id)
  WHERE is_tenant_self = true;
```

**Columns**

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | bigint | no | identity | PK |
| `tenant_id` | bigint | no | — | Owning tenant |
| `is_tenant_self` | boolean | no | `false` | One per tenant; AR payee / AP payer |
| `profile_type` | text | no | — | `customer` / `vendor` / `courier` / `staff` / … (match live `profile_party_type` at cutover) |
| `name` | text | no | — | Display name |
| `phone` | text | yes | — | |
| `phone_country_code` | text | no | `+880` | |
| `email` | text | yes | — | |
| `address` | text | yes | — | |
| `is_active` | boolean | no | `true` | |
| `deleted_at` | timestamptz | yes | — | Soft delete |
| `meta` | jsonb | no | `{}` | Extension fields (`accent_color`, `customer_group_id`, …) |
| `created_at` | timestamptz | no | `now()` | |
| `updated_at` | timestamptz | no | `now()` | |

**Constraints**

- PK: `id`

**Indexes**

| Name | Columns | Type | Purpose |
|---|---|---|---|
| (PK) | `id` | btree | — |

**Notes**

- Inserting a profile triggers auto-provisioning of its cashbook (via `fn_provision_profile_cashbook` — see Triggers below).
- No FK to other tables — this is the root.
- **Cutover:** live `profiles` still has `subject_id` and typed enums; migration/backfill maps party rows before this DDL replaces production. Until then, treat this block as **target** shape, not a diff against `supabase/schemas/bills_pays/` today.

---

### 3.2 `cashbook_accounts`

**Purpose:** Top container of a profile's (or tenant's/branch's) money. Owns all cashbook points below it and holds one pointer to its default pot (used for auto-resolution in deposit/withdraw RPCs).

```sql
CREATE TABLE public.cashbook_accounts (
  id                            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id                     bigint NOT NULL,
  entity_type                   text   NOT NULL,
  entity_id                     bigint NOT NULL,
  profile_id                    bigint,
  available_balance             numeric(18,4) NOT NULL DEFAULT 0,
  pending_balance               numeric(18,4) NOT NULL DEFAULT 0,
  locked_balance                numeric(18,4) NOT NULL DEFAULT 0,
  default_cashbook_point_pot_id bigint,  -- FK added after cashbook_point_pots (§3.4)
  created_at                    timestamptz NOT NULL DEFAULT now(),
  updated_at                    timestamptz NOT NULL DEFAULT now(),

  UNIQUE (tenant_id, entity_type, entity_id),
  CONSTRAINT chk_tenant_entity_matches
    CHECK (entity_type <> 'tenant' OR entity_id = tenant_id)
);
```

**Columns**

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | bigint | no | identity | PK |
| `tenant_id` | bigint | no | — | |
| `entity_type` | text | no | — | `profile` / `tenant` / `branch` / … |
| `entity_id` | bigint | no | — | ID of the entity in `profiles` or `tenants` |
| `profile_id` | bigint | yes | — | Set = `entity_id` when `entity_type='profile'`, else NULL |
| `available_balance` | numeric(18,4) | no | `0` | **Not spine truth** — optional UI cache; pot.amount is authoritative. `[OPEN QUESTION]` who writes this column if anyone? Spine triggers do **not**. |
| `pending_balance` | numeric(18,4) | no | `0` | Not maintained by spine triggers. Same open question as `available_balance`. |
| `locked_balance` | numeric(18,4) | no | `0` | Not maintained by spine triggers. Same open question as `available_balance`. |
| `default_cashbook_point_pot_id` | bigint | yes | — | FK to `cashbook_point_pots` |
| `created_at` | timestamptz | no | `now()` | |
| `updated_at` | timestamptz | no | `now()` | |

**Constraints**

| Name | Definition | Enforced by |
|---|---|---|
| PK | `id` | — |
| UQ | `UNIQUE (tenant_id, entity_type, entity_id)` | — |
| CHK | `entity_type <> 'tenant' OR entity_id = tenant_id` | — |

**Foreign Keys**

| Column | → Target | On Delete |
|---|---|---|
| `default_cashbook_point_pot_id` | `cashbook_point_pots.id` | (default — RESTRICT) |

**Indexes**

| Name | Columns | Type | Purpose |
|---|---|---|---|
| (PK) | `id` | btree | — |
| UQ | `(tenant_id, entity_type, entity_id)` | btree | Enforce one account per entity |
| (FK) | `default_cashbook_point_pot_id` | btree | FK lookups |

**Forward References**

- FK to `cashbook_point_pots` — must be added **after** that table exists. See §3.4 for the deferred `ALTER TABLE`.

**Notes**

- `profile_id` denormalized — trigger validates `profile_id = entity_id` when `entity_type='profile'`.
- Default pot pointer validated by trigger — must belong to this account (Triggers below).

---

### 3.3 `cashbook_points`

**Purpose:** A physical location inside an account (e.g. "main counter", "BRAC bank account", "branch B cash"). Groups pots by currency under one location.

```sql
CREATE TABLE public.cashbook_points (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id           bigint NOT NULL,
  cashbook_account_id bigint NOT NULL REFERENCES public.cashbook_accounts(id) ON DELETE RESTRICT,
  code                text   NOT NULL,
  name                text   NOT NULL,
  is_active           boolean NOT NULL DEFAULT true,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),

  UNIQUE (cashbook_account_id, code)
);
```

**Columns**

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | bigint | no | identity | PK |
| `tenant_id` | bigint | no | — | |
| `cashbook_account_id` | bigint | no | — | FK |
| `code` | text | no | — | `main` / `bank-brac` / `counter-1` / … |
| `name` | text | no | — | Display |
| `is_active` | boolean | no | `true` | |
| `created_at` | timestamptz | no | `now()` | |
| `updated_at` | timestamptz | no | `now()` | |

**Constraints**

| Name | Definition |
|---|---|
| PK | `id` |
| UQ | `(cashbook_account_id, code)` |

**Foreign Keys**

| Column | → Target | On Delete |
|---|---|---|
| `cashbook_account_id` | `cashbook_accounts.id` | CASCADE |

**Indexes**

| Name | Columns | Purpose |
|---|---|---|
| (PK) | `id` | — |
| UQ | `(cashbook_account_id, code)` | Enforce unique code per account |

---

### 3.4 `cashbook_point_pots`

**Purpose:** A single-currency balance bucket — the leaf that actually holds money. One pot = one currency at one point. `amount` is the live balance and can only be written by `fn_pays_apply`.

```sql
CREATE TABLE public.cashbook_point_pots (
  id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id         bigint NOT NULL,
  cashbook_point_id bigint NOT NULL REFERENCES public.cashbook_points(id) ON DELETE RESTRICT,
  currency_code     text   NOT NULL DEFAULT 'BDT',
  amount            numeric(18,4) NOT NULL DEFAULT 0,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),

  UNIQUE (cashbook_point_id, currency_code),
  CONSTRAINT chk_pot_amount_non_negative CHECK (amount >= 0)
);
```

**Columns**

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | bigint | no | identity | PK |
| `tenant_id` | bigint | no | — | |
| `cashbook_point_id` | bigint | no | — | FK |
| `currency_code` | text | no | `BDT` | ISO 4217 |
| `amount` | numeric(18,4) | no | `0` | **Live balance — trigger-only** |
| `created_at` | timestamptz | no | `now()` | |
| `updated_at` | timestamptz | no | `now()` | |

**Constraints**

| Name | Definition | Enforced by |
|---|---|---|
| PK | `id` | — |
| UQ | `(cashbook_point_id, currency_code)` | — |
| CHK | `amount >= 0` | — |
| (implicit) | `amount` writable only by trigger | `trg_pot_guard` (Triggers below) |

**Foreign Keys**

| Column | → Target | On Delete |
|---|---|---|
| `cashbook_point_id` | `cashbook_points.id` | CASCADE |

**Indexes**

| Name | Columns | Purpose |
|---|---|---|
| (PK) | `id` | — |
| UQ | `(cashbook_point_id, currency_code)` | Enforce one pot per currency per point |

**Post-create (after pots exist):**

```sql
ALTER TABLE public.cashbook_accounts
  ADD CONSTRAINT fk_accounts_default_pot
  FOREIGN KEY (default_cashbook_point_pot_id)
  REFERENCES public.cashbook_point_pots(id);
```

Order: accounts (no default-pot FK) → points → pots → this `ALTER`. Only circular FK in the schema.

---

### 3.5 `pays`

**Purpose:** One row per cash movement. Kinds: deposit, withdrawal, transfer, payment. Immutable once posted; voiding is the only permitted UPDATE.

```sql
CREATE TABLE public.pays (
  id               bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  tenant_id        bigint NOT NULL,

  kind             text NOT NULL CHECK (kind IN
                     ('deposit','withdrawal','transfer','payment')),

  from_pot_id      bigint REFERENCES public.cashbook_point_pots(id),
  to_pot_id        bigint REFERENCES public.cashbook_point_pots(id),

  amount           numeric(18,4) NOT NULL CHECK (amount > 0),
  currency_code    text   NOT NULL DEFAULT 'BDT',
  books_amount     numeric(18,4) NOT NULL,
  exchange_rate    numeric(15,6) NOT NULL DEFAULT 1,

  payment_date     date   NOT NULL DEFAULT CURRENT_DATE,
  status           text   NOT NULL DEFAULT 'posted' CHECK (status IN ('posted','voided')),
  voided_at        timestamptz,
  voided_by        uuid,
  idempotency_key  text,
  request_hash     text,

  from_balance_after numeric(18,4),
  to_balance_after   numeric(18,4),

  refs             jsonb NOT NULL DEFAULT '{}'::jsonb,
  meta             jsonb NOT NULL DEFAULT '{}'::jsonb,

  created_by       uuid,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),

  CHECK (from_pot_id IS NOT NULL OR to_pot_id IS NOT NULL),
  CHECK (from_pot_id IS DISTINCT FROM to_pot_id),
  CHECK (pg_column_size(meta) < 8192)
);

-- Permanent idempotency (I24): voided row still holds the key
CREATE UNIQUE INDEX uq_pays_idempotency
  ON public.pays (tenant_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;
```


**Columns**

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | bigint | no | identity | PK |
| `tenant_id` | bigint | no | — | |
| `kind` | text | no | — | `deposit` / `withdrawal` / `transfer` / `payment` |
| `from_pot_id` | bigint | yes | — | NULL = external (deposit) |
| `to_pot_id` | bigint | yes | — | NULL = external (withdrawal) |
| `amount` | numeric(18,4) | no | — | In from-pot currency (or to-pot for deposit) |
| `currency_code` | text | no | `BDT` | |
| `books_amount` | numeric(18,4) | no | — | `amount × books_rate` (BDT) |
| `exchange_rate` | numeric(15,6) | no | `1` | from → to currency (used only for `transfer`) |
| `payment_date` | date | no | `CURRENT_DATE` | |
| `status` | text | no | `posted` | `posted` / `voided` |
| `voided_at` | timestamptz | yes | — | |
| `voided_by` | uuid | yes | — | Set on void |
| `request_hash` | text | yes | — | Idempotency conflict detection |
| `from_balance_after` / `to_balance_after` | numeric(18,4) | yes | — | Pot snapshot at post (recon / reads) |
| `idempotency_key` | text | yes | — | Unique per tenant (permanent) |
| `refs` | jsonb | no | `{}` | `{bill_id, shipment_id, …}` |
| `meta` | jsonb | no | `{}` | `{method, reference, note, void_reason, …}` |
| `created_by` | uuid | yes | — | `auth.uid()` |
| `created_at` | timestamptz | no | `now()` | |
| `updated_at` | timestamptz | no | `now()` | |

**Constraints**

| Name | Definition | Enforced by |
|---|---|---|
| PK | `id` | — |
| UQ | `uq_pays_idempotency` `(tenant_id, idempotency_key)` | — |
| CHK | `from_pot_id IS DISTINCT FROM to_pot_id` | I30 |
| CHK | `kind IN (...)` | — |
| CHK | `amount > 0` | — |
| CHK | `status IN ('posted','voided')` | — |
| CHK | `from_pot_id IS NOT NULL OR to_pot_id IS NOT NULL` | — |
| (implicit) | only `posted → voided` and `voided_at`/`meta` writable on UPDATE | `trg_pays_guard_immutable` |

**Foreign Keys**

| Column | → Target | On Delete |
|---|---|---|
| `from_pot_id` | `cashbook_point_pots.id` | (default — RESTRICT) |
| `to_pot_id` | `cashbook_point_pots.id` | (default — RESTRICT) |

**Indexes**

| Name | Columns | Type | Purpose |
|---|---|---|---|
| (PK) | `id` | btree | — |
| `uq_pays_idempotency` | `(tenant_id, idempotency_key)` | btree | Permanent idempotency |
| `ix_pays_from` | `(tenant_id, from_pot_id, payment_date)` | btree | From-pot history |
| `ix_pays_to` | `(tenant_id, to_pot_id, payment_date)` | btree | To-pot history |
| `ix_pays_refs` | `refs` | GIN (jsonb_path_ops) | `exchange_rate_id`, not full allocations JSON |

**Notes**

- `from_pot_id`/`to_pot_id` nullable — external world represented as NULL.
- `amount` for `transfer` scales to `to_pot` by `exchange_rate`; for all other kinds raw.
- `books_amount` is always in BDT — computed as `amount × books_rate` at insert time.

---

### 3.6 `bill_kind_registry`

**Purpose:** Discovery table. Enumerates every legal bill kind. Adding a new kind = one INSERT here. No code change.

```sql
CREATE TABLE public.bill_kind_registry (
  kind              text PRIMARY KEY,
  numbering_prefix  text NOT NULL,
  default_status    text NOT NULL DEFAULT 'draft',
  can_be_issued     boolean NOT NULL DEFAULT true,
  can_be_paid       boolean NOT NULL DEFAULT true,
  required_meta     text[] NOT NULL DEFAULT '{}',
  description       text,
  is_active         boolean NOT NULL DEFAULT true,
  created_at        timestamptz NOT NULL DEFAULT now()
);
```

**Columns**

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `kind` | text | no | — | PK; e.g. `sales_invoice_wholesale` |
| `numbering_prefix` | text | no | — | `INV-WS`, `AP-SC`, `CN`, `DN`, … |
| `default_status` | text | no | `draft` | |
| `can_be_issued` | boolean | no | `true` | |
| `can_be_paid` | boolean | no | `true` | |
| `required_meta` | text[] | no | `{}` | Keys validated by `rpc_create_bill` |
| `description` | text | yes | — | |
| `is_active` | boolean | no | `true` | |
| `created_at` | timestamptz | no | `now()` | |

**Constraints**

| Name | Definition |
|---|---|
| PK | `kind` |

**Indexes**

| Name | Columns | Purpose |
|---|---|---|
| (PK) | `kind` | — |

**Seed data (required):**

```sql
INSERT INTO public.bill_kind_registry
  (kind, numbering_prefix, required_meta, can_be_paid, description) VALUES
  ('sales_invoice_wholesale', 'INV-WS', '{}',                    true,  'Wholesale sales invoice'),
  ('sales_invoice_retail',    'INV-RT', '{retail_billing_mode}', true,  'Retail sales invoice'),
  ('sales_invoice_dropship',  'INV-DS', '{}',                    true,  'Dropship sales invoice'),
  ('shipment_cost_ap',        'AP-SC',  '{ap_kind, shipment_id}',true,  'Shipment cost AP bill'),
  ('dropship_courier_ap',     'AP-DC',  '{}',                    true,  'Dropship courier AP bill'),
  ('credit_note',             'CN',     '{reason}',              false, 'Credit note — document-apply only; parent_bill_id required'),
  ('debit_note',              'DN',     '{reason}',              true,  'Debit note — normal bill; pay with cash (not document-apply)');
```


---

### 3.7 `invoice_no_counters`

**Purpose:** Per-tenant, per-prefix sequence allocation. Atomic, race-free. Powers `rpc_allocate_invoice_no`.

```sql
CREATE TABLE public.invoice_no_counters (
  tenant_id  bigint NOT NULL,
  prefix     text   NOT NULL,
  next_seq   bigint NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, prefix)
);
```

**Columns**

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `tenant_id` | bigint | no | — | |
| `prefix` | text | no | — | e.g. `INV-WS` |
| `next_seq` | bigint | no | `1` | Next sequence to assign |

**Constraints**

| Name | Definition |
|---|---|
| PK | `(tenant_id, prefix)` |

**Indexes**

| Name | Columns | Purpose |
|---|---|---|
| (PK) | `(tenant_id, prefix)` | — |

**Notes**

- No FK to `tenants` or `bill_kind_registry` — this is a hot-path counter, and enforcing FKs would add latency. `rpc_create_bill` rejects unknown kinds before touching this table.

---

### 3.8 `bills`

**Purpose:** The business document being paid. Invoices, bills, credit notes, debit notes, and any future document kind. One row per document.

```sql
CREATE TABLE public.bills (
  id                    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id             bigint NOT NULL,
  issued_by_tenant_id   bigint NOT NULL,

  kind                  text NOT NULL REFERENCES public.bill_kind_registry(kind),
  status                text NOT NULL DEFAULT 'draft'
                        CHECK (status IN
                          ('draft','issued','partial','paid','voided','written_off')),

  invoice_no            text,
  request_hash          text,
  invoice_date          date NOT NULL DEFAULT CURRENT_DATE,
  due_date              date,

  from_profile_id       bigint,
  to_profile_id         bigint,
  counterparty_profile_id bigint,
  counterparty_tenant_id  bigint,

  currency_code         text   NOT NULL DEFAULT 'BDT',
  total_amount          numeric(18,4) NOT NULL DEFAULT 0,
  paid_amount           numeric(18,4) NOT NULL DEFAULT 0,
  due_amount            numeric(18,4) NOT NULL DEFAULT 0,
  written_off_amount    numeric(18,4) NOT NULL DEFAULT 0,

  parent_bill_id        bigint REFERENCES public.bills(id),

  source_type           text,
  source_id             text,
  source_key            text,
  idempotency_key       text,

  meta                  jsonb NOT NULL DEFAULT '{}'::jsonb,
  note                  text,

  created_by            uuid,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT chk_amounts_non_negative
    CHECK (total_amount >= 0 AND paid_amount >= 0 AND due_amount >= 0 AND written_off_amount >= 0),
  CONSTRAINT chk_bill_amount_identity
    CHECK (
      status = 'voided'
      OR paid_amount + due_amount + written_off_amount = total_amount
    ),
  CONSTRAINT chk_bills_meta_size CHECK (pg_column_size(meta) < 8192)
);

CREATE UNIQUE INDEX uq_bills_invoice_no
  ON public.bills (tenant_id, invoice_no)
  WHERE invoice_no IS NOT NULL;

CREATE UNIQUE INDEX uq_bills_idempotency
  ON public.bills (tenant_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;
```

**Columns**

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | bigint | no | identity | PK |
| `tenant_id` | bigint | no | — | Books owner (may be parent) |
| `issued_by_tenant_id` | bigint | no | — | Who issued (may be child) |
| `kind` | text | no | — | FK → `bill_kind_registry` |
| `status` | text | no | `draft` | `draft` / `issued` / `partial` / `paid` / `voided` / `written_off` |
| `invoice_no` | text | yes | — | Null on draft; allocated at `rpc_issue_bill` |
| `request_hash` | text | yes | — | Idempotency conflict detection |
| `invoice_date` | date | no | `CURRENT_DATE` | |
| `due_date` | date | yes | — | |
| `from_profile_id` | bigint | yes | — | Payer / debtor (required before issue) |
| `to_profile_id` | bigint | yes | — | Payee / creditor (required before issue) |
| `counterparty_profile_id` | bigint | yes | — | Denorm “other party” for lists |
| `counterparty_tenant_id` | bigint | yes | — | |
| `currency_code` | text | no | `BDT` | |
| `total_amount` | numeric(18,4) | no | `0` | = `SUM(bill_lines.line_total)` (enforced by RPC) |
| `paid_amount` | numeric(18,4) | no | `0` | Trigger-written |
| `due_amount` | numeric(18,4) | no | `0` | Trigger-written |
| `written_off_amount` | numeric(18,4) | no | `0` | |
| `parent_bill_id` | bigint | yes | — | For credit/debit notes |
| `source_type` | text | yes | — | External pointer type |
| `source_id` | text | yes | — | |
| `source_key` | text | yes | — | |
| `idempotency_key` | text | yes | — | |
| `meta` | jsonb | no | `{}` | Kind-specific fields |
| `note` | text | yes | — | |
| `created_by` | uuid | yes | — | |
| `created_at` | timestamptz | no | `now()` | |
| `updated_at` | timestamptz | no | `now()` | |

**Constraints**

| Name | Definition | Enforced by |
|---|---|---|
| PK | `id` | — |
| UQ | `uq_bills_invoice_no` `(tenant_id, invoice_no)` WHERE `invoice_no IS NOT NULL` | — |
| CHK | `status IN (...)` | — |
| CHK | `chk_amounts_non_negative` | — |
| CHK | `chk_bill_amount_identity` (`voided` OR `paid+due+written_off=total`) | — |
| (implicit) | structural columns frozen after issue | `trg_bills_guard_financial_spine` |

**Foreign Keys**

| Column | → Target | On Delete |
|---|---|---|
| `kind` | `bill_kind_registry.kind` | (default — RESTRICT) |
| `parent_bill_id` | `bills.id` (self) | (default — RESTRICT) |

**Indexes**

| Name | Columns | Type | Purpose |
|---|---|---|---|
| (PK) | `id` | btree | — |
| UQ | `(tenant_id, invoice_no)` | btree | Invoice number uniqueness |
| `uq_bills_idempotency` | `(tenant_id, idempotency_key)` WHERE `idempotency_key IS NOT NULL` | btree | Permanent idempotency |
| `uq_bills_source_key` | `(tenant_id, source_type, source_id, COALESCE(source_key,''))` WHERE `source_type IS NOT NULL AND status <> 'voided'` | btree | Natural key for AP |
| `ix_bills_tenant_status_kind` | `(tenant_id, status, kind)` | btree | List filtering |
| `ix_bills_counterparty` | `(counterparty_profile_id)` WHERE `IS NOT NULL` | btree | Statement queries |
| `ix_bills_parent` | `(parent_bill_id)` WHERE `IS NOT NULL` | btree | Credit/debit note linkage |
| `ix_bills_source` | `(tenant_id, source_type, source_id)` WHERE `source_type IS NOT NULL` | btree | Source lookups |
| `ix_bills_meta_gin` | `meta` | GIN (jsonb_path_ops) | `meta @> '{"shipment_id": 123}'` |

---

### 3.9 `bill_lines`

**Purpose:** Line items of a bill. Products, services, charges, adjustments. One row per line.

```sql
CREATE TABLE public.bill_lines (
  id             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id      bigint NOT NULL,
  bill_id        bigint NOT NULL REFERENCES public.bills(id) ON DELETE CASCADE,
  line_no        int    NOT NULL,
  item_kind      text   NOT NULL DEFAULT 'stock',
  product_id     bigint,
  description    text   NOT NULL,
  quantity       numeric(18,4) NOT NULL DEFAULT 1,
  unit_price     numeric(18,4) NOT NULL DEFAULT 0,
  line_total     numeric(18,4) NOT NULL DEFAULT 0,
  meta           jsonb  NOT NULL DEFAULT '{}'::jsonb,
  created_at     timestamptz NOT NULL DEFAULT now(),

  UNIQUE (bill_id, line_no),
  CHECK (quantity >= 0 AND unit_price >= 0 AND line_total >= 0)
);
```

**Columns**

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | bigint | no | identity | PK |
| `tenant_id` | bigint | no | — | Denormalized from `bills` |
| `bill_id` | bigint | no | — | FK |
| `line_no` | int | no | — | Position in bill |
| `item_kind` | text | no | `stock` | `stock` / `service` / `charge` / `adjustment` |
| `product_id` | bigint | yes | — | Optional FK (products table external to spine) |
| `description` | text | no | — | |
| `quantity` | numeric(18,4) | no | `1` | |
| `unit_price` | numeric(18,4) | no | `0` | |
| `line_total` | numeric(18,4) | no | `0` | `= qty × unit_price` for stock; may differ for charges |
| `meta` | jsonb | no | `{}` | `shipment_item_id`, `barcode`, `assigned_child_tenant_id`, etc. |
| `created_at` | timestamptz | no | `now()` | |

**Constraints**

| Name | Definition |
|---|---|
| PK | `id` |
| UQ | `(bill_id, line_no)` |
| CHK | `quantity >= 0 AND unit_price >= 0 AND line_total >= 0` |

**Foreign Keys**

| Column | → Target | On Delete |
|---|---|---|
| `bill_id` | `bills.id` | CASCADE |

**Indexes**

| Name | Columns | Type | Purpose |
|---|---|---|---|
| (PK) | `id` | btree | — |
| UQ | `(bill_id, line_no)` | btree | Line ordering |
| `ix_bill_lines_bill` | `(bill_id)` | btree | Bill detail |
| `ix_bill_lines_product` | `(product_id)` WHERE `IS NOT NULL` | btree | Product history |

**Notes**

- `line_total` is NOT auto-computed. For stock lines, `rpc_create_bill` validates `line_total = qty × unit_price`. For charge lines, caller-supplied.
- `shipment_item_id` moves to `meta` — enables the shipment report to join `bill_lines.meta->>'shipment_item_id'` to `global_shipment_items.id`.

---

### 3.10 `bill_settlements`

**Purpose:** Links a bill to cash (`pay`) or to another bill (`document`, e.g. credit note apply). Immutable (delete via RPC only).

```sql
CREATE TABLE public.bill_settlements (
  id                     bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id              bigint NOT NULL REFERENCES public.tenants(id),
  bill_id                bigint NOT NULL REFERENCES public.bills(id) ON DELETE RESTRICT,
  settlement_kind        text NOT NULL CHECK (settlement_kind IN ('pay','document')),
  pays_id                bigint REFERENCES public.pays(id) ON DELETE RESTRICT,
  source_bill_id         bigint REFERENCES public.bills(id) ON DELETE RESTRICT,
  allocated_amount       numeric(18,4) NOT NULL CHECK (allocated_amount > 0),
  allocated_books_amount numeric(18,4) CHECK (
    settlement_kind = 'document' OR allocated_books_amount > 0
  ),
  idempotency_key        text,
  request_hash           text,
  created_by             uuid,
  created_at             timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT chk_settlement_pay
    CHECK (settlement_kind <> 'pay' OR pays_id IS NOT NULL),
  CONSTRAINT chk_settlement_document
    CHECK (settlement_kind <> 'document' OR (pays_id IS NULL AND source_bill_id IS NOT NULL)),
  CONSTRAINT chk_settlement_document_not_self
    CHECK (source_bill_id IS NULL OR source_bill_id <> bill_id)
);

CREATE UNIQUE INDEX uq_settle_bill_pays
  ON public.bill_settlements (bill_id, pays_id)
  WHERE pays_id IS NOT NULL;

-- Void/update pays look up settlements by pays_id alone (uq leading col is bill_id)
CREATE INDEX ix_settle_pays
  ON public.bill_settlements (pays_id)
  WHERE pays_id IS NOT NULL;

-- No unique on (bill_id, source_bill_id): same credit_note may apply to one
-- target in multiple partial document settlements.
CREATE INDEX ix_settle_source
  ON public.bill_settlements (source_bill_id)
  WHERE source_bill_id IS NOT NULL;

CREATE UNIQUE INDEX uq_settle_idempotency
  ON public.bill_settlements (tenant_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;
```

**Columns**

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | bigint | no | identity | PK |
| `tenant_id` | bigint | no | — | |
| `bill_id` | bigint | no | — | **Target** bill (due reduced) |
| `settlement_kind` | text | no | — | `pay` \| `document` |
| `pays_id` | bigint | yes | — | Required when `pay` |
| `source_bill_id` | bigint | yes | — | credit_note bill when `document` |
| `allocated_amount` | numeric(18,4) | no | — | In **target bill** currency |
| `allocated_books_amount` | numeric(18,4) | yes | — | BDT for `pay`; null for `document` (convert in RPC if needed) |
| `idempotency_key` | text | yes | — | Unique per tenant when set (document apply / retries) |

**Notes**

- `pay`: `fn_bill_settle_apply` updates **target** `bill_id` only; pots via `pays`.
- `document`: updates **target** `bill_id` and **source** `source_bill_id` (CN consumed).
- D1 (I7): overalloc check only for `settlement_kind = 'pay'`.
- Indexes: `uq_settle_bill_pays`, `ix_settle_pays` (void/update by pays_id), `ix_settle_source`, `uq_settle_idempotency`.

---

### 3.11 `bill_events`

**Purpose:** Append-only lifecycle stream. Every bill state transition writes one row here. Single source of truth for reporting and audit.

```sql
CREATE TABLE public.bill_events (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id   bigint NOT NULL,
  bill_id     bigint NOT NULL REFERENCES public.bills(id) ON DELETE CASCADE,
  event_type  text NOT NULL
              CHECK (event_type IN
                ('created','issued','voided','payment_applied','payment_reversed',
                 'written_off','updated')),
  payload     jsonb NOT NULL DEFAULT '{}'::jsonb,
  actor_id    uuid,
  created_at  timestamptz NOT NULL DEFAULT now()
);
```

**Columns**

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | bigint | no | identity | PK |
| `tenant_id` | bigint | no | — | Denormalized from `bills` |
| `bill_id` | bigint | no | — | FK |
| `event_type` | text | no | — | Enumerated (see CHECK) |
| `payload` | jsonb | no | `{}` | Kind-specific event detail |
| `actor_id` | uuid | yes | — | `auth.uid()` |
| `created_at` | timestamptz | no | `now()` | |

**Constraints**

| Name | Definition | Enforced by |
|---|---|---|
| PK | `id` | — |
| CHK | `event_type IN (...)` | — |
| (implicit) | append-only — no UPDATE or DELETE | `trg_bill_events_no_update` (Triggers below) |

**Foreign Keys**

| Column | → Target | On Delete |
|---|---|---|
| `bill_id` | `bills.id` | CASCADE |

**Indexes**

| Name | Columns | Purpose |
|---|---|---|
| (PK) | `id` | — |
| `ix_bill_events_bill` | `(bill_id, created_at DESC)` | Timeline per bill |
| `ix_bill_events_tenant` | `(tenant_id, event_type, created_at DESC)` | Tenant-level reports |
| `ix_bill_events_type` | `(event_type, created_at DESC)` | Cross-tenant analysis |

**Event priority rule (enforced by trigger):**

When a single UPDATE changes multiple things, only the highest-priority event is emitted
(same order as `fn_bill_events_from_bills` / §4.2):

0. `voided` (status → voided wins even if due/written_off cleared in same UPDATE)
1. `payment_applied` / `payment_reversed` (money delta)
2. `written_off` (write-off delta)
3. `issued` (status → issued only)

**No double-counting.**

---

### 3.12 `books_exchange_rates`

**Purpose:** Historical FX snapshots for reporting and downstream modules. Not used by the money spine — `pays.exchange_rate` and `pays.books_amount` are stored snapshots at transaction time.

```sql
CREATE TABLE public.books_exchange_rates (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id           bigint NOT NULL,
  base_currency_code  text   NOT NULL DEFAULT 'BDT',
  quote_currency_code text   NOT NULL,
  rate                numeric(18,6) NOT NULL,
  rate_date           timestamptz NOT NULL DEFAULT now(),
  source              text   NOT NULL DEFAULT 'manual',
  created_at          timestamptz NOT NULL DEFAULT now()
);
```

**Columns**

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| `id` | bigint | no | identity | PK |
| `tenant_id` | bigint | no | — | |
| `base_currency_code` | text | no | `BDT` | |
| `quote_currency_code` | text | no | — | |
| `rate` | numeric(18,6) | no | — | 1 unit base = `rate` units quote |
| `rate_date` | timestamptz | no | `now()` | |
| `source` | text | no | `manual` | `manual` / `vendor` / `central_bank` / … |
| `created_at` | timestamptz | no | `now()` | |

**Constraints**

| Name | Definition |
|---|---|
| PK | `id` |

**Foreign Keys**

None.

**Indexes**

| Name | Columns | Purpose |
|---|---|---|
| (PK) | `id` | — |

**Notes**

- Standalone — not referenced by any spine table.
- Used by reporting layer for back-office rate lookups and historical revaluation.

---

## 4. Table Summary

| # | Table | Rows of concern | FK out | FK in | Append-only |
|---|---|---|---|---|---|
| 1 | `profiles` | — | 0 | 0 | no |
| 2 | `cashbook_accounts` | — | 1 (`default_cashbook_point_pot_id`) | 1 (`cashbook_points`) | no |
| 3 | `cashbook_points` | — | 1 | 1 (`cashbook_point_pots`) | no |
| 4 | `cashbook_point_pots` | — | 1 | 2 (`pays.from`, `pays.to`) | amount only |
| 5 | `pays` | Movement | 2 | 1 (`bill_settlements`) | effective |
| 6 | `bill_kind_registry` | Kinds (≤ 100) | 0 | 1 (`bills`) | no |
| 7 | `invoice_no_counters` | Sequences | 0 | 0 | no |
| 8 | `bills` | **High** `[ASSUMPTION]` relative concern, not measured | 2 (`kind`, `parent_bill_id`) | 2 (`bill_lines`, `bill_events`) + 1 (`bill_settlements`) | partial (guard) |
| 9 | `bill_lines` | **High** (10× bills) `[ASSUMPTION]` | 1 | 0 | no |
| 10 | `bill_settlements` | Medium | 3 | 0 | immutable |
| 11 | `bill_events` | **Very high** (5× bills) `[ASSUMPTION]` | 1 | 0 | yes |
| 12 | `books_exchange_rates` | — | 0 | 0 | no |

**Dropped from old design (not recreated):** `money_purposes`, `cashbook_entries`, `pay_allocations`, `pay_instruments`.

**Why dropped (alternatives):** spine truth is pot `amount` + `pays` + `bill_settlements` — not a parallel entry ledger. See [00-overview.md](00-overview.md) Alternatives. `[TODO-ARCH: link prior ADR if one exists for cashbook_entries removal — owner, date]`

**P3 clarification:** “Balances are never written directly” means **`cashbook_point_pots.amount`** (T3 + T1). It does **not** claim the unused account header balance columns are trigger-maintained. `[CORRECTED: P3 scope = pot.amount only; account header cols are non-spine]`


---

## 5. Deployment Order

Migrations must run in this exact order:

```
000  public.tenants            (prerequisite — see deploy note on bill_settlements.tenant_id FK)
001  currencies
002  profiles
003  cashbook_accounts       (without default_cashbook_point_pot_id FK)
004  cashbook_points
005  cashbook_point_pots
006  ALTER cashbook_accounts ADD FK → cashbook_point_pots
007  pays
008  bill_kind_registry + seed
009  invoice_no_counters
010  bills
011  bill_lines
012  bill_settlements
013  bill_events
014  books_exchange_rates
015  money_outbox
```

**Then:** triggers (below) → [02-actions.md](02-actions.md).

---

## Triggers

8 core + 6 supporting + 1 deferred + delete/truncate guards. Application code never writes balance columns.

The money spine enforces its invariants through these triggers. Together they are the only mechanism that:
- Writes pot balances
- Writes bill paid/due/status
- Emits lifecycle events
- Freezes structural columns
- Rejects illegal mutations

**Application code never writes balance columns. Triggers do.**

---

## 2. Trigger Inventory

### 2.1 Core triggers (the 8)

| # | Trigger name | Table | Timing | Purpose |
|---|---|---|---|---|
| T1 | `trg_pays_apply` | `pays` | AFTER INSERT, AFTER UPDATE OF status | Applies/reverses pot balances; sets `money.pot_writer`; writes balance snapshots |
| T2 | `trg_pays_guard_immutable` | `pays` | BEFORE UPDATE | Only `posted → voided`; `idempotency_key` immutable; `meta` add-only |
| T3 | `trg_pot_guard` | `cashbook_point_pots` | BEFORE INSERT, BEFORE UPDATE OF amount | INSERT: `amount=0`; UPDATE: requires `money.pot_writer` |
| T4 | `trg_bills_guard_financial_spine` | `bills` | BEFORE UPDATE | Freezes structural cols; settlement EXISTS only when `total_amount`/`due_date` change |
| T5 | `trg_bill_events_no_update` | `bill_events` | BEFORE UPDATE OR DELETE | Append-only enforcement |
| T6 | `trg_bill_events_from_bills` | `bills` | AFTER INSERT, AFTER UPDATE | One lifecycle event; payment payload includes settlement id/kind |
| T7 | `trg_bill_settle_apply` | `bill_settlements` | AFTER INSERT, AFTER DELETE | Updates bill paid/due/status (exact arithmetic) |
| T8 | `trg_bill_lines_guard` | `bill_lines` | BEFORE INSERT, UPDATE, DELETE | No line mutations when bill not `draft`; at issue Σ lines = total |

### 2.2 Supporting triggers

| # | Trigger name | Table | Timing | Purpose |
|---|---|---|---|---|
| S1 | `trg_bill_settlements_immutable` | `bill_settlements` | BEFORE UPDATE | Reject in-place edits (void + re-insert only) |
| S2 | `trg_validate_profile_link` | `cashbook_accounts` | BEFORE INSERT, BEFORE UPDATE | Enforce `profile_id = entity_id` when `entity_type='profile'` |
| S3 | `trg_validate_default_pot` | `cashbook_accounts` | BEFORE INSERT, BEFORE UPDATE OF default_cashbook_point_pot_id | Enforce default pot belongs to this account |
| S4 | `trg_provision_profile_cashbook` | `profiles` | AFTER INSERT | Auto-create profile's cashbook + main point + BDT pot |
| S5 | `trg_bill_settlements_pay_guard` | `bill_settlements` | BEFORE INSERT | I31 pay settlements; I29 document party swap |
| S6 | `trg_tenant_id_immutable` | all kernel tables | BEFORE UPDATE OF tenant_id | Reject tenant_id changes |
| G1 | `trg_deny_dml_pays_bills` | `pays`, `bills`, `bill_settlements` | BEFORE DELETE, BEFORE TRUNCATE | Reject unless RPC/session flag |

### 2.3 Deferred constraint

| # | Name | Table | Type | Purpose |
|---|---|---|---|---|
| D1 | `trg_check_pays_overalloc` | `bill_settlements` | CONSTRAINT TRIGGER (deferred) | Σ allocated_books per pays ≤ pays.books_amount |

### 2.4 Required extensions

`cashbook_point_pots.tenant_id` on insert must derive from `cashbook_point_id → cashbook_points → cashbook_accounts`. Ensure the `INSERT` for pots includes `tenant_id` (see §3.4 above).

---

## 3. Execution Order

### 3.1 INSERT into `pays`

```
1. FK: from_pot_id, to_pot_id → cashbook_point_pots
2. CHECK: kind, amount > 0, status, from/to not both null
3. UNIQUE: (tenant_id, idempotency_key)
4. INSERT happens
5. T1 trg_pays_apply (AFTER INSERT) →
   if status = 'posted':
     UPDATE pot(from).amount -= amount         (if from not null)
     UPDATE pot(to).amount   += amount × rate  (if to not null)
       (rate = 1 for all kinds except 'transfer')
   UPDATEs on pots trigger T3 trg_pot_guard → allow (pg_trigger_depth > 1)
```

### 3.2 UPDATE on `pays` (posted → voided)

```
1. FK: none new
2. CHECK: status must be in enum
3. T2 trg_pays_guard_immutable (BEFORE UPDATE) →
   verify only status, voided_at, meta, updated_at changed
   (any change to amount/pots/currency/rate/books_amount/kind/tenant_id → EXCEPTION)
4. UPDATE applies
5. T1 trg_pays_apply (AFTER UPDATE OF status) →
   if NEW.status = 'voided' AND OLD.status = 'posted':
     UPDATE pot(from).amount += OLD.amount
     UPDATE pot(to).amount   -= OLD.amount × OLD.rate
```

### 3.3 UPDATE on `pays` (posted → posted, no change)

Trigger T2 **rejects** all changes to a posted pays except the void transition. If code tries to `UPDATE pays SET amount = ...`:
- T2 fires
- Detects `NEW.amount <> OLD.amount`
- Raises `EXCEPTION`

### 3.4 INSERT into `bill_settlements`

```
1. FK: tenant_id → tenants, bill_id → bills, pays_id → pays
2. CHECK: allocated_amount > 0, allocated_books_amount > 0
3. UNIQUE: (bill_id, pays_id)
4. INSERT happens
5. T7 trg_bill_settle_apply (AFTER INSERT) →
   one UPDATE bills SET paid/due/status/updated_at
6. That UPDATE triggers T4 (BEFORE) and T6 (AFTER) once:
   - T4: allow (paid_amount/due_amount/status/updated_at)
   - T6: emit 'payment_applied' (paid delta wins over status)
7. Deferred: D1 trg_check_pays_overalloc runs at COMMIT →
   verify Σ allocated_books per pays ≤ pays.books_amount + tolerance
```

### 3.5 DELETE from `bill_settlements` (via void path)

```
1. DELETE happens
2. T7 trg_bill_settle_apply (AFTER DELETE) →
   one UPDATE bills SET paid/due/status/updated_at
3. bills UPDATE triggers T4 (allow) and T6 (emit 'payment_reversed')
```

### 3.6 UPDATE on `bills` (issue: draft → issued)

```
1. FK: kind → bill_kind_registry
2. CHECK: status enum, amounts non-negative, paid+due ≤ total+written_off
3. T4 trg_bills_guard_financial_spine (BEFORE UPDATE) →
   OLD.status = 'draft', NEW.status = 'issued' → ALLOW (guard checks only issued → * transitions)
   (checks totals freeze only if settlements exist — none on a fresh draft)
4. UPDATE applies
5. T6 trg_bill_events_from_bills (AFTER UPDATE) →
   detect status change → emit 'issued' event
```

### 3.7 UPDATE on `bills` (write-off)

```
1. T4 trg_bills_guard_financial_spine (BEFORE UPDATE) →
   written_off_amount changed → ALLOW
   due_amount changed → ALLOW (trigger-driven, not app-driven — see §4.3)
2. UPDATE applies
3. T6 trg_bill_events_from_bills (AFTER UPDATE) →
   detect written_off_amount change → emit 'written_off' event
   (priority: written_off > status; do NOT also emit a status event)
```

### 3.8 UPDATE on `bills` (void with payment reversal)

Voiding a bill (`rpc_void_bill`, reverse=true):

```
1. Refuse if any linked pays also settles a *different* bill (multi-bill pays)
2. For each settlement on this bill: rpc_void_pays / rpc_void_document_settlement
   (void_pays deletes all pay settlements for that pays_id + reverses pots)
3. For CN source rows: void document settlements
4. UPDATE bills SET status='voided', due_amount=0, written_off_amount=0
   → T6 emits `voided` (priority 0; ignores due/written_off clear in same row)
```

### 3.9 UPDATE on `bills` (illegal edit after issue)

```
1. Code: UPDATE bills SET total_amount = ... WHERE id = X (already issued)
2. T4 trg_bills_guard_financial_spine (BEFORE UPDATE) →
   OLD.status = 'issued' AND structural column changed → EXCEPTION
```

---

## 4. Trigger Interaction Matrix

### 4.1 Which trigger fires on which action

| Action | T1 | T2 | T3 | T4 | T5 | T6 | T7 | S1 | D1 |
|---|---|---|---|---|---|---|---|---|---|
| INSERT pays | ✅ | — | (indirect on pot) | — | — | — | — | — | — |
| UPDATE pays (void) | ✅ | ✅ | (indirect on pot) | — | — | — | — | — | — |
| UPDATE pays (edit) | — | ✅ rejects | — | — | — | — | — | — | — |
| INSERT bill_settlements | — | — | — | (indirect on bills) | — | (indirect on bills) | ✅ | — | deferred |
| DELETE bill_settlements | — | — | — | (indirect on bills) | — | (indirect on bills) | ✅ | — | — |
| UPDATE bill_settlements | — | — | — | — | — | — | — | ✅ rejects | — |
| INSERT bills | — | — | — | — | — | ✅ 'created' | — | — | — |
| UPDATE bills (issue) | — | — | — | ✅ | — | ✅ 'issued' | — | — | — |
| UPDATE bills (payment) | — | — | — | ✅ (via T7) | — | ✅ 'payment_applied' | (from T7) | — | — |
| UPDATE bills (write-off) | — | — | — | ✅ | — | ✅ 'written_off' | — | — | — |
| UPDATE bills (void) | — | — | — | ✅ | — | ✅ 'voided' | — | — | — |
| UPDATE bills (structural, post-issue) | — | — | — | ✅ rejects | — | — | — | — | — |
| UPDATE pot amount directly | — | — | ✅ rejects | — | — | — | — | — | — |
| INSERT bill_events | — | — | — | — | — | — | — | — | — |
| UPDATE bill_events | — | — | — | — | ✅ rejects | — | — | — | — |
| DELETE bill_events | — | — | — | — | ✅ rejects | — | — | — | — |

### 4.2 Priority rules

**For `bills` UPDATE, T6 emits one and only one event:**

If multiple deltas are detected in a single UPDATE, priority is (must match `fn_bill_events_from_bills`):

```
0. voided                               (status → voided; wins over due/written_off clear)
1. payment_applied / payment_reversed   (paid_amount changed)
2. written_off                          (written_off_amount changed)
3. issued                               (status → issued only; partial/paid/written_off status alone = no event)
```

T6 **returns immediately** after the first matching case. This prevents double-counting.

**Reason:** when `fn_bill_settle_apply` (T7) updates both `paid_amount` and `status`, only `payment_applied` fires — not also a status event. Void must beat written_off/due clears in the same `rpc_void_bill` UPDATE.

### 4.3 Trigger depth and T3's safety check

`fn_pays_apply` (T1) and `fn_bill_settle_apply` (T7) both UPDATE tables that have guard triggers.

The guards use `pg_trigger_depth() > 1` to detect "I'm running inside another trigger, allow this write."

- Direct app `UPDATE cashbook_point_pots SET amount = ...` → `pg_trigger_depth() = 1` → T3 rejects
- `fn_pays_apply` runs → `pg_trigger_depth() = 1` → inside fn, UPDATE pot → `pg_trigger_depth() = 2` → T3 allows

This works **as long as the application role does not have `CREATE TRIGGER` privilege** on the schema. On Supabase, that's the default. On a self-hosted Postgres where `authenticated` has `CREATE TRIGGER`, the guard can be bypassed by dropping the trigger — but if you trust the role not to drop triggers, you're already at a higher privilege level and the check is not the last line of defense anyway.

### 4.4 Deferred constraint ordering

`trg_check_pays_overalloc` (D1) is a `CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY DEFERRED`. It runs **at COMMIT**, after every other trigger. This means:

- `rpc_pay_bill` can insert a settlement for pays A to bill X
- Then in the same transaction, insert another settlement for pays A to bill Y
- The check runs once at COMMIT, summing all settlements for pays A

This enables atomic multi-bill payments in one transaction.

---

## 5. Full DDL

### 5.1 T1 — `trg_pays_apply`

**Applied pot balance movements.**

```sql
CREATE OR REPLACE FUNCTION public.fn_pays_apply()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_to_credit numeric(18,4);
BEGIN
  IF TG_OP = 'INSERT' AND NEW.status = 'posted' THEN
    -- Debit from-pot (must have funds — defense beyond RPC checks)
    IF NEW.from_pot_id IS NOT NULL THEN
      UPDATE public.cashbook_point_pots
         SET amount     = amount - NEW.amount,
             updated_at = now()
       WHERE id = NEW.from_pot_id
         AND amount >= NEW.amount;
      IF NOT FOUND THEN
        RAISE EXCEPTION
          'insufficient_balance: pot % cannot cover pays % amount %',
          NEW.from_pot_id, NEW.id, NEW.amount;
      END IF;
    END IF;

    -- Credit to-pot (transfer uses rounded amount×rate — must match void)
    IF NEW.to_pot_id IS NOT NULL THEN
      v_to_credit := CASE
        WHEN NEW.kind = 'transfer' THEN round(NEW.amount * NEW.exchange_rate, 4)
        ELSE                            NEW.amount
      END;
      UPDATE public.cashbook_point_pots
         SET amount     = amount + v_to_credit,
             updated_at = now()
       WHERE id = NEW.to_pot_id;
    END IF;
  END IF;

  IF TG_OP = 'UPDATE'
     AND NEW.status = 'voided'
     AND OLD.status = 'posted' THEN
    -- Reverse from-pot debit
    IF OLD.from_pot_id IS NOT NULL THEN
      UPDATE public.cashbook_point_pots
         SET amount     = amount + OLD.amount,
             updated_at = now()
       WHERE id = OLD.from_pot_id;
    END IF;

    -- Reverse to-pot credit (same rounded expression as insert)
    IF OLD.to_pot_id IS NOT NULL THEN
      v_to_credit := CASE
        WHEN OLD.kind = 'transfer' THEN round(OLD.amount * OLD.exchange_rate, 4)
        ELSE                            OLD.amount
      END;
      UPDATE public.cashbook_point_pots
         SET amount     = amount - v_to_credit,
             updated_at = now()
       WHERE id = OLD.to_pot_id
         AND amount >= v_to_credit;
      IF NOT FOUND THEN
        RAISE EXCEPTION
          'insufficient_balance: cannot void pays %; to_pot % missing credit %',
          OLD.id, OLD.to_pot_id, v_to_credit;
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_pays_apply
  AFTER INSERT OR UPDATE OF status ON public.pays
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_pays_apply();
```

**Invariants it enforces:**
- Every posted pays moves pot balances by exactly its own `amount` (or `amount × exchange_rate` for transfer → to-pot)
- Voiding a pays reverses exactly the same deltas
- The `updated_at` of touched pots advances

**`kind=payment`:** both pots must match `bills.currency_code` and use `exchange_rate=1` (`rpc_pay_bill`). Cross-currency movement is **`transfer`** only; bill pay happens after pots share the bill currency.

**Failure modes:**
- If `NEW.amount` is NULL → CHECK constraint rejects before INSERT
- If both pots NULL → CHECK rejects
- If reversing pushes pot negative → CHECK on pot rejects (this only happens if data was corrupted earlier)

---

### 5.2 T2 — `trg_pays_guard_immutable`

**Pays rows are immutable once posted. Only `posted → voided` is allowed, and only specific fields may change during that transition.**

```sql
CREATE OR REPLACE FUNCTION public.fn_pays_guard_immutable()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Already voided → no further changes at all
  IF OLD.status = 'voided' THEN
    RAISE EXCEPTION 'pays % is voided and cannot be updated', OLD.id;
  END IF;

  -- OLD.status = 'posted' from here.
  -- Allow only void transition, and only status/voided_at/meta/updated_at may change.
  IF NEW.status = 'voided' THEN
    IF NEW.amount           <> OLD.amount
       OR NEW.from_pot_id   IS DISTINCT FROM OLD.from_pot_id
       OR NEW.to_pot_id     IS DISTINCT FROM OLD.to_pot_id
       OR NEW.currency_code <> OLD.currency_code
       OR NEW.exchange_rate <> OLD.exchange_rate
       OR NEW.books_amount  <> OLD.books_amount
       OR NEW.kind          <> OLD.kind
       OR NEW.tenant_id     <> OLD.tenant_id
       OR NEW.payment_date  <> OLD.payment_date
       OR NEW.created_by    IS DISTINCT FROM OLD.created_by
       OR NEW.refs          IS DISTINCT FROM OLD.refs THEN
      RAISE EXCEPTION
        'void pays % may only change status, voided_at, meta, updated_at', OLD.id;
    END IF;
    RETURN NEW;
  END IF;

  -- Any other UPDATE (posted → posted) is forbidden
  RAISE EXCEPTION
    'posted pays % is immutable; use rpc_update_pays (void + recreate) for corrections', OLD.id;
END;
$$;

CREATE TRIGGER trg_pays_guard_immutable
  BEFORE UPDATE ON public.pays
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_pays_guard_immutable();
```

**Invariants it enforces:**
- No in-place edit of any financial field on a posted pays
- Void is one-way (`posted → voided`, never back)
- Voided pays are read-only forever

**Failure modes:**
- `UPDATE pays SET amount = 100` → EXCEPTION
- `UPDATE pays SET status = 'voided', amount = 100` → EXCEPTION (amount changed)
- `UPDATE pays SET status = 'voided', voided_at = now(), meta = ...` → allowed

---

### 5.3 T3 — `trg_pot_guard`

**Pot `amount` is written only by `fn_pays_apply`, never directly. New pots start at zero (I36).**

```sql
CREATE OR REPLACE FUNCTION money_kernel.fn_pot_guard()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = money_kernel, pg_temp
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.amount IS DISTINCT FROM 0 THEN
      RAISE EXCEPTION 'pot_insert_requires_zero_amount';
    END IF;
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.amount IS DISTINCT FROM NEW.amount THEN
    IF current_setting('money.pot_writer', true) IS DISTINCT FROM '1' THEN
      RAISE EXCEPTION
        'cashbook_point_pots.amount may only be modified by fn_pays_apply';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_pot_guard
  BEFORE INSERT OR UPDATE OF amount ON money_kernel.cashbook_point_pots
  FOR EACH ROW
  EXECUTE FUNCTION money_kernel.fn_pot_guard();
```

**Invariants it enforces:**
- INSERT with non-zero `amount` rejected (I36)
- UPDATE only when `fn_pays_apply` set `set_config('money.pot_writer','1',true)` for the transaction

**Failure modes:**
- `INSERT … amount = 1e9` → `pot_insert_requires_zero_amount`
- App `UPDATE` without flag → EXCEPTION

**Defense in depth (recommended):**

```sql
REVOKE INSERT, UPDATE, DELETE ON public.cashbook_point_pots FROM authenticated;
-- Only service_role (owner) can write directly; all writes go through SECURITY DEFINER functions
```

Even if a bad actor drops the trigger (requires superuser), they can't write through the authenticated role.

---

### 5.4 T4 — `trg_bills_guard_financial_spine`

**Freeze structural columns after issue. Freeze totals once money has been applied.**

```sql
CREATE OR REPLACE FUNCTION public.fn_bills_guard_financial_spine()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_has_settlements boolean;
BEGIN
  -- Voided bills are frozen forever
  IF OLD.status = 'voided' THEN
    RAISE EXCEPTION 'voided bill % cannot be updated', OLD.id;
  END IF;

  -- Draft: allow edits; status may only move to issued or voided
  IF OLD.status = 'draft' THEN
    IF NEW.status IS DISTINCT FROM OLD.status
       AND NEW.status NOT IN ('issued', 'voided') THEN
      RAISE EXCEPTION
        'illegal status transition for bill %: draft → %', OLD.id, NEW.status;
    END IF;
    RETURN NEW;
  END IF;

  -- Issued / partial / paid / written_off from here
  IF NEW.tenant_id             <> OLD.tenant_id
     OR NEW.issued_by_tenant_id <> OLD.issued_by_tenant_id
     OR NEW.invoice_no         <> OLD.invoice_no
     OR NEW.invoice_date       <> OLD.invoice_date
     OR NEW.kind               <> OLD.kind
     OR NEW.parent_bill_id     IS DISTINCT FROM OLD.parent_bill_id
     OR NEW.currency_code      <> OLD.currency_code
     OR NEW.from_profile_id IS DISTINCT FROM OLD.from_profile_id
     OR NEW.to_profile_id   IS DISTINCT FROM OLD.to_profile_id
     OR NEW.counterparty_profile_id IS DISTINCT FROM OLD.counterparty_profile_id
     OR NEW.counterparty_tenant_id  IS DISTINCT FROM OLD.counterparty_tenant_id
     OR NEW.source_type        IS DISTINCT FROM OLD.source_type
     OR NEW.source_id          IS DISTINCT FROM OLD.source_id
     OR NEW.source_key         IS DISTINCT FROM OLD.source_key THEN
    RAISE EXCEPTION
      'issued bill % — structural columns are immutable (void and recreate if needed)', OLD.id;
  END IF;

  -- Totals freeze once settled (only check when those columns change — avoid O(N²) on T7)
  IF NEW.total_amount IS DISTINCT FROM OLD.total_amount
     OR NEW.due_date IS DISTINCT FROM OLD.due_date THEN
    SELECT EXISTS (
      SELECT 1 FROM public.bill_settlements
       WHERE bill_id = OLD.id OR source_bill_id = OLD.id
    ) INTO v_has_settlements;
  ELSE
    v_has_settlements := false;
  END IF;
  IF v_has_settlements THEN
    IF NEW.total_amount  <> OLD.total_amount
       OR NEW.due_date   IS DISTINCT FROM OLD.due_date THEN
      RAISE EXCEPTION
        'bill % has settlements — total_amount and due_date cannot change', OLD.id;
    END IF;
  END IF;

  -- status transitions must be legal (include reverse paths when settlements void)
  IF NEW.status <> OLD.status THEN
    IF NOT (
      (OLD.status = 'issued' AND NEW.status IN ('partial','paid','written_off','voided')) OR
      (OLD.status = 'partial' AND NEW.status IN ('issued','paid','written_off','voided')) OR
      (OLD.status = 'paid' AND NEW.status IN ('partial','issued','voided')) OR
      (OLD.status = 'written_off' AND NEW.status = 'voided')
    ) THEN
      RAISE EXCEPTION
        'illegal status transition for bill %: % → %', OLD.id, OLD.status, NEW.status;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_bills_guard_financial_spine
  BEFORE UPDATE ON public.bills
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_bills_guard_financial_spine();
```

**Invariants it enforces:**
- Voided bills cannot change
- Draft may only transition to `issued` or `voided`
- Once issued, structural columns are frozen forever (only void + recreate changes them)
- Once any settlement exists as **target or document source**, `total_amount` and `due_date` are frozen
- Legal status transitions include reverse reopen (`paid/partial → issued`) when settlements are voided

**Notes:**
- `paid_amount`, `due_amount`, `written_off_amount` are writable by T7 and `rpc_write_off_bill` (and `rpc_void_bill` zeroing due).
- `status` only along the state machine.

---

### 5.5 T5 — `trg_bill_events_no_update`

**Event log is append-only.**

```sql
CREATE OR REPLACE FUNCTION public.fn_bill_events_immutable()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION
    'bill_events is append-only; cannot UPDATE or DELETE row id=%', OLD.id;
END;
$$;

CREATE TRIGGER trg_bill_events_no_update
  BEFORE UPDATE OR DELETE ON public.bill_events
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_bill_events_immutable();
```

**Invariants it enforces:**
- No event is ever mutated
- No event is ever deleted (even on bill delete — CASCADE runs, but the bill delete itself is a documented destructive operation)

**Note on CASCADE:** `bill_events.bill_id` has `ON DELETE CASCADE` to `bills`. But this trigger fires on `DELETE` of `bill_events` rows. **Postgres fires triggers on CASCADE deletes too** — so a `DELETE FROM bills` would fail with `bill_events is append-only`.

**This is intentional.** To delete a bill you must `void` it, not delete it. There is no way to delete a bill that has events.

---

### 5.6 T6 — `trg_bill_events_from_bills`

**Emit exactly one lifecycle event per bill action.**

```sql
CREATE OR REPLACE FUNCTION public.fn_bill_events_from_bills()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_event_type text;
  v_payload    jsonb;
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.bill_events
      (tenant_id, bill_id, event_type, payload, actor_id)
    VALUES
      (NEW.tenant_id, NEW.id, 'created',
       jsonb_build_object(
         'kind',          NEW.kind,
         'invoice_no',    NEW.invoice_no,
         'status',        NEW.status,
         'total_amount',  NEW.total_amount,
         'currency_code', NEW.currency_code,
         'source_type',   NEW.source_type,
         'source_id',     NEW.source_id,
         'source_key',    NEW.source_key,
         'parent_bill_id', NEW.parent_bill_id,
         'counterparty_profile_id', NEW.counterparty_profile_id
       ),
       auth.uid());
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    -- Priority 0: void wins even if due/written_off cleared in the same UPDATE
    IF NEW.status = 'voided' AND OLD.status IS DISTINCT FROM 'voided' THEN
      INSERT INTO public.bill_events
        (tenant_id, bill_id, event_type, payload, actor_id)
      VALUES (
        NEW.tenant_id, NEW.id, 'voided',
        jsonb_build_object(
          'from_status', OLD.status,
          'to_status', 'voided',
          'due_before', OLD.due_amount,
          'written_off_before', OLD.written_off_amount
        ),
        auth.uid()
      );
      RETURN NEW;
    END IF;

    -- Priority 1: payment delta
    IF NEW.paid_amount IS DISTINCT FROM OLD.paid_amount THEN
      v_event_type := CASE
        WHEN NEW.paid_amount > OLD.paid_amount THEN 'payment_applied'
        ELSE 'payment_reversed'
      END;
      v_payload := jsonb_build_object(
        'delta',       NEW.paid_amount - OLD.paid_amount,
        'paid_before', OLD.paid_amount,
        'paid_after',  NEW.paid_amount,
        'due_after',   NEW.due_amount,
        'status_after', NEW.status
      );
      INSERT INTO public.bill_events
        (tenant_id, bill_id, event_type, payload, actor_id)
      VALUES (NEW.tenant_id, NEW.id, v_event_type, v_payload, auth.uid());
      RETURN NEW;   -- do not also emit status event
    END IF;

    -- Priority 2: write-off delta
    IF NEW.written_off_amount IS DISTINCT FROM OLD.written_off_amount THEN
      v_payload := jsonb_build_object(
        'delta',           NEW.written_off_amount - OLD.written_off_amount,
        'written_off_total', NEW.written_off_amount,
        'due_after',       NEW.due_amount,
        'status_after',    NEW.status
      );
      INSERT INTO public.bill_events
        (tenant_id, bill_id, event_type, payload, actor_id)
      VALUES (NEW.tenant_id, NEW.id, 'written_off', v_payload, auth.uid());
      RETURN NEW;
    END IF;

    -- Priority 3: issued only (void handled above)
    IF NEW.status <> OLD.status AND NEW.status = 'issued' THEN
      INSERT INTO public.bill_events
        (tenant_id, bill_id, event_type, payload, actor_id)
      VALUES (
        NEW.tenant_id, NEW.id, 'issued',
        jsonb_build_object('from_status', OLD.status, 'to_status', NEW.status),
        auth.uid()
      );
      RETURN NEW;
    END IF;

    -- No interesting delta (e.g. just `updated_at` changed) → no event
    RETURN NEW;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_bill_events_from_bills
  AFTER INSERT OR UPDATE ON public.bills
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_bill_events_from_bills();
```

**Invariants it enforces:**
- Every meaningful bill change produces exactly one event
- Priority ordering prevents double-counting
- Events are written in the same transaction as the triggering change (atomic)

---

### 5.7 T7 — `trg_bill_settle_apply`

**Settlement insert/delete drives `bills.paid_amount`, `due_amount`, `status`.**

```sql
CREATE OR REPLACE FUNCTION public.fn_bill_settle_apply()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_row   bill_settlements;
  v_delta numeric(18,4);
BEGIN
  v_row := COALESCE(NEW, OLD);
  v_delta := CASE WHEN TG_OP = 'INSERT' THEN NEW.allocated_amount ELSE -OLD.allocated_amount END;

  -- Target: one UPDATE for paid/due/status (RHS sees pre-image; one T4/T6 fire)
  UPDATE public.bills
     SET paid_amount = paid_amount + v_delta,
         due_amount  = due_amount  - v_delta,
         status      = CASE
                         WHEN status = 'voided' THEN status
                         ELSE public.derive_bill_status(
                                total_amount,
                                paid_amount + v_delta,
                                due_amount - v_delta,
                                written_off_amount)
                       END,
         updated_at  = now()
   WHERE id = v_row.bill_id
     AND (due_amount - v_delta) >= 0
     AND (paid_amount + v_delta) >= 0;
  IF NOT FOUND THEN
    RAISE EXCEPTION
      'invalid_amount: settlement delta % would break paid/due on bill %',
      v_delta, v_row.bill_id;
  END IF;

  -- Document: consume remaining credit on source credit_note (same one-shot pattern)
  IF v_row.settlement_kind = 'document' AND v_row.source_bill_id IS NOT NULL THEN
    UPDATE public.bills
       SET paid_amount = paid_amount + v_delta,
           due_amount  = due_amount  - v_delta,
           status      = CASE
                           WHEN status = 'voided' THEN status
                           ELSE public.derive_bill_status(
                                  total_amount,
                                  paid_amount + v_delta,
                                  due_amount - v_delta,
                                  written_off_amount)
                         END,
           updated_at  = now()
     WHERE id = v_row.source_bill_id
       AND (due_amount - v_delta) >= -0.01
       AND (paid_amount + v_delta) >= -0.01;
    IF NOT FOUND THEN
      RAISE EXCEPTION
        'invalid_amount: settlement delta % would break paid/due on source bill %',
        v_delta, v_row.source_bill_id;
    END IF;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_bill_settle_apply
  AFTER INSERT OR DELETE ON public.bill_settlements
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_bill_settle_apply();
```

**Notes:**
- Target (and CN source) get paid/due/status in **one** UPDATE each (fewer T4/T6 firings). T6 still emits one `payment_applied`/`payment_reversed` because paid_amount changed (priority over status).
- Voided bills never change `status` here.

---

### 5.8 S1 — `trg_bill_settlements_immutable`

**Settlement rows cannot be edited. Void + re-insert only.**

```sql
CREATE OR REPLACE FUNCTION public.fn_bill_settlements_immutable()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION
    'bill_settlements row % is immutable; void via rpc_void_pays / rpc_void_document_settlement', OLD.id;
END;
$$;

CREATE TRIGGER trg_bill_settlements_immutable
  BEFORE UPDATE ON public.bill_settlements
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_bill_settlements_immutable();
```

---

### 5.9 S2 — `trg_validate_profile_link`

**`cashbook_accounts.profile_id` must match `entity_id` when `entity_type='profile'`.**

```sql
CREATE OR REPLACE FUNCTION public.fn_validate_profile_link()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.entity_type = 'profile' THEN
    IF NEW.profile_id IS NULL OR NEW.profile_id <> NEW.entity_id THEN
      RAISE EXCEPTION
        'cashbook_accounts.profile_id (%) must equal entity_id (%) when entity_type=profile',
        NEW.profile_id, NEW.entity_id;
    END IF;
  ELSE
    IF NEW.profile_id IS NOT NULL THEN
      RAISE EXCEPTION
        'cashbook_accounts.profile_id must be NULL when entity_type=% (got %)',
        NEW.entity_type, NEW.profile_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_profile_link
  BEFORE INSERT OR UPDATE ON public.cashbook_accounts
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_validate_profile_link();
```

---

### 5.10 S3 — `trg_validate_default_pot`

**`default_cashbook_point_pot_id` must belong to this account.**

```sql
CREATE OR REPLACE FUNCTION public.fn_validate_default_pot()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.default_cashbook_point_pot_id IS NOT NULL THEN
    PERFORM 1
      FROM public.cashbook_point_pots pp
      JOIN public.cashbook_points     pt ON pt.id = pp.cashbook_point_id
     WHERE pp.id = NEW.default_cashbook_point_pot_id
       AND pt.cashbook_account_id = NEW.id;
    IF NOT FOUND THEN
      RAISE EXCEPTION
        'default_cashbook_point_pot_id % does not belong to account %',
        NEW.default_cashbook_point_pot_id, NEW.id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_validate_default_pot
  BEFORE INSERT OR UPDATE OF default_cashbook_point_pot_id
  ON public.cashbook_accounts
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_validate_default_pot();
```

---

### 5.11 S4 — `trg_provision_profile_cashbook`

**Every new profile gets a default cashbook with a main point and a BDT pot.**

```sql
CREATE OR REPLACE FUNCTION public.fn_provision_profile_cashbook()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_account_id bigint;
  v_point_id   bigint;
  v_pot_id     bigint;
BEGIN
  -- Account (BEFORE INSERT validation: profile_id = entity_id when entity_type='profile')
  INSERT INTO public.cashbook_accounts
    (tenant_id, entity_type, entity_id, profile_id)
  VALUES
    (NEW.tenant_id, 'profile', NEW.id, NEW.id)
  RETURNING id INTO v_account_id;

  -- Main point
  INSERT INTO public.cashbook_points
    (tenant_id, cashbook_account_id, code, name)
  VALUES
    (NEW.tenant_id, v_account_id, 'main', 'Main')
  RETURNING id INTO v_point_id;

  -- BDT pot
  INSERT INTO public.cashbook_point_pots
    (tenant_id, cashbook_point_id, currency_code)
  VALUES
    (NEW.tenant_id, v_point_id, 'BDT')
  RETURNING id INTO v_pot_id;

  -- Set default pot pointer (validated by trg_validate_default_pot)
  UPDATE public.cashbook_accounts
     SET default_cashbook_point_pot_id = v_pot_id
   WHERE id = v_account_id;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_provision_profile_cashbook
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_provision_profile_cashbook();
```

**Invariants it enforces:**
- Every profile has a working cashbook from the moment it's created
- `rpc_deposit` / `rpc_withdraw` never fail with "no pot" for a profile that exists

---

### 5.12 D1 — `trg_check_pays_overalloc`

**Σ allocation per pays ≤ pays amount (BDT-normalized).**

```sql
CREATE OR REPLACE FUNCTION public.fn_check_pays_overalloc()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_alloc numeric(18,4);
  v_books numeric(18,4);
BEGIN
  IF NEW.settlement_kind <> 'pay' OR NEW.pays_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COALESCE(SUM(allocated_books_amount), 0)
    INTO v_alloc
    FROM public.bill_settlements
   WHERE pays_id = NEW.pays_id
     AND settlement_kind = 'pay';

  SELECT books_amount
    INTO v_books
    FROM public.pays
   WHERE id = NEW.pays_id;

  -- 0.01 tolerance for rounding
  IF v_alloc > v_books + 0.01 THEN
    RAISE EXCEPTION
      'over-allocated pays %: books-allocated % > books-amount %',
      NEW.pays_id, v_alloc, v_books;
  END IF;

  RETURN NEW;
END;
$$;

CREATE CONSTRAINT TRIGGER trg_check_pays_overalloc
  AFTER INSERT OR UPDATE ON public.bill_settlements
  DEFERRABLE INITIALLY DEFERRED
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_check_pays_overalloc();
```

**Notes:**
- `DEFERRABLE INITIALLY DEFERRED` → runs at `COMMIT`. Allows multi-bill payment in one transaction.
- Compares in BDT (`allocated_books_amount` vs `books_amount`) → currency-agnostic.

---

### 5.13 Helper — `derive_bill_status`

**Pure function that maps (total, paid, due, written_off) → status.**

```sql
CREATE OR REPLACE FUNCTION public.derive_bill_status(
  p_total       numeric,
  p_paid        numeric,
  p_due         numeric,
  p_written_off numeric
) RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF p_due = 0 THEN
    IF p_paid = 0 AND p_written_off > 0 THEN
      RETURN 'written_off';
    END IF;
    RETURN 'paid';
  END IF;

  IF p_paid > 0 OR p_written_off > 0 THEN
    RETURN 'partial';
  END IF;
  RETURN 'issued';
END;
$$;
```

**Called by:**
- `fn_bill_settle_apply` (T7) — after updating paid/due
- `rpc_write_off_bill` — after updating written_off_amount
- `rpc_issue_bill` — after transitioning draft → issued (uses OLD status to prevent re-issue)

**Not called by** the `bills` guard trigger — it's a pure calculator, not an enforcer.

---

## 6. Illegal Transitions — Error Catalog

Every one of these returns an `EXCEPTION` that aborts the transaction:

| Attempt | Trigger | Error |
|---|---|---|
| `UPDATE pays SET amount = ...` on posted | T2 | `posted pays N is immutable; use rpc_update_pays` |
| `UPDATE pays SET status = 'voided', amount = 100` | T2 | `void pays N may only change status, voided_at, meta, updated_at` |
| `UPDATE pays SET status = 'posted'` on voided | T2 | `pays N is voided and cannot be updated` |
| `UPDATE cashbook_point_pots SET amount = ...` | T3 | `cashbook_point_pots.amount may only be modified by fn_pays_apply` |
| `UPDATE bills SET total_amount = ...` on issued | T4 | `issued bill N — structural columns are immutable` |
| `UPDATE bills SET total_amount = ...` with settlements | T4 | `bill N has settlements — total_amount and due_date cannot change` |
| `UPDATE bills SET status = 'partial'` on draft | T4 | `illegal status transition for bill N: draft → partial` |
| `UPDATE` any column on voided bill | T4 | `voided bill N cannot be updated` |
| `UPDATE bills` total on CN after it was document source | T4 | `bill N has settlements — total_amount and due_date cannot change` |
| `UPDATE bill_events ...` | T5 | `bill_events is append-only` |
| `DELETE bill_events ...` | T5 | `bill_events is append-only` |
| `UPDATE bill_settlements SET allocated_amount = ...` | S1 | `bill_settlements row N is immutable` |
| Insert `cashbook_accounts` with `profile_id ≠ entity_id` | S2 | `profile_id (%) must equal entity_id (%) when entity_type=profile` |
| Insert `cashbook_accounts` with foreign `default_cashbook_point_pot_id` | S3 | `default_cashbook_point_pot_id % does not belong to account %` |
| Insert `bill_settlements` pushing Σ allocation > pays | D1 (at COMMIT) | `over-allocated pays N: books-allocated % > books-amount %` |
| `UPDATE bills` so `paid+due+written_off ≠ total` (non-void) | CHK | `chk_bill_amount_identity` |

---



## Deployment order (triggers)

```
1. Tables (all 12)                  — table deploy order above
2. derive_bill_status helper        — needed by fn_bill_settle_apply
3. fn_pays_apply + trg_pays_apply
4. fn_pays_guard_immutable + trg_pays_guard_immutable
5. fn_pot_guard + trg_pot_guard
6. fn_bills_guard_financial_spine + trg_bills_guard_financial_spine
7. fn_bill_events_immutable + trg_bill_events_no_update
8. fn_bill_events_from_bills + trg_bill_events_from_bills
9. fn_bill_settle_apply + trg_bill_settle_apply
10. fn_bill_settlements_immutable + trg_bill_settlements_immutable
11. fn_validate_profile_link + trg_validate_profile_link
12. fn_validate_default_pot + trg_validate_default_pot
13. fn_provision_profile_cashbook + trg_provision_profile_cashbook
14. fn_check_pays_overalloc + trg_check_pays_overalloc (CONSTRAINT TRIGGER)
15. REVOKE direct writes on protected columns (see §5.3)
```

**Dependency note:** `fn_pays_apply` writes to `cashbook_point_pots`, which must exist and have `chk_pot_amount_non_negative`. `fn_bill_settle_apply` calls `derive_bill_status`, which must exist first.

---


### 3.13 `money_outbox`

**Purpose:** Durable change-feed rows, same transaction as lifecycle writes. Consumers poll by `xid` (see [00-overview.md](00-overview.md)).

```sql
CREATE TABLE money_kernel.money_outbox (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id   bigint NOT NULL,
  xid         xid8 NOT NULL DEFAULT pg_current_xact_id(),
  event_type  text NOT NULL,
  payload     jsonb NOT NULL,
  bill_id     bigint,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_outbox_tenant_xid ON money_kernel.money_outbox (tenant_id, xid, id);
```

T6 (or sibling) INSERTs into `money_outbox` when inserting `bill_events`.

---

## 7. Index DDL (executable)

Run after tables. Drop redundant indexes called out in overview NFR.

```sql
-- bills list / search
CREATE INDEX ix_bills_tenant_invoice_date_id ON money_kernel.bills (tenant_id, invoice_date DESC, id DESC);
CREATE INDEX ix_bills_tenant_due_open ON money_kernel.bills (tenant_id, due_date) WHERE due_amount > 0;
CREATE INDEX ix_bills_tenant_updated ON money_kernel.bills (tenant_id, updated_at);
CREATE INDEX ix_bills_invoice_no_pattern ON money_kernel.bills (tenant_id, invoice_no text_pattern_ops);

-- settlements (all kinds — T4, get_bill, void_bill)
CREATE INDEX ix_settle_bill ON money_kernel.bill_settlements (bill_id);

-- pots
CREATE INDEX ix_pots_tenant ON money_kernel.cashbook_point_pots (tenant_id);

-- meta shipment (expression; prefer over full GIN where possible)
CREATE INDEX ix_bills_meta_shipment ON money_kernel.bills ((meta->>'shipment_id'))
  WHERE meta ? 'shipment_id';

-- DROP redundant (superseded by UNIQUE / BRIN):
-- ix_bill_lines_bill, ix_bill_events_type, ix_pays_meta
```

**Hot rows:** `ALTER TABLE money_kernel.cashbook_point_pots SET (fillfactor = 70);` same for `bills`. Aggressive autovacuum on pots. `bill_events` partitioned monthly + BRIN on `created_at` at scale.

**D1:** cap ≤200 settlement rows per pays per transaction; add check Σ `allocated_amount` ≤ `pays.amount` at RPC.

---

### 5.14 T8 — `trg_bill_lines_guard` (sketch)

```sql
-- BEFORE INSERT/UPDATE/DELETE on bill_lines: parent bills.status must be 'draft'
-- AFTER issue path in rpc_issue_bill: assert SUM(line_total) = bills.total_amount
```

### 5.15 S5 — settlement pay guard (sketch)

```sql
-- BEFORE INSERT on bill_settlements:
-- pay: joins pays where status='posted', kind='payment', tenant_id match (I31)
-- document: source is credit_note; target.from = source.to AND target.to = source.from (I29)
```

All trigger/helper functions: `SET search_path = money_kernel, pg_temp`.

Invariants: see [00-overview.md](00-overview.md).
