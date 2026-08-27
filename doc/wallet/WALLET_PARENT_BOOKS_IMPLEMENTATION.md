# Wallet Parent-Books Migration — Implementation Plan

Align universal wallet storage and reads with **parent tenant books** (same model as `sales_invoices.parent_tenant_id` + `issued_by_tenant_id`).

**Domain spec (target):** [`WALLET.md`](./WALLET.md) §1.1–1.4  
**System RPC callers:** [`RECORD_LEDGER_SYSTEM_RPC_MIGRATION.md`](./RECORD_LEDGER_SYSTEM_RPC_MIGRATION.md) (invoice, dropship, procurement, investor)  
**Legacy retirement:** [`WALLET_LEGACY_RETIREMENT.md`](./WALLET_LEGACY_RETIREMENT.md) (drop zombie RPCs + dead UI)  
**Status:** **Not started** — schema still uses single `tenant_id`; dropship writes child; UI reads parent.  
**Triggered by:** Order #37 (`shop_orders.id = 37`) — DB has balances on child tenant `11`; wallet UI shows `0`.

---

## Problem

| Layer | Today | Should be |
| :--- | :--- | :--- |
| `wallet_accounts` / `universal_wallet_ledger` | One column `tenant_id` = mixed meaning | `parent_tenant_id` (book) + `operating_tenant_id` (desk) |
| Dropship RPCs | `p_tenant_id => shop_orders.tenant_id` (child) | `parent_tenant_id => resolve_parent(...)`, `operating_tenant_id => child` |
| Wallet UI composables | `parent_id ?? id` for queries | `parent_tenant_id` = books; optional `operating_tenant_id` filter |
| Tenant cash `entity_id` | Often child id (`11`) | **Parent id** (one company cash pool) |

---

## Locked decisions

1. **Books column:** `parent_tenant_id` on both `wallet_accounts` and `universal_wallet_ledger`.
2. **Operating column:** `operating_tenant_id` on ledger (and optional on accounts if needed for metadata only — ledger is required).
3. **Unique wallet key:** `(parent_tenant_id, entity_type, entity_id, currency_code)`.
4. **Company cash:** `entity_type = 'tenant'`, `entity_id = parent_tenant_id`.
5. **Courier:** `entity_id = courier_services.wallet_entity_id` (not UUID).
6. **Reseller / customer wallet:** `entity_id = billing_profiles.id`.
7. **Standalone tenant:** `parent_tenant_id = operating_tenant_id = tenants.id`.
8. **Deprecate:** single `tenant_id` on wallet tables after backfill (rename or drop in final phase).

---

## Target schema

### `wallet_accounts`

| Column | Type | Notes |
| :--- | :--- | :--- |
| `id` | bigint PK | identity |
| `parent_tenant_id` | bigint NOT NULL FK → `tenants` | Books scope |
| `entity_type` | text NOT NULL | |
| `entity_id` | bigint NOT NULL | |
| `currency_code` | text NOT NULL DEFAULT `'BDT'` | |
| `available_balance` | numeric(18,4) | |
| `pending_balance` | numeric(18,4) | |
| `locked_balance` | numeric(18,4) | |
| `created_at` / `updated_at` | timestamptz | |

**UNIQUE:** `(parent_tenant_id, entity_type, entity_id, currency_code)`

### `universal_wallet_ledger`

| Column | Type | Notes |
| :--- | :--- | :--- |
| `id` | uuid PK | |
| `parent_tenant_id` | bigint NOT NULL | Must match account book |
| `operating_tenant_id` | bigint NOT NULL | Child desk or self |
| `entity_type` | text NOT NULL | |
| `entity_id` | bigint NOT NULL | |
| `type` | text | `credit` / `debit` |
| `amount`, `base_amount`, `balance_after`, `currency_code`, `exchange_rate` | | unchanged |
| `source_type`, `source_id`, `metadata` | | unchanged |
| `created_at` | timestamptz | append-only |

**Indexes:**

- `(parent_tenant_id, entity_type, entity_id, created_at DESC, id DESC)` — wallet UI
- `(parent_tenant_id, operating_tenant_id, created_at DESC)` — per-child drill-down
- `(source_type, source_id)` — order / invoice trace
- `(operating_tenant_id, source_type, source_id)` — child-scoped lookups

### RPC signature (`record_ledger_transaction`)

Add parameters (keep backward compat one release if needed):

```text
p_parent_tenant_id     bigint  -- books
p_operating_tenant_id  bigint  -- desk (defaults to parent when standalone)
p_entity_type, p_entity_id, p_type, p_amount, ...
```

