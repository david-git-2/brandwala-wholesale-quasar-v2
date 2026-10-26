# Money kernel — Phase A (ops gaps) & Phase B (BD tax) implementation plan

**Status:** Phase A = **proposed** (review before build). Phase B = **design only** — do not implement until Phase A passes CI.

**Prerequisites:** [00-ONBOARDING-AND-AUDIT.md](00-ONBOARDING-AND-AUDIT.md), kernel `01`–`08`, live SQL `supabase/schemas/bills_pays/`.

**Naming:** **LIVE** = current DB/RPC names. **TARGET** = `kernel_*`, `status`, full source plugs.

---

# PHASE A — CLOSE BLOCKING OPERATIONAL GAPS

**Delivery order:** A1 → A2 → … → A8 (single epic or stacked PRs; **A1 must merge first**).

**Bundle paths (proposed):**

- Migrations: `supabase/migrations/YYYYMMDDHHMMSS_kernel_phase_a_*.sql` (split per item or one squashed after review)
- Tests: `supabase/tests/bills_pays/` + `pnpm run backend:test` (new script)
- Schemas: mirror in `supabase/schemas/bills_pays/` after each migration

---

## A1. Invariant test suite (07 Tier 1) — FIRST

### 1. Design note

Introduce **pgTAP** via Supabase local DB. Tests run in `BEGIN` … RPC … `ROLLBACK` with seeded tenant/profile/stock fixtures. Gate: any PR touching `supabase/schemas/bills_pays/` or `supabase/migrations/*bills*` runs `supabase test db`.

**Gap today:** No pgTAP in repo (verified). Issue-then-`UPDATE total_amount` may **not** be blocked by trigger — test documents current behavior and fails until trigger or revoke direct UPDATE is added.

### 2. Migration / infra diff

```sql
-- supabase/tests/bills_pays/001_invariants.sql (pgTAP)
-- Requires: CREATE EXTENSION IF NOT EXISTS pgtap;
```

Optional hardening migration (if test proves hole):

```sql
CREATE OR REPLACE FUNCTION public.bills_deny_issued_total_mutate()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.invoice_status = 'issued' AND NEW.total_amount IS DISTINCT FROM OLD.total_amount THEN
    RAISE EXCEPTION 'issued bill total_amount is immutable';
  END IF;
  RETURN NEW;
END;
$$;
-- Only if product accepts trigger on bills; else enforce RPC-only writes + REVOKE UPDATE on sensitive cols from authenticated.
```

### 3. Tests (Tier 1)

| Test name | Assert |
| :--- | :--- |
| `test_issue_then_update_total_raises` | After `issue_sales_invoice`, `UPDATE bills SET total_amount` fails |
| `test_alloc_exceeds_pay_amount` | `post_customer_receipt_with_allocations` alloc sum > amount → exception, no alloc rows |
| `test_alloc_exceeds_net_due` | Alloc > `get_bill_net_balances` due → exception |
| `test_void_issued_with_pays_raises` | Void path → `cannot void a paid` |
| `test_negative_pot_check` | INSERT pot `amount = -1` → CHECK |
| `test_credit_note_requires_parent` | `create_bill_adjustment` / insert without `parent_bill_id` → exception |

### 4. Doc changes

| File | Change |
| :--- | :--- |
| `07-TDD-AND-VERIFICATION-SUITE.md` | Replace “not_built” with path `supabase/tests/bills_pays/`, CI command |
| `README.md` | Add “Run tests: `pnpm run backend:test`” |
| `package.json` | `"backend:test": "supabase test db"` |

### 5. RPC signatures

None (tests only).

---

## A2. Idempotency on payment ingestion (BP12)

### 1. Design note

Remittance/collect retries must not duplicate `pays` or allocations. Scoped unique: `(parent_tenant_id, idempotency_key)` where key not null — `parent_tenant_id` derived from `p_tenant_id` on pay writers.

### 2. Migration diff

```sql
ALTER TABLE public.pays
  ADD COLUMN IF NOT EXISTS parent_tenant_id bigint,
  ADD COLUMN IF NOT EXISTS idempotency_key text;

CREATE UNIQUE INDEX pays_idempotency_uq
  ON public.pays (parent_tenant_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;
```

### 3. RPC signature diff

**LIVE** — extend:

```text
post_customer_receipt_with_allocations(
  ...,
  p_idempotency_key text DEFAULT NULL
) RETURNS pays

post_ap_payout_with_allocations(
  ...,
  p_idempotency_key text DEFAULT NULL
) RETURNS pays
```

