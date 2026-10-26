# Phase C — Supabase runtime hardening (money kernel)

**Scope:** Platform safety only. Does **not** change Phase A/B invariants, tax model, or RPC signatures except `[supabase-required]` items below.

**Assumption:** Hosted Supabase Postgres + Supavisor; app calls **PostgREST** (`supabase-js` RPC/REST), not raw `node-postgres` from the browser.

---

## C1. Connection pooler discipline

### Design note

Money paths must not rely on **session-scoped** state (`set_config(..., false)`, `SET`, temp tables, `LISTEN`, advisory locks held across requests). Supavisor **transaction mode** (port **6543**) `[verify against current Supabase docs]` assigns one server connection per transaction; session GUCs do not survive the next RPC.

**Audit (LIVE `bills_pays/03_rpcs.sql`):** no `set_config` in bills_pays RPCs. **Indirect risk:** `issue_sales_invoice` / AP payout may call procurement paths that use `set_config(..., true)` (transaction-local) — safe on transaction pooler **within the same RPC transaction**.

**Hard rule (doc 03):** kernel money RPCs never use session-level `SET` or `set_config(..., false)`.

### Connection policy table

| Component | Pooler mode | Port (typical) `[verify]` | Reason |
| :--- | :--- | :--- | :--- |
| PostgREST RPC writes (`post_customer_receipt_with_allocations`, `issue_sales_invoice`, `create_bill_adjustment`, `post_ap_payout_with_allocations`, `reverse_payment` when shipped) | **Transaction** | 6543 | One HTTP call = one transaction; no session state in bills_pays |
| PostgREST RPC reads (`get_bill_net_balances`, `list_bills_for_profile` when shipped) | **Transaction** | 6543 | Read-only, no session state |
| `supabase-js` from SPA (default) | **Transaction** (via API) | N/A (HTTPS → PostgREST) | No direct Postgres pool |
| Python ETL / `psql` migrations / `supabase test db` | **Session** or **direct** | 5432 / local 54322 | Migrations and pgTAP need session semantics |
| Edge Function with `postgres` driver (if added) | **Session** unless `prepare: false` | 5432 Session pooler `[verify]` | Named prepared statements break on transaction pooler |
| pg_cron jobs (C5) | **Direct** (in-DB) | internal | Runs inside Postgres |
| Long interactive `psql` on prod | **Forbidden** | 5432 | Policy — use read replica + break-glass |

### Money RPC classification (Phase A/B names)

| Class | Examples (LIVE) | Session state? | Pooler |
| :--- | :--- | :--- | :--- |
| Pay writers | `post_customer_receipt_with_allocations`, `post_ap_payout_with_allocations`, `dispense_middleman_payout_from_tenant` | No | Transaction |
| Bill writers | `create_sales_invoice*`, `issue_sales_invoice`, `create_bill_adjustment`, `sync_shipment_ap_bills` | No* | Transaction |
| Reversal | `reverse_payment` (Phase A) | No | Transaction |
| Reads | `get_bill_net_balances`, `get_bill_detail_bundle`, `list_bills_for_profile` (A7) | No | Transaction |
| Ledger | `record_ledger_transaction` | No | Transaction |

\*If stock issue triggers procurement `set_config(..., true)`, stays transaction-local.

### Config / code

No `[supabase-required]` RPC signature change. Optional comment header in `03_rpcs.sql`:

```sql
-- Pooler-safe: no session-level set_config; one RPC = one transaction (PostgREST).
```

### Tests

Tier 1: existing invariant suite (C4).

### Doc diff

**`03-TRANSACTIONS-LOCKING-AND-CONCURRENCY.md`** — add § “Pooler discipline” + hard rule (see §7 patches).

---

## C2. Prepared statement / driver hardening

### Design note

Browsers use **HTTPS + PostgREST** — no client-side prepared statements on the pooler.

Risk: **server-side** scripts (`python/`, CI, future Edge Functions) using `node-postgres` with named prepared statements against port **6543** → errors `[verify against current Supabase docs]`.