Internal: upsert account on `(parent_tenant_id, entity_type, entity_id, currency)`; insert ledger with both tenant columns.

### Helper SQL

```sql
wallet_books_tenant_id(p_tenant_id bigint) :=
  resolve_parent_tenant_id(p_tenant_id);
```

---

## Phase overview

| Phase | Focus | Risk | Depends on |
| :--- | :--- | :--- | :--- |
| **P0** | Schema add + backfill migration | Medium | — |
| **P1** | Core ledger RPCs | High | P0 |
| **P2** | Dropship + sales-invoice writers | High | P1 |
| **P3** | Remaining wallet writers | Medium | P1 |
| **P4** | RLS + membership | Medium | P0 |
| **P5** | Frontend wallet module | Medium | P1 |
| **P5a** | List RPC + `WalletEntityListPage` | Medium | P1, [`LIST_WALLET_ENTITIES_RPC.md`](./LIST_WALLET_ENTITIES_RPC.md) |
| **P5b** | Detail + manual tx RPCs + `UniversalWalletPage` | High | P1, [`UNIVERSAL_WALLET_DETAIL_RPC.md`](./UNIVERSAL_WALLET_DETAIL_RPC.md) |
| **P6** | Treasury / reporting RPCs | Low | P1 |
| **P7** | Drop legacy `tenant_id`, types, verification | Medium | P0–P6 |
| **P8** | Retire zombie RPCs + dead wallet UI | Low | P5b, [`WALLET_LEGACY_RETIREMENT.md`](./WALLET_LEGACY_RETIREMENT.md) |

Implement **P0 → P1 → P2 → P5a → P5b** for wallet UI fix; then P3, P4, P6, P7.

---

## Master task list (RPC + UI)

Track implementation outside this file; check boxes when done.

### Schema & core (P0–P1)