**TARGET:** `kernel_post_payment(..., p_idempotency_key text DEFAULT NULL)`

Behavior: if conflict on unique index → `SELECT` existing pay by key, return row (no new alloc).

### 4. Tests

| Tier | Name |
| :--- | :--- |
| 1 | Same key twice in one transaction → one row |
| 3 | Two parallel sessions same key → one row, one alloc set |

### 5. Doc changes

| File | Section |
| :--- | :--- |
| `03-TRANSACTIONS-LOCKING-AND-CONCURRENCY.md` | Idempotency table → **built** |
| `04-RPC-AND-API-CONTRACTS.md` | `kernel_post_payment` idempotency behavior |
| `01-SYSTEM-INVARIANTS.md` | PR checklist: idempotency on external callbacks |

---

## A3. Reversal RPC (WA13 / BP12)

### 1. Design note

Cheque bounce SOP (08) must not require manual SQL. Reverse pay → remove allocs → refresh bill caches via existing refresh helper (grep `refresh_bill_payment` / payment status updaters in `03_rpcs.sql`) → reverse custody ledger entries linked to `p_pay_id`.

**LIVE alias:** implement `reverse_payment` and document as **TARGET** `kernel_reverse_payment` wrapper.

Must **not** `UPDATE` issued `total_amount`.

### 2. Migration diff

```sql
ALTER TABLE public.pays
  ADD COLUMN IF NOT EXISTS reversed_at timestamptz,
  ADD COLUMN IF NOT EXISTS reversal_reason text,
  ADD COLUMN IF NOT EXISTS reverses_payment_id bigint REFERENCES public.pays(id);

CREATE TABLE public.kernel_audit_log (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  parent_tenant_id bigint NOT NULL,
  actor_email text,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);
-- A8 may extend; minimal row for reversal here
```

### 3. RPC signatures

**TARGET / LIVE (new):**

```text
reverse_payment(
  p_pay_id bigint,
  p_reason text,
  p_reverse_leftover boolean DEFAULT true
) RETURNS jsonb  -- { pay_id, reversed_allocations, bills_refreshed[] }
```

Steps (in one transaction): `SELECT pays FOR UPDATE`; reject if `voided_at` or `reversed_at`; delete `pay_allocations`; call bill due refresh; if `p_reverse_leftover`, debit custody mirror of original credit; set `reversed_at`; audit log row.

### 4. Tests

| Tier | Name |
| :--- | :--- |
| 2 | `golden_cheque_bounce`: collect 1500 → reverse → `due_amount` restored, custody 0, `total_amount` unchanged |

### 5. Doc changes

| File | Section |
| :--- | :--- |
| `08-AUDIT-RECONCILIATION-AND-RUNBOOK.md` | Cheque SOP → call `reverse_payment` |
| `04-RPC-AND-API-CONTRACTS.md` | `kernel_reverse_payment` → **LIVE:** `reverse_payment` |
| `02-STATE-MACHINES-AND-LIFECYCLES.md` | Pay void/reverse transition row |

---

## A4. Cashbook point enforcement (BP15)

### 1. Design note

Invariant #6: tenant operating cash must have `cashbook_point_id`. **LIVE:** column nullable on `pays` (02_tables.sql). Backfill: `tax_settings` not needed — use `tenant_preferences.default_cashbook_point_id` or new column on `tenants.preference` jsonb.

### 2. Migration diff

```sql
-- Backfill UPDATE pays SET cashbook_point_id = <default> WHERE ... tenant cash move AND cashbook_point_id IS NULL;

ALTER TABLE public.pays
  ADD CONSTRAINT pays_tenant_cash_requires_point CHECK (
    cashbook_point_id IS NOT NULL
    OR source IN ('store_credit', ...) -- profile-only custody paths; enumerate from live writers
  );
```

(Exact `source` exempt list must match `post_customer_receipt_with_allocations` / AP writers — **decision needed** in implementation PR.)

### 3. RPC guards

Raise: `tenant cash movement requires cashbook_point_id` when posting BDT to tenant books without point.

### 4. Tests

Tier 1: collect with cash instrument, null point → raises (after backfill).

### 5. Doc changes

`01-SYSTEM-INVARIANTS.md` §6 — mark **enforced in LIVE** when merged.

---

## A5. ATP cart race (03)

### 1. Design note

**LIVE:** `add_to_shop_cart` checks `global_stock_atp_qty` without lock (shop_order `03_rpcs.sql`). Fix: in same transaction as cart insert, `SELECT * FROM global_stocks WHERE id = ? FOR UPDATE` then re-check ATP.