### Policy

| Client | Write path | Read path | Config |
| :--- | :--- | :--- | :--- |
| Quasar SPA | `supabase.rpc(...)` | `.from().select()` | Default pooler via Supabase URL (transaction) |
| Migrations / pgTAP | `supabase db` / local 54322 | same | Not through pooler |
| Optional worker | Session pooler **5432** OR `prepare: false` `[verify]` | Transaction 6543 OK for simple SELECT |

**Env (hosted):** `DATABASE_URL` (transaction, 6543) for app workers; `DATABASE_URL_SESSION` (5432) only if a worker needs prepared statements — document in runbook, not in frontend `.env`.

### Doc diff

**`05-ADAPTER-INTEGRATION-GUIDE.md`** — § “Supabase client discipline” (patch in §7).

### Tests

None (config/doc).

---

## C3. SECURITY DEFINER hardening

### Design note

~99 `SECURITY DEFINER` functions in `bills_pays/03_rpcs.sql`. Auth today is **per-RPC** (`is_tenant_staff`, `membership_has_module_action`) — not a single prologue.

**Target:** one helper, first statement in every money RPC.

### Helper SQL (migration sketch)

```sql
CREATE OR REPLACE FUNCTION public.assert_kernel_money_access(
  p_parent_tenant_id bigint,
  p_action text DEFAULT 'view'  -- view | edit | collect | payout
) RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_parent_tenant_id IS NULL THEN
    RAISE EXCEPTION 'parent_tenant_id required';
  END IF;
  IF public.is_superadmin() THEN
    RETURN;
  END IF;
  -- LIVE: membership via email; not JWT custom claim today
  IF NOT public.is_tenant_staff(p_parent_tenant_id)
     AND NOT public.user_can_manage_parent_tenant(p_parent_tenant_id) THEN
    RAISE EXCEPTION 'access denied for tenant %', p_parent_tenant_id;
  END IF;
  -- Optional: map p_action → membership_has_module_action (extend in same migration)
END;
$$;
```

> TODO(owner): Map `p_action` to exact grants (`global_invoice`, `payments`, …) per RPC — not specified in pack.

### RLS defense-in-depth (additive)

RPCs bypass RLS as `SECURITY DEFINER`; RLS blocks **direct** PostgREST table access.

**LIVE:** `bills`, `pays` already have policies on `issued_by_tenant_id` / `tenant_id`. **Gap:** tighten to `parent_tenant_id` consistently; add `audit_log`, `cashbook_point_pots` if missing.

```sql
-- Pattern (sketch): membership via current_user_email(), not JWT claim — unless you add app_metadata.tenant_id
CREATE POLICY kernel_bills_tenant_select ON public.bills
  FOR SELECT TO authenticated
  USING (
    public.is_superadmin()
    OR public.user_can_manage_parent_tenant(parent_tenant_id)
    OR public.membership_has_module_action(issued_by_tenant_id, 'global_invoice', 'view')
  );
```

JWT `parent_tenant_id` claim: **not specified in pack** — use membership helpers unless product adds claim.

### Tests — `cross_tenant_denied` (Tier 1, new class)

For each **money-moving** RPC (minimum set):

`post_customer_receipt_with_allocations`, `issue_sales_invoice`, `create_bill_adjustment`, `post_ap_payout_with_allocations`, `reverse_payment`

```sql
-- pgTAP pattern: seed tenant A staff + tenant B bill; call RPC with A session → raises
SELECT throws_ok(
  $$ SELECT public.issue_sales_invoice(<tenant_b_bill_id>) $$,
  'access denied%'
);
```

One test file per RPC or parameterized helper `test_cross_tenant_denied('issue_sales_invoice', ...)`.

### Doc diff

**`01-SYSTEM-INVARIANTS.md`** PR checklist — add auth prologue item (§7).

---

## C4. pgTAP + CI on Supabase CLI

### Design note

Phase A proposes `supabase/tests/bills_pays/`. **LIVE repo:** no pgTAP yet.