- [ ] P0 — `parent_tenant_id` / `operating_tenant_id` columns + backfill ([§Existing data](#existing-data--how-to-adjust-production-backfill))
- [ ] P1 — `record_ledger_transaction` accepts books + operating tenant
- [ ] P1 — `get_wallet_account_balances` uses `parent_tenant_id` (until detail RPC replaces UI usage)

### New RPCs (spec → SQL)

- [ ] `list_wallet_entities_for_staff` — [`LIST_WALLET_ENTITIES_RPC.md`](./LIST_WALLET_ENTITIES_RPC.md)
- [ ] `get_wallet_detail_for_staff` — [`UNIVERSAL_WALLET_DETAIL_RPC.md`](./UNIVERSAL_WALLET_DETAIL_RPC.md) §1
- [ ] `list_wallet_ledger_for_staff` — [`UNIVERSAL_WALLET_DETAIL_RPC.md`](./UNIVERSAL_WALLET_DETAIL_RPC.md) §2
- [ ] `record_wallet_manual_transaction_for_staff` — [`UNIVERSAL_WALLET_DETAIL_RPC.md`](./UNIVERSAL_WALLET_DETAIL_RPC.md) §3
- [ ] `reverse_wallet_ledger_entry_for_staff` — [`UNIVERSAL_WALLET_DETAIL_RPC.md`](./UNIVERSAL_WALLET_DETAIL_RPC.md) §4
- [ ] `pnpm run backend:types` after each migration batch

### Domain writers (P2–P3)

Full per-RPC inventory: [`RECORD_LEDGER_SYSTEM_RPC_MIGRATION.md`](./RECORD_LEDGER_SYSTEM_RPC_MIGRATION.md)

- [ ] P2 — Sales invoice writers (7 RPCs: collect, post, payout, return, …)
- [ ] P2 — Dropship / shop order writers (`confirm_dropship_delivered_costing`, remittance, return, bank transfer)
- [ ] P3 — Procurement shipment + vendor writers (6 RPCs)
- [ ] P3 — Investor capital in/out (2 RPCs)

### Frontend (P5a–P5b)

- [ ] P5a — `WalletEntityListPage` → single `list_wallet_entities_for_staff` call
- [ ] P5b — `UniversalWalletPage` → `get_wallet_detail_for_staff` on mount
- [ ] P5b — Ledger table → `list_wallet_ledger_for_staff` (search param)
- [ ] P5b — `WalletActionModal` submit → `record_wallet_manual_transaction_for_staff`
- [ ] P5b — Revert action → `reverse_wallet_ledger_entry_for_staff` (+ reason dialog)
- [ ] P5b — Remove `fetchEntityName` direct table queries
- [ ] P5b — `walletBooksTenantId()` helper shared across wallet module
- [ ] Query keys updated per [`WALLET.md`](./WALLET.md) §4–§5

### Legacy retirement (P8)

Spec: [`WALLET_LEGACY_RETIREMENT.md`](./WALLET_LEGACY_RETIREMENT.md)

- [ ] P8a — Drop `dispense_middleman_payout`, `ensure_dropship_invoice_billed_entry`; fix `get_courier_unremitted_financial_summary`
- [ ] P8b — Delete dead wallet Vue components (`UniversalWallet.vue`, deposit/withdraw modals, …)
- [ ] P8c — Revoke client `record_ledger_transaction`; wallet repo uses staff RPCs only

### Verify

- [ ] Child tenant courier list + detail show real balances (order 37)
- [ ] Manual deposit on company wallet updates tenant pool
- [ ] Pay from company debits tenant + credits vendor (two ledger rows)
- [ ] Reversal blocked on `shop_order` system rows; works on manual rows
- [ ] `pnpm run backend:reset` clean

---

## Phase 0 — Schema add + backfill

**Goal:** New columns live; existing balances readable under parent book.

**Files:**

- `supabase/schemas/public.sql` (or split `wallet/` when extracted)
- `supabase/migrations/YYYYMMDDHHMMSS_wallet_parent_books_columns.sql`

**Change:**

1. Add `parent_tenant_id` to `wallet_accounts` and `universal_wallet_ledger` (nullable initially).
2. Add `operating_tenant_id` to `universal_wallet_ledger` (nullable initially).
3. Backfill:
   - `operating_tenant_id = tenant_id` (old column).
   - `parent_tenant_id = resolve_parent_tenant_id(tenant_id)`.
4. For `entity_type = 'tenant'` rows where `entity_id = operating_tenant_id` and `entity_id <> parent_tenant_id`, set `entity_id = parent_tenant_id` and merge balances into parent tenant wallet row (scripted in migration with care — log conflicts).
5. Set NOT NULL on new columns.
6. Add indexes listed above.
7. Add new UNIQUE on `wallet_accounts (parent_tenant_id, entity_type, entity_id, currency_code)` — drop old unique on `(tenant_id, …)` only after merge verified.
8. `pnpm run backend:types` after migration.

**Verify SQL:**

```sql
SELECT parent_tenant_id, operating_tenant_id, entity_type, entity_id, count(*)
FROM universal_wallet_ledger
GROUP BY 1,2,3,4
ORDER BY 1,2,3,4;
```

---

## Existing data — how to adjust (production backfill)

Live DB already has wallet rows on **child** `tenant_id` (e.g. Dropshipping `11`). Migration must **move books to parent** without losing money. Run on a **staging clone first**; take a backup before production.

### Principles

1. **Do not delete ledger rows** — append-only; only UPDATE column values and `entity_id` where the wallet party definition changes.
2. **`wallet_accounts` is the UI balance source** — after merge, summed balances on the parent book row must match pre-migration totals per party.
3. **`balance_after` on old ledger lines** may not re-chain perfectly after tenant-pool merge — acceptable if current balance comes from `wallet_accounts` and new RPCs maintain the chain going forward. Optional replay script below.
4. **Order of operations:** audit → add nullable columns → backfill columns → merge accounts → fix ledger `entity_id` → NOT NULL → new unique → deploy RPCs → drop old `tenant_id`.

### Step A — Pre-migration audit (run in Supabase SQL)

```sql
-- 1) Rows still on child book (tenant_id = child, parent exists)
SELECT
  wa.tenant_id AS old_tenant_id,
  t.name AS tenant_name,
  t.parent_id,
  wa.entity_type,
  wa.entity_id,
  wa.available_balance,
  wa.pending_balance,
  wa.locked_balance
FROM wallet_accounts wa
JOIN tenants t ON t.id = wa.tenant_id
WHERE t.parent_id IS NOT NULL
ORDER BY wa.tenant_id, wa.entity_type, wa.entity_id;

-- 2) Child tenant cash wallets (entity_id = child id) — need merge to parent pool
SELECT
  wa.tenant_id,
  wa.entity_id AS tenant_entity_id,
  t.parent_id AS should_be_entity_id,
  wa.available_balance + wa.pending_balance + wa.locked_balance AS total
FROM wallet_accounts wa
JOIN tenants t ON t.id = wa.tenant_id
WHERE wa.entity_type = 'tenant'
  AND t.parent_id IS NOT NULL
  AND wa.entity_id = wa.tenant_id;

-- 3) Ledger volume per old tenant_id
SELECT tenant_id, entity_type, count(*) AS ledger_rows
FROM universal_wallet_ledger
GROUP BY tenant_id, entity_type
ORDER BY tenant_id, entity_type;

-- 4) Example: order 37 parties (before migration)
SELECT tenant_id, entity_type, entity_id, type, base_amount, source_id
FROM universal_wallet_ledger
WHERE source_type = 'shop_order' AND source_id = '37'
ORDER BY created_at;
```

Save audit output (row counts + balance totals) for post-migration diff.

### Step B — Add columns (migration part 1)

```sql
ALTER TABLE wallet_accounts
  ADD COLUMN IF NOT EXISTS parent_tenant_id bigint;

ALTER TABLE universal_wallet_ledger
  ADD COLUMN IF NOT EXISTS parent_tenant_id bigint,
  ADD COLUMN IF NOT EXISTS operating_tenant_id bigint;
```

### Step C — Backfill tenant columns (migration part 2)

Uses existing `tenant_id` as **operating** desk; resolves **books** via `resolve_parent_tenant_id`.

```sql
-- Ledger: operating = old tenant_id, parent = books
UPDATE universal_wallet_ledger u
SET
  operating_tenant_id = u.tenant_id,
  parent_tenant_id = public.resolve_parent_tenant_id(u.tenant_id)
WHERE operating_tenant_id IS NULL;

-- Accounts: parent book only (no operating column on accounts)
UPDATE wallet_accounts wa
SET parent_tenant_id = public.resolve_parent_tenant_id(wa.tenant_id)
WHERE parent_tenant_id IS NULL;
```

Standalone tenants (`parent_id IS NULL`): `resolve_parent_tenant_id` returns self — no change in meaning.

### Step D — Merge child tenant cash into parent pool

**Case:** `entity_type = 'tenant'`, `entity_id = child_id` (e.g. `11`) while books should be `entity_id = parent_id`.

```sql
-- Preview merges: child pool → parent pool same book
WITH child_pools AS (
  SELECT
    wa.id,
    wa.tenant_id AS operating_tenant_id,
    public.resolve_parent_tenant_id(wa.tenant_id) AS parent_tenant_id,
    wa.currency_code,
    wa.available_balance,
    wa.pending_balance,
    wa.locked_balance
  FROM wallet_accounts wa
  JOIN tenants t ON t.id = wa.tenant_id
  WHERE wa.entity_type = 'tenant'
    AND t.parent_id IS NOT NULL
    AND wa.entity_id = wa.tenant_id
),
parent_pools AS (
  SELECT wa.*
  FROM wallet_accounts wa
  JOIN child_pools c
    ON wa.parent_tenant_id = c.parent_tenant_id
   AND wa.entity_type = 'tenant'
   AND wa.entity_id = c.parent_tenant_id
   AND wa.currency_code = c.currency_code
)
SELECT
  c.operating_tenant_id,
  c.parent_tenant_id,
  c.available_balance AS child_avail,
  p.available_balance AS parent_avail_before,
  c.available_balance + p.available_balance AS parent_avail_after
FROM child_pools c
JOIN parent_pools p ON p.parent_tenant_id = c.parent_tenant_id AND p.currency_code = c.currency_code;
```

**Apply merge** (inside transaction):

```sql
BEGIN;

-- Upsert parent company cash row (create if parent had no tenant wallet yet)
INSERT INTO wallet_accounts (
  tenant_id, parent_tenant_id, entity_type, entity_id, currency_code,
  available_balance, pending_balance, locked_balance
)
SELECT
  c.parent_tenant_id,  -- keep tenant_id = books until column dropped in P7
  c.parent_tenant_id,
  'tenant',
  c.parent_tenant_id,
  c.currency_code,
  0, 0, 0
FROM wallet_accounts wa
JOIN tenants t ON t.id = wa.tenant_id
CROSS JOIN LATERAL (
  SELECT public.resolve_parent_tenant_id(wa.tenant_id) AS parent_tenant_id, wa.currency_code
) c
WHERE wa.entity_type = 'tenant'
  AND t.parent_id IS NOT NULL
  AND wa.entity_id = wa.tenant_id
ON CONFLICT (tenant_id, entity_type, entity_id, currency_code) DO NOTHING;
-- Note: ON CONFLICT target switches to (parent_tenant_id, ...) after old unique dropped

-- Add child balances into parent pool
UPDATE wallet_accounts parent
SET
  available_balance = parent.available_balance + child.available_balance,
  pending_balance = parent.pending_balance + child.pending_balance,
  locked_balance = parent.locked_balance + child.locked_balance,
  updated_at = now()
FROM wallet_accounts child
JOIN tenants t ON t.id = child.tenant_id
WHERE child.entity_type = 'tenant'
  AND t.parent_id IS NOT NULL
  AND child.entity_id = child.tenant_id
  AND parent.parent_tenant_id = public.resolve_parent_tenant_id(child.tenant_id)
  AND parent.entity_type = 'tenant'
  AND parent.entity_id = parent.parent_tenant_id
  AND parent.currency_code = child.currency_code;

-- Remove empty child pool rows (after balances moved)
DELETE FROM wallet_accounts child
WHERE child.entity_type = 'tenant'
  AND child.entity_id = child.tenant_id
  AND EXISTS (
    SELECT 1 FROM tenants t
    WHERE t.id = child.tenant_id AND t.parent_id IS NOT NULL
  );

COMMIT;
```

Adjust `ON CONFLICT` / join keys when `tenant_id` column is replaced by `parent_tenant_id` on unique constraint.

### Step E — Fix ledger rows (party + books)

```sql
BEGIN;

-- All ledger lines: books column already set in Step C

-- Tenant cash lines: point entity_id at parent pool (not child desk id)
UPDATE universal_wallet_ledger u
SET entity_id = u.parent_tenant_id
WHERE u.entity_type = 'tenant'
  AND u.entity_id = u.operating_tenant_id
  AND u.entity_id <> u.parent_tenant_id;

-- Optional: stamp migration in metadata (no balance change)
UPDATE universal_wallet_ledger
SET metadata = metadata || jsonb_build_object(
  'migration', 'wallet_parent_books_2026',
  'migrated_at', now()
)
WHERE parent_tenant_id IS NOT NULL
  AND NOT (metadata ? 'migration');

COMMIT;
```

**Courier / customer rows:** only `parent_tenant_id` + `operating_tenant_id` change; `entity_id` stays (`wallet_entity_id`, `billing_profile_id`).

### Step F — Reconcile `wallet_accounts` with ledger (optional but recommended)

After entity_id fixes, recompute materialized balances from ledger for each wallet key:

```sql
-- Per-wallet net from ledger (credits - debits on available bucket is approximate;
-- use only for verification — RPC uses bucket rules)
WITH nets AS (
  SELECT
    parent_tenant_id,
    entity_type,
    entity_id,
    currency_code,
    sum(CASE WHEN type = 'credit' THEN base_amount ELSE -base_amount END) AS net_from_ledger
  FROM universal_wallet_ledger
  GROUP BY 1, 2, 3, 4
),
accounts AS (
  SELECT
    parent_tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance + pending_balance + locked_balance AS total_account
  FROM wallet_accounts
)
SELECT
  n.*,
  a.total_account,
  n.net_from_ledger - a.total_account AS diff
FROM nets n
JOIN accounts a
  ON a.parent_tenant_id = n.parent_tenant_id
 AND a.entity_type = n.entity_type
 AND a.entity_id = n.entity_id
 AND a.currency_code = n.currency_code
WHERE abs(n.net_from_ledger - a.total_account) > 0.01
ORDER BY abs(n.net_from_ledger - a.total_account) DESC;
```

If diffs exist pre-migration, **do not blame migration** — fix accounts to match business truth or run a one-off adjustment via `record_ledger_transaction` after P1 ships.

**Optional `balance_after` replay** (only if you need a clean chain on parent tenant wallet):

1. Lock wallet.
2. Walk ledger ordered by `created_at`, `id` for `(parent_tenant_id, 'tenant', parent_id)`.
3. Recompute running `balance_after` in a temp column; swap when verified.

Skip replay if UI uses `wallet_accounts` only.

### Step G — Constraints + indexes (migration part 3)

```sql
ALTER TABLE universal_wallet_ledger
  ALTER COLUMN parent_tenant_id SET NOT NULL,
  ALTER COLUMN operating_tenant_id SET NOT NULL;

ALTER TABLE wallet_accounts
  ALTER COLUMN parent_tenant_id SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_wallet_accounts_parent_book
  ON wallet_accounts (parent_tenant_id, entity_type, entity_id, currency_code);

-- After verification:
-- DROP old unique on (tenant_id, entity_type, entity_id, currency_code);
```

Keep `wallet_accounts.tenant_id = parent_tenant_id` until P7 so legacy queries do not break mid-deploy.

### Step H — Post-migration verification

```sql
-- No child-only tenant pools left
SELECT count(*) AS child_tenant_pools_left
FROM wallet_accounts wa
JOIN tenants t ON t.id = wa.tenant_id
WHERE wa.entity_type = 'tenant'
  AND t.parent_id IS NOT NULL
  AND wa.entity_id = wa.tenant_id;

-- Totals per parent book should match Step A audit (per entity_type + entity_id)
SELECT
  parent_tenant_id,
  entity_type,
  entity_id,
  sum(available_balance) AS avail,
  sum(pending_balance) AS pend,
  sum(locked_balance) AS lock
FROM wallet_accounts
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;

-- Order 37 after migration (example)
SELECT parent_tenant_id, operating_tenant_id, entity_type, entity_id,
       type, base_amount, source_id, metadata->>'purpose' AS purpose
FROM universal_wallet_ledger
WHERE source_type = 'shop_order' AND source_id = '37'
ORDER BY created_at;

-- UI RPC smoke test (replace ids)
SELECT public.get_wallet_account_balances(
  (SELECT parent_id FROM tenants WHERE id = 11), 'courier', 1, 'BDT'
);
SELECT public.get_wallet_account_balances(
  (SELECT parent_id FROM tenants WHERE id = 11), 'tenant',
  (SELECT parent_id FROM tenants WHERE id = 11), 'BDT'
);
SELECT public.get_wallet_account_balances(
  (SELECT parent_id FROM tenants WHERE id = 11), 'customer', 31, 'BDT'
);
```

### Worked example — Dropshipping child `11`, order `37`

| Party | Before (`tenant_id`) | After `parent_tenant_id` | After `operating_tenant_id` | `entity_id` |
| :--- | :--- | :--- | :--- | :--- |
| Courier Steadfast | `11` | parent of `11` | `11` | `1` (unchanged) |
| Company cash | `11` | parent of `11` | `11` on ledger | parent id (merged pool) |
| David Admin | `11` | parent of `11` | `11` | `31` (unchanged) |

Courier available `60`, tenant cash `17000`, customer `11091` — same totals, now visible when UI queries parent book.

### Rollback plan

1. Migration runs in transaction per step where possible.
2. Before deploy: export `wallet_accounts` and `universal_wallet_ledger` to CSV/json.
3. If rollback needed before P7: restore CSV or reverse UPDATE using saved Step A audit totals.
4. Do not drop `tenant_id` until production verified for one release cycle.

### When **not** to merge in SQL

- If parent **already** has a separate tenant wallet with manual adjustments and child also has cash, **manual review** before merge (preview query in Step D).
- If same `(parent, courier, wallet_entity_id)` exists under two child `tenant_id` rows with balances — merge is additive; confirm couriers are shared intentionally.

---

## Phase 1 — Core ledger RPCs

**Goal:** All reads/writes use `parent_tenant_id`; ledger records `operating_tenant_id`.

**Files:**

- `supabase/schemas/public.sql` — functions:
  - `record_ledger_transaction`
  - `get_wallet_account_balances`
  - `get_wallet_dashboard_summary`
  - `transfer_wallet_funds` / `transfer_wallet_balance` (if present)
- Grants in schema RLS files as needed

**Change:**

1. `record_ledger_transaction`: accept `p_parent_tenant_id`, `p_operating_tenant_id`; upsert/insert on new columns; keep `p_tenant_id` as deprecated alias mapping to books id for one release OR break and update all callers in same PR.
2. `get_wallet_account_balances`: filter `wallet_accounts.parent_tenant_id = p_parent_tenant_id` (param rename from `p_tenant_id` or add new param).
3. `get_wallet_dashboard_summary`: aggregate on `parent_tenant_id`.
4. Transfers: both legs use same `parent_tenant_id`; pass `operating_tenant_id` on ledger lines.

**Do not** edit generated `web/src/types/database.types.ts` by hand.

---

## Phase 2 — Dropship + sales-invoice wallet hooks

**Goal:** Order #37-style flows write parent book; tenant cash credits parent `entity_id`.

**Spec (full RPC list + idempotency rules):** [`RECORD_LEDGER_SYSTEM_RPC_MIGRATION.md`](./RECORD_LEDGER_SYSTEM_RPC_MIGRATION.md) §3–4

**Files:**

- `supabase/schemas/sales_invoice/03_rpcs.sql` — 7 writers (`collect_wholesale_invoice_payment`, `post_sales_invoice`, …)
- `supabase/schemas/shop_order/03_rpcs.sql` — dropship deliver, remittance, return, bank transfer
- Latest dropship migrations if `03_rpcs.sql` stubs lag live DB (`record_dropship_courier_bank_transfer`, `process_dropship_courier_remittance_uwl` 3-leg split)

**Change pattern for each writer:**

```sql
v_books_id := resolve_parent_tenant_id(v_order.tenant_id);
v_operating_id := v_order.tenant_id;

perform record_ledger_transaction(
  p_parent_tenant_id => v_books_id,
  p_operating_tenant_id => v_operating_id,
  p_entity_type => 'tenant',
  p_entity_id => v_books_id,  -- not child id
  ...
);
```

Courier leg: same `v_books_id`, `entity_type = 'courier'`, `entity_id = wallet_entity_id`.

**Re-test:** order delivered → remittance → invoice collection; SQL audit script from WALLET.md.

---

## Phase 3 — Remaining wallet writers

**Goal:** Procurement, vendor, cargo, investor paths use parent books + operating desk.

**Spec:** [`RECORD_LEDGER_SYSTEM_RPC_MIGRATION.md`](./RECORD_LEDGER_SYSTEM_RPC_MIGRATION.md) §5–6

**Files:**

- `supabase/schemas/procurement/03_rpcs.sql` — 6 RPCs (shipment settle, vendor AP, investor profit on shipment)
- `supabase/schemas/public.sql` — `record_investor_capital_in`, `record_investor_withdrawal_paid`
- Grep: `INSERT INTO universal_wallet_ledger`, `wallet_accounts`, `tenant_id = v_order.tenant_id` in UWL queries

**Change:** Procurement already uses `parent_tenant_id` for books — add `operating_tenant_id` (`coalesce(assigned_child_tenant_id, parent)`). Vendor param RPCs: resolve books from `p_tenant_id`. Tenant cash always `entity_id = v_books_id`.

---

## Phase 4 — RLS

**Goal:** Parent staff see all books rows; child staff see rows where `operating_tenant_id` matches membership tenant OR user can manage parent.

**Files:**

- `supabase/schemas/public.sql` — policies on `wallet_accounts`, `universal_wallet_ledger`

**Change:**

- SELECT: `is_superadmin()` OR membership on `parent_tenant_id` OR (`operating_tenant_id` = membership tenant).
- Align with `global_invoices_select` pattern (`user_can_manage_parent_tenant`).

---

## Phase 5 — Frontend wallet module

**Goal:** Wallet UI queries `parent_tenant_id`; company wallet uses parent id as `entity_id`.

**Files:**

- `web/src/modules/wallet/composables/useWalletAccounts.ts`
- `web/src/modules/wallet/composables/useWalletQuery.ts`
- `web/src/modules/wallet/composables/useWalletAccount.ts` (if duplicate)
- `web/src/modules/wallet/repositories/walletAccountRepository.ts`
- `web/src/modules/wallet/repositories/walletRepository.ts`
- `web/src/modules/wallet/pages/WalletEntityListPage.vue`
- `web/src/modules/wallet/pages/UniversalWalletPage.vue` — company route `entityId` = books id for tenant wallet
- `web/src/modules/wallet/shared/queryKeys/walletQueryKeys.ts`
- `web/src/modules/wallet/types/index.ts`
- `web/src/modules/shop_order/` — `MerchantWalletPage`, dropship wallet RPCs if client-side tenant id passed

**Change:**

1. Shared helper `walletBooksTenantId()` := `resolveParentTenantId(selectedTenant)` (mirror sales invoice pages).
2. `fetchAccountBalances(parentTenantId, entityType, entityId)` — RPC param `p_parent_tenant_id`.
3. Ledger query: `.eq('parent_tenant_id', booksId)`; optional UI filter `.eq('operating_tenant_id', childId)`.
4. `WalletEntityListPage`: list accounts with `parentTenantId`; courier list still maps `wallet_entity_id`.
5. Company wallet route: `entityId` = books tenant id (parent), not child id.
6. Update query keys per WALLET.md §5.
7. Replace `WalletEntityListPage` multi-fetch with **`list_wallet_entities_for_staff`** — [`LIST_WALLET_ENTITIES_RPC.md`](./LIST_WALLET_ENTITIES_RPC.md).

### Phase 5b — Universal wallet detail + manual transactions

**Goal:** One RPC bundle for [`UniversalWalletPage.vue`](../../../web/src/modules/wallet/pages/UniversalWalletPage.vue).

**Spec:** [`UNIVERSAL_WALLET_DETAIL_RPC.md`](./UNIVERSAL_WALLET_DETAIL_RPC.md)

**Files:**

- `supabase/schemas/public.sql` — four new functions
- `web/src/modules/wallet/pages/UniversalWalletPage.vue`
- `web/src/modules/wallet/components/WalletActionModal.vue` (submit payload mapping)
- `web/src/modules/wallet/components/UniversalWalletLedgerTable.vue` (revert)
- `web/src/modules/wallet/repositories/walletRepository.ts`
- `web/src/modules/wallet/composables/useWalletQuery.ts`, `useWalletAccounts.ts` (replace or narrow)

**Change:**

1. Mount: `get_wallet_detail_for_staff` only (name + balances + permissions).
2. Ledger: `list_wallet_ledger_for_staff` with server `p_search` when stable.
3. Actions: `record_wallet_manual_transaction_for_staff` (atomic double-entry for pay).
4. Revert: `reverse_wallet_ledger_entry_for_staff` with required reason.
5. Stop calling legacy `record_ledger_transaction` and direct `universal_wallet_ledger` select from this page.

---

## Phase 6 — Treasury / reporting RPCs

**Goal:** Cash in, customer dues, dashboard aggregates use `parent_tenant_id`.

**Files:**

- `supabase/schemas/public.sql` — `get_tenant_cash_in_report`, wallet sections of reporting RPCs
- `doc/reporting_treasury/CASH_IN.md`, `CUSTOMER_DUES.md` — doc cross-links only if behavior text changes

**Change:** Filter ledger `parent_tenant_id = wallet_books_tenant_id(p_tenant_id)`; optional `operating_tenant_id` filter param for child breakdown reports.

---

## Phase 8 — Legacy retirement

**Goal:** Remove broken RPCs, no-op stubs, and dead wallet UI; clients no longer call internal ledger RPC directly.

**Spec:** [`WALLET_LEGACY_RETIREMENT.md`](./WALLET_LEGACY_RETIREMENT.md)

**Summary:**

1. **Drop:** `dispense_middleman_payout` (broken; use `dispense_middleman_payout_from_tenant`).
2. **Drop:** `ensure_dropship_invoice_billed_entry` + remove `perform` from `create_dual_invoice_from_dropship_order`.
3. **Fix:** `get_courier_unremitted_financial_summary` → UWL `dropship_profit` (table `billing_profile_wallet_ledger` already dropped).
4. **Delete:** unused wallet components (`UniversalWallet.vue`, `WalletDepositModal`, `WalletWithdrawModal`, `WalletTransferModal`, `WalletStatementView`, `WalletReportsView`).
5. **After P5b:** revoke `authenticated` on `record_ledger_transaction`; wallet module uses staff RPCs only.

---

## Phase 7 — Cleanup + verification

**Goal:** Remove ambiguity; production data single books.

**Files:**

- Migration: drop `wallet_accounts.tenant_id` (or keep as generated alias — prefer drop)
- `supabase/schemas/public.sql`
- `doc/wallet/WALLET.md` — remove §1.4 “current gap” when done
- `doc/shop_order/DROPSHIP_MANAGEMENT.md` — wallet tenant wording if needed

**Verification checklist:**

- [ ] Child tenant Dropshipping: courier wallet shows balance (order 37 courier entity `1`).
- [ ] Company wallet shows tenant cash (parent pool).
- [ ] Customer wallet shows billing profile `31` ledger.
- [ ] `get_wallet_dashboard_summary` matches sum of accounts on parent book.
- [ ] New dropship order E2E: deliver → remit → payout flags.
- [ ] Standalone tenant unchanged (parent = self).
- [ ] `pnpm run backend:reset` on empty DB replays all migrations.

---

## Optional hotfix (not recommended alone)

**If UI must work before P0–P2:** change composables to query **child** `tenant_id` when `selectedTenant.parent_id` is set. Fixes display only; parent consolidated view stays wrong. **Do not** ship without full migration plan above.

---

## Related docs to sync after P7

- [`doc/MASTER_PLAN.md`](../MASTER_PLAN.md) — tenet #4 wording
- [`doc/shop_order/DROPSHIP_MANAGEMENT.md`](../shop_order/DROPSHIP_MANAGEMENT.md) — §7 wallet steps
- [`doc/sales_invoice/SALES_INVOICE.md`](../sales_invoice/SALES_INVOICE.md) — cross-link wallet books parity

## RPC spec index

| Doc | RPCs |
| :--- | :--- |
| [`LIST_WALLET_ENTITIES_RPC.md`](./LIST_WALLET_ENTITIES_RPC.md) | `list_wallet_entities_for_staff` |
| [`UNIVERSAL_WALLET_DETAIL_RPC.md`](./UNIVERSAL_WALLET_DETAIL_RPC.md) | `get_wallet_detail_for_staff`, `list_wallet_ledger_for_staff`, `record_wallet_manual_transaction_for_staff`, `reverse_wallet_ledger_entry_for_staff` |
| [`WALLET_LEGACY_RETIREMENT.md`](./WALLET_LEGACY_RETIREMENT.md) | Drops: `dispense_middleman_payout`, `ensure_dropship_invoice_billed_entry`; dead UI files |

---

*Created 2026-08-27 from wallet UI / order #37 parent-child mismatch analysis.*