Alternative (larger): reservation row lock — defer unless FOR UPDATE insufficient.

### 2. Migration diff

RPC-only change in `shop_order/03_rpcs.sql` (or `bills_pays` if moved). No DDL.

### 3. Tests

Tier 3: two sessions, last unit, parallel `add_to_shop_cart` → one success, one `insufficient stock`.

### 4. Doc changes

`03-TRANSACTIONS-LOCKING-AND-CONCURRENCY.md` — remove “shop cart race” caveat; link A5 test.

---

## A6. Single-currency shipment AP (WA15)

### 1. Design note

**LIVE:** `sync_shipment_ap_bills` — replace grouping to one bill per `(ap_kind/bucket, currency_code)` with `source_key = '{bucket}:{currency}'`. **Invariant 4:** never edit issued mixed-currency header — corrective **credit notes** + new split bills (per 01).

### 2. Migration diff

- Rewrite `sync_shipment_ap_bills` body (copy from `schemas/procurement` or `bills_pays` after grep).
- Data migration script (DML migration): identify mixed-currency issued AP → `create_bill_adjustment` voiding face + re-sync split drafts → issue.

### 3. RPC signatures

Unchanged names; behavior change documented.

### 4. Tests

Tier 2: shipment with USD material + GBP freight → two bills, two `source_key`s; Tier 1: one bill cannot have two `currency_code` on lines (when line currencies exist).

### 5. Doc changes

`05-ADAPTER-INTEGRATION-GUIDE.md`, `01` §4 — WA15 **done**; `06` Scenario B — remove “live may differ”.

---

## A7. Read RPCs (BP10)

### 1. Design note

Reports must not re-sum `pay_allocations` ad hoc. `list_bills_for_profile` calls `get_bill_net_balances` per bill (or shared SQL function `bill_net_balance_row(bill_id)`).

### 2. RPC signatures (new LIVE)

```text
list_bills_for_profile(
  p_parent_tenant_id bigint,
  p_profile_id bigint,
  p_from date,
  p_to date,
  p_kind text DEFAULT 'all'  -- 'ar' | 'ap' | 'all'
) RETURNS SETOF jsonb

get_custody_balance(
  p_parent_tenant_id bigint,
  p_profile_id bigint DEFAULT NULL
) RETURNS jsonb
-- { profiles: [{ profile_id, currency_code, balance }], aggregate: {...} }
```

**TARGET:** same names under `kernel_` prefix later.

`get_custody_balance`: sum `cashbook_entries` / `cashbook_accounts` for `entity_type` customer (grep live ledger entity types).

### 3. Tests

Tier 2: Scenario C profile → custody 500 after overpay; list shows B1 paid, B2 due 0.

### 4. Doc changes

`04-RPC-AND-API-CONTRACTS.md` Read RPCs section; `05` — replace “when BP10 lands”; `00-gaps` (external) BP10 done.

---

## A8. Audit log

### 1. Design note

Replace heuristic `updated_at > created_at + 1 minute` (08 §4). Append-only `kernel_audit_log` (or extend A3 table): `actor_email`, `action`, `entity_type`, `entity_id`, `before_hash`, `after_hash`, `metadata jsonb`.

Writers: issue, void, pay, alloc, reverse, adjustment issue.

### 2. Migration

```sql
CREATE TABLE public.kernel_audit_log (...);  -- see A3
CREATE VIEW public.v_issued_bill_mutations AS
  SELECT * FROM public.kernel_audit_log
  WHERE entity_type = 'bill' AND action IN ('issue','void','adjustment_issue','total_mutate_attempt');
```

### 3. Doc changes

`08-AUDIT-RECONCILIATION-AND-RUNBOOK.md` §4 → query view, deprecate heuristic SQL.

---

## Phase A — combined deliverables checklist

| Item | Migration | Tests | Docs |
| :--- | :---: | :---: | :---: |
| A1 | optional trigger | pgTAP suite + CI | 07, README, package.json |
| A2 | pays.idempotency_key | T1 + T3 | 03, 04, 01 |
| A3 | audit_log + pays reversal cols | T2 bounce | 04, 08, 02 |
| A4 | backfill + CHECK | T1 | 01 |
| A5 | RPC only | T3 | 03 |
| A6 | sync rewrite + DML | T2 | 01, 05, 06 |
| A7 | RPC only | T2 | 04, 05 |
| A8 | audit_log + view | T1 insert on pay | 08 |

**Gate:** `pnpm run backend:test` green + `backend:local` + `backend:types:local`.

---

# PHASE B — BANGLADESH-FIRST TAX LAYER (DESIGN ONLY)