### Commands `[verify against current Supabase docs]`

```bash
# Local (from repo root)
pnpm run backend:local   # DB up + migrations
supabase test db         # runs supabase/tests/**/*.sql
```

Expected: `Files=..., Tests=..., ... Result: PASS` (exact format varies by CLI version).

### `config.toml` snippet

```toml
[db.seed]
# optional: seed minimal tenant for tests via sql_paths

# Tests discovered from supabase/tests/ by default [verify]
```

### CI (proposed — no workflow in repo today)

```yaml
# .github/workflows/kernel-db-tests.yml
on:
  pull_request:
    paths:
      - 'supabase/schemas/bills_pays/**'
      - 'supabase/tests/**'
      - 'supabase/migrations/*bills*'
jobs:
  pgtap:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: supabase/setup-cli@v1
      - run: supabase start
      - run: supabase test db
```

**Nightly:** Tier-3 race tests (A2 idempotency parallel, A5 cart race) — separate workflow `cron: '0 2 * * *'`.

### Doc diff

**`07-TDD-AND-VERIFICATION-SUITE.md`** — CI placement table (§7).

---

## C5. Extension usage

### Design note

Only **pg_cron** + **pgcrypto** as requested.

### pgcrypto — audit hash helper (Phase A A8)

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION public.kernel_audit_payload_hash(p_payload jsonb)
RETURNS text
LANGUAGE sql IMMUTABLE
AS $$
  SELECT encode(digest(p_payload::text, 'sha256'), 'hex');
$$;
```

Use in `kernel_audit_log.before_hash` / `after_hash` — no chain required unless product asks.

### pg_cron schedules `[verify extension enabled on hosted tier]`

```sql
SELECT cron.schedule(
  'kernel_audit_orphan_unallocated',
  '0 3 * * *',  -- daily 03:00 UTC
  $$ INSERT INTO kernel_audit_log (parent_tenant_id, action, entity_type, entity_id, payload)
     SELECT 0, 'audit_orphan_unallocated', 'pays', id::text, jsonb_build_object('pay_id', id)
     FROM pays p WHERE coalesce(unallocated_amount,0) > 0
       AND NOT EXISTS (SELECT 1 FROM cashbook_entries ce WHERE ce.source_id = p.id::text)
     LIMIT 100; $$
);

-- Mushak 9.1 draft: only after Phase B RPC exists
-- SELECT cron.schedule('mushak_91_draft', '0 4 1 * *', $$ SELECT get_mushak_9_1_extract(...) $$);

