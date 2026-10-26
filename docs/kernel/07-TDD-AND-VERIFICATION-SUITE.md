# TDD and verification suite

**Job:** Testing specification and roadmap — what to automate so kernel changes do not drift from [01-SYSTEM-INVARIANTS](01-SYSTEM-INVARIANTS.md) and [06 golden scenarios](06-ACCOUNTING-FLOWS-AND-GOLDEN-SCENARIOS.md).

**As-built:** Most coverage is manual + production audit SQL; formal pgTAP / CI suite is **not_built** — this doc is the target pyramid.

---

## Tier 1 — Invariant unit tests (database)

Run in transaction + `ROLLBACK` or isolated DB (`backend:reset` fixture).

| Test | Assert |
| :--- | :--- |
| Issue then `UPDATE total_amount` | Blocked by RPC policy or trigger (target); today rely on code review + audit #4 |
| Alloc > pay amount | RPC raises; no `pay_allocations` row |
| Alloc > `get_bill_net_balances.due` | RPC raises |
| Void issued bill with pays | `cannot void a paid` |
| Negative pot / ledger | CHECK violation on insert |
| Credit note without parent | RPC raises |
| `cross_tenant_denied` (each money RPC) | Tenant A session cannot act on tenant B bill/pay |

Implement as SQL tests calling RPCs with `raises_ok` (pgTAP) or Supabase test harness when added.

---

## Tier 2 — Golden ledger pipeline tests

One test per scenario in [06-ACCOUNTING-FLOWS-AND-GOLDEN-SCENARIOS](06-ACCOUNTING-FLOWS-AND-GOLDEN-SCENARIOS.md):

1. Seed profiles + minimal stock (wholesale / dropship fixtures).
2. Call adapter + kernel RPC chain.
3. Snapshot: `bills`, `pay_allocations`, `get_bill_net_balances`, sum of custody ledger for profile.

Compare to frozen JSON fixture in repo (`supabase/tests/fixtures/` — **to create**).

---

## Tier 3 — Concurrency race tests

| Scenario | Expect |
| :--- | :--- |
| Two parallel collects on same bill due | One succeeds; one fails over-allocation OR serializes via bill `FOR UPDATE` |
| Two parallel issues on same stock line | One insufficient stock after lock |
| Double remittance POST (same order) | Second should no-op when `p_idempotency_key` exists (target) |

Use `pg_sleep` + two sessions or stress script against local Supabase. Document in CI only when stable.

---

## CI placement (target)

| Job | Scope |
| :--- | :--- |
| `backend:reset` | Migrations replay (existing) |
| `supabase test` / custom | Tier 1 + 2 on PR touching `bills_pays/` |
| Nightly | Tier 3 optional |

---

## Manual checklist before merge (money PR)

- [ ] [01](01-SYSTEM-INVARIANTS.md) PR checklist
- [ ] Golden scenario touched? Update [06](06-ACCOUNTING-FLOWS-AND-GOLDEN-SCENARIOS.md)
- [ ] New RPC? Update [04](04-RPC-AND-API-CONTRACTS.md) + `database.types.ts`
- [ ] Run audit queries in [08](08-AUDIT-RECONCILIATION-AND-RUNBOOK.md) on local seed data

## CI (Supabase)

| Job | Trigger | Command |
| :--- | :--- | :--- |
| Tier 1 + `cross_tenant_denied` | PR touching `supabase/schemas/bills_pays/`, `supabase/tests/` | `supabase test db` |
| Tier 3 races | Nightly (not every PR) | A2 idempotency + A5 cart parallel |
| Backup / PITR window | Weekly ops | Dashboard check `[verify Supabase docs]` |

See [PHASE-C-SUPABASE-RUNTIME.md](PHASE-C-SUPABASE-RUNTIME.md) (C4, C8).