**Do not implement until Phase A is accepted.**

---

## B1. Tax model

### 1. Design note

Per-line tax on `bill_lines` (not per-bill). **Source (defaults):** VAT & SD Act 2012; NBR rate schedules; Finance Act 2026 for threshold/tier changes **(rates must be verified at seed time — not legal advice in code comments).**

### 2. Migration sketch

```sql
CREATE TABLE public.tax_codes (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  parent_tenant_id bigint NOT NULL,
  code text NOT NULL,
  description text NOT NULL,
  rate numeric(5,2) NOT NULL,
  schedule text NOT NULL CHECK (schedule IN ('first','second','third','standard')),
  effective_from date NOT NULL,
  effective_to date,
  is_active boolean NOT NULL DEFAULT true,
  UNIQUE (parent_tenant_id, code, effective_from)
);

ALTER TABLE public.bill_lines
  ADD COLUMN tax_code_id bigint REFERENCES public.tax_codes(id),
  ADD COLUMN tax_rate numeric(5,2),
  ADD COLUMN tax_amount numeric(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN tax_inclusive boolean NOT NULL DEFAULT false;
```

Seed via migration DML from `tax_settings` template tenant 0 → copy on tenant bootstrap.

### 3. Tests (Tier 1, when built)

Mixed rates on draft → issue freezes `tax_rate` on line; UPDATE line tax after issue → blocked.

### 4. Doc changes

New `09-TAX-AND-COMPLIANCE.md`; `01` invariant **#8** (frozen line tax); `kernel-schema.md` bill_lines columns.

---

## B2. Total and net balance semantics

### 1. Design note

**TARGET:** `total_amount` = **gross (tax-inclusive)** face. **LIVE today:** may be pre-tax on some desks — **decision needed:** migration to gross for BD tenants only vs global.

`get_bill_net_balances` **additive** keys:

```json
{ "tax_total", "taxable_total", "exempt_total" }
```

Existing keys unchanged. CN/DN lines copy parent line `tax_code_id` + frozen rate.

### 2. RPC diff

Extend `get_bill_net_balances` and `issue_sales_invoice` line stamper.

### 3. Doc changes

`02` §2 revenue timing + tax; `06` scenarios E–G.

---

## B3. Mushak 6.3 fields

### 1. Design note

**Source:** NBR Mushak 6.3 format; BIN mandatory above BDT 25,000 **(threshold in `tax_settings.bin_required_above`, default 25000)**.

```sql
ALTER TABLE public.profiles ADD COLUMN bin text;

CREATE TABLE public.bill_tax_snapshot (
  bill_id bigint PRIMARY KEY REFERENCES public.bills(id),
  supplier_name text, supplier_address text, supplier_bin text,
  buyer_name text, buyer_address text, buyer_bin text,
  issued_at timestamptz NOT NULL,
  transport text,
  lines jsonb NOT NULL  -- per-line ex-VAT, inc-VAT, VAT%, SD%
);
```

Issue RPC: if gross > threshold and buyer BIN null → `RAISE WARNING` or soft `jsonb` warning return **(decision needed: warn vs block).**

---

## B4. VDS (AP / pay side)

### 1. Design note

**Source:** VAT Act VDS provisions; NBR circulars on rates (5%, 7.5%, 10%, 15% examples in prompt — seed in `tax_settings.vds_rates jsonb`).

Fields on `pay_allocations` or `pay_deductions`:

`vds_applicable`, `vds_rate`, `vds_amount`

Guard: if supplier Mushak 6.3 at full VAT on bill → **skip VDS** at pay.

`vds_register` VIEW for Mushak 9.1.

**Not on AR invoice lines.**

---

## B5. AIT / TDS (pay level)

Separate from VDS. **Source:** Finance Act 2026 / IT Rules 2026 §89–§90 **(verify sections in seed doc).**

`pay_deductions( pay_id, kind='ait', section text, rate, amount )`

Threshold default BDT 50,000 goods — `tax_settings.ait_goods_threshold`.

Does not change `bills.total_amount`.

---

## B6. Turnover tier

**Source:** Finance Act 2026 turnover limits (prompt: 3M / 5M BDT — **config**, not constants; note 2025 law change from 30M).

```sql
CREATE TABLE public.tax_settings (
  parent_tenant_id bigint PRIMARY KEY,
  country_code text NOT NULL DEFAULT 'BD',
  tenant_tax_tier text NOT NULL DEFAULT 'vat_registered', -- exempt | turnover | vat_registered
  turnover_exempt_threshold numeric,
  turnover_max_threshold numeric,
  turnover_tax_rate numeric,
  standard_vat_rate numeric,
  reduced_rates jsonb,
  bin_required_above numeric,
  ...
);
```