-- AR aging: prefer on-demand list_bills_for_profile unless MV added
-- SELECT cron.schedule('ar_aging_refresh', '0 4 * * *', $$ REFRESH MATERIALIZED VIEW CONCURRENTLY ... $$);
```

Run orphan detection as **read-only alert** (insert audit row / notify) — do not auto-mutate pays.

### Tests

Tier 1: `kernel_audit_payload_hash` deterministic.

### Doc diff

**`08-AUDIT-RECONCILIATION-AND-RUNBOOK.md`** — cron references orphan query §3.

---

## C6. Backup, PITR, and recovery

### Design note

Money ledger on **Free tier is not production-safe** `[verify against current Supabase docs]`: limited backups, no PITR, connection caps.

**Require Pro or above** for production kernel: PITR, better backup window, higher connection limit, extension support.

### Recovery runbook (add to 08)

1. **Stop writes:** disable pay/issue routes or revoke `authenticated` execute on writers (break-glass).
2. **Identify T0:** last good `kernel_audit_log` / pay id / migration version.
3. **PITR restore** to new project or branch DB at T0 − 1 min `[verify Supabase dashboard / branch flow]`.
4. **Reconcile:** run 08 audit SQL; compare `cashbook_entries.exchange_rate` (frozen FX, invariant 5) to physical till counts; compare `get_bill_net_balances` to bank statements.
5. **Replay:** forward migrations only after root-cause fix; never “fix” issued `total_amount` in SQL editor.
6. **Sign-off:** finance + eng before re-enabling traffic.

### Doc diff

**`08-AUDIT-RECONCILIATION-AND-RUNBOOK.md`** — new § “PITR recovery” (full text in §7 patch).

### Tests

None (ops).

---

## C7. Capacity and pricing plan

### Sizing formulas (not magic numbers)

| Store | Growth |
| :--- | :--- |
| `bill_lines` | `bills_per_month × avg_lines_per_bill` |
| `pays` | `payments_per_month` |
| `pay_allocations` | `≤ pays × avg_bills_per_payment` |
| `cashbook_entries` | `≈ pays × (1 + instruments_per_pay) × ledger_rows_per_pay` |
| `kernel_audit_log` | `≈ (bill_mutations + pays + allocs) × 1` after A8 |
| Storage | sum of row width × counts; index overhead ~30–50% |

**Connections:** `concurrent_users × (supabase-js pool default 1) + edge_workers × pool_size`. PostgREST multiplexes; bottleneck is **DB max connections** `[verify Pro limits]`.

**Free tier:** breached quickly once real pays + audit_log + entries accumulate — **use Pro from first real money traffic.**

**Compute add-on:** when p95 RPC latency rises or connection saturation on Pro `[verify metrics]`.

### Doc diff

Optional one paragraph in **`README.md`** kernel pack — link Phase C.

---

## C8. Migration / deployment discipline

### Hard rules

1. Schema changes only via `supabase migration new` → review → `pnpm run deploy:backend` / CI — **never** production SQL editor for DDL on money tables.
2. Pre-deploy gate for migrations touching `bills`, `pays`, `pay_allocations`, `cashbook_entries`, tax columns:
   - (a) Tier-1 test added/updated
   - (b) rollback note in migration comment
   - (c) confirmation: no silent `UPDATE` on issued rows

### Doc diff

**`07-TDD-AND-VERIFICATION-SUITE.md`** + **`PHASE-A-B-IMPLEMENTATION-PLAN.md`** cross-link.

---

## C9. What Supabase does NOT solve

| Concern | Owner |
| :--- | :--- |
| Cross-tenant authorization logic | RPC `assert_kernel_money_access` + RLS baseline |
| Idempotency on pays | Phase A A2 (app + DB unique index) |
| Money invariants | Phase A pgTAP |
| Frozen FX on ledger lines | Phase A kernel writers |
| Tax / Mushak compliance | Phase B |
| Cheque bounce business rules | `reverse_payment` + ops SOP |
| Preventing dashboard SQL on prod | **Policy + IAM** (not a Supabase feature) |

---

## Supabase runtime contract

| Component | Required tier `[verify]` | Pooler mode | Extensions | Env var | Test coverage |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Production kernel | **Pro+** | Transaction 6543 (app) | `pgcrypto`, `pg_cron` (if scheduled) | `VITE_SUPABASE_URL`, anon key; workers: `DATABASE_URL` session only if needed | Tier 1 every PR; Tier 3 nightly |
| Local dev | Docker (`supabase start`) | Direct 54322 | same as prod | `web/.env.local` | `supabase test db` |
| Migrations | N/A | Session/direct | — | `SUPABASE_ACCESS_TOKEN` CI | `backend:reset` optional |
| PostgREST RPCs | Hosted with project | Transaction via API | — | — | `cross_tenant_denied` per writer |

---

## Residual risks (operational)

1. **Dashboard SQL editor on production** — #1 corruption vector; disable or restrict to break-glass role.
2. **Service role key in frontend** — never; only Edge/server.
3. **Direct table INSERT via PostgREST** — RLS helps; revoke INSERT on `pays`/`bills` from `authenticated` if policies are too permissive (LIVE allows some INSERT — review).
4. **PITR restore without cash recon** — books disagree with physical till.
5. **Transaction pooler + future session RPC** — code review must enforce C1 rule.
6. **Platform limit changes** — re-verify pooler ports and PITR annually.

---

## Deploy checklist (sign before production money traffic)

- [ ] Project on **Pro+** with **PITR enabled** `[verify]`
- [ ] All Phase A Tier-1 tests green in CI on `main`
- [ ] `assert_kernel_money_access` (or equivalent) on all money RPCs
- [ ] `cross_tenant_denied` tests for pay/issue/adjust/reverse writers
- [ ] App uses Supabase **HTTPS API** only (no 6543 from browser)
- [ ] Workers documented: transaction vs session URL
- [ ] Migrations applied via CI, not dashboard
- [ ] 08 PITR runbook printed / linked in on-call
- [ ] pg_cron orphan audit scheduled (or manual weekly until enabled)
- [ ] Policy: no prod ad-hoc SQL without ticket + second reviewer
- [ ] Phase B tax (if live): `tax_settings` seeded per tenant

---

## §7 — Doc patches (apply to kernel docs)

### `03-TRANSACTIONS-LOCKING-AND-CONCURRENCY.md` — append

```markdown
## Pooler discipline (Supabase)

- Money RPCs: **no session-level `SET`** and no `set_config(..., false)`.
- PostgREST / transaction pooler (port 6543): one RPC = one transaction — default for all `bills_pays` writers.
- Use session pooler (5432) or direct DB only for migrations, pgTAP, pg_cron, and drivers that require named prepared statements.
- See [PHASE-C-SUPABASE-RUNTIME.md](PHASE-C-SUPABASE-RUNTIME.md) connection policy table.
```

### `01-SYSTEM-INVARIANTS.md` — PR checklist append

```markdown
- [ ] Every `SECURITY DEFINER` money RPC calls `assert_kernel_money_access` (or stricter) as **first** statement
- [ ] No session-scoped `set_config` / `SET` in money RPC path
```

### `05-ADAPTER-INTEGRATION-GUIDE.md` — append

```markdown
## Supabase client discipline

- Adapters call **RPCs** via `supabase-js` (PostgREST), not raw Postgres from the SPA.
- Do not use transaction-pooler URLs with server drivers that cache prepared statements; use session pooler (5432) or disable prepare mode `[verify Supabase docs]`.
- Writes and reads use the same Supabase project URL unless a documented worker uses `DATABASE_URL_SESSION`.
```

### `07-TDD-AND-VERIFICATION-SUITE.md` — append

```markdown
## CI (Supabase)

| Job | Trigger | Command |
| :--- | :--- | :--- |
| Tier 1 | PR touching `supabase/schemas/bills_pays/`, `supabase/tests/` | `supabase test db` |
| Tier 3 races | Nightly cron | idempotency + cart race tests |
| Backup verify | Weekly manual / cron | confirm PITR window `[verify dashboard]` |
```

### `08-AUDIT-RECONCILIATION-AND-RUNBOOK.md` — append

```markdown
## PITR recovery (production)

1. Stop money writers. 2. Pick restore time T0 before incident. 3. Restore via Supabase PITR `[verify]`. 4. Run §1–§3 audit SQL; reconcile physical cash vs `cashbook_point_pots` and frozen `cashbook_entries.exchange_rate`. 5. Replay migrations after fix. Do not edit issued `total_amount` in SQL editor.

**Tier:** Pro+ required for production ledger.

## Scheduled audits (pg_cron)

Daily orphan-unallocated check (see PHASE-C-SUPABASE-RUNTIME.md C5). Alert only — no auto-delete.
```

---

## Self-check

| Item | Done |
| :--- | :--- |
| Every money RPC pooler classification | Table C1 (by class; enumerate in tests backlog) |
| `cross_tenant_denied` per money RPC | Specified C3; implement with Phase A tests |
| Auth prologue standardized | `assert_kernel_money_access` sketch |
| PITR + frozen FX in runbook | C6 + 08 patch |
| Tier named + justified | C6/C7 Pro+ |
| Platform claims labelled | `[verify against current Supabase docs]` throughout |
| What Supabase does not solve | C9 |