Issue guard: tier `turnover` → VAT-6.9 path, block Mushak 6.3 at 15%.

---

## B7. Report RPCs (minimum)

Built on A7 — no alloc re-sum:

| RPC | Purpose |
| :--- | :--- |
| `get_mushak_9_1_extract(p_tenant, period)` | Output/input tax, VDS, net payable |
| `list_purchase_register` / `list_sales_register` | 6.1 / 6.2 lines |
| `list_ar_aging` / `list_ap_aging` | Buckets from `list_bills_for_profile` |
| `get_customer_statement` | Wrapper profile + date range |
| `get_daily_sales_summary` | take vs condition + tax split |
| `get_custody_balance` | Phase A |

---

## B8. Configurability

All BD defaults in `tax_settings` + `tax_codes` per `parent_tenant_id`. Override `country_code` ≠ `BD` → empty seed, tenant-owned rates.

`05-ADAPTER-INTEGRATION-GUIDE.md` § “Tax” — adapters read `tax_settings`, pass line `tax_code` on upsert draft.

---

## B9. Golden scenarios (doc 06)

| Scenario | Assert |
| :--- | :--- |
| **E** Mixed 15% + 5% + exempt | Mushak snapshot, `tax_total`, 9.1 output split |
| **F** AP + VDS pay | cash = gross − VDS, `vds_payable`, register row |
| **G** CN on 15% line | same tax_code, parent `total_amount` unchanged |

(Add numeric tables when implementing — mirror A–D format.)

---

# COMBINED RISK REGISTER

| Risk | Phase | Severity | Mitigation | Residual |
| :--- | :--- | :--- | :--- | :--- |
| Phase A scope creep blocks release | A | Major | Stack PRs A1→A8; timebox A6 DML | Some WA15 rows need manual finance sign-off |
| pgTAP not in CI initially | A | Major | A1 adds `backend:test` on path filter | Flaky until fixtures stable |
| Idempotency without adapter adoption | A | Major | Require key from remittance API + shop | Old clients can still double-post |
| `reverse_payment` partial custody edge cases | A | Major | T2 golden + audit log | Complex multi-bill pays need playbook |
| CHECK on pays.point breaks legacy sources | A | Blocker | Enumerate exempt `source` values before NOT NULL | Misclassified pays block collect |
| WA15 backfill wrong CN amounts | A | Blocker | Finance review script; dry-run mode | Historical AP mismatch until corrected |
| `total_amount` gross vs net migration | B | Blocker | BD-only flag; do not flip wholesale tenants blindly | Cross-border tenants need explicit mode |
| Tax rates wrong vs NBR | B | Blocker | Rates only in `tax_codes`; legal review of seed | Tenant must update when law changes |
| VDS vs full VAT invoice guard wrong | B | Major | Explicit bill flag `supplier_mushak_6_3_at_standard_rate` | Disputes with suppliers |
| AIT vs VAT double-count in reports | B | Major | Separate `pay_deductions` ledger accounts | Report RPC bugs |
| Turnover tier mis-set | B | Major | Onboarding wizard + issue guard | Wrong invoice type issued |
| `get_bill_net_balances` key explosion | B | Minor | Additive JSON only | Client parsers must update |
| Performance: list_bills N× net balance | A | Minor | SQL function batch net balances | Large statements slow |
| Audit log PII | A | Minor | Store email hash option | GDPR not specified in pack |

---

## Self-check (delivery)

| Question | Answer |
| :--- | :--- |
| Phase A tests before features? | **Yes** — A1 first in plan |
| BD defaults in `tax_settings`? | **Yes** — Phase B design |
| `total_amount` gross + additive tax keys? | **Proposed** — LIVE migration flagged |
| VDS on AP/pay? | **Yes** |
| AIT separate? | **Yes** |
| Turnover blocks Mushak 6.3? | **Yes** — guard in B6 |
| Non-BD override without deploy? | **Yes** — tenant rows |
| Scenarios E–G? | **Outlined** — numbers at implement time |
| Inferring? | LIVE `get_bill_net_balances` shape verified in schema grep; exempt pay `source` list **not specified in pack** |
| Phase B code shipped? | **No** — by instruction |

---

**Next step for team:** Review Phase A plan → approve A1 CI → implement A1–A8 → re-run fault audit in [00-ONBOARDING-AND-AUDIT.md](00-ONBOARDING-AND-AUDIT.md) → then unlock Phase B implementation.
