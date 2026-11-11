# Money spine v2 — overview

Canonical money kernel for TradeFlow.

| Meta | Value |
| :--- | :--- |
| **Doc type** | Design Spec / implementable LLD (kernel contract) |
| **Stage** | Draft → Under Review (target contract; live SQL may lag) |
| **Audience** | Staff engineers implementing the kernel; feature authors calling RPCs |
| **Live SQL** | `[ASSUMPTION]` may lag this contract until cutover — `supabase/schemas/bills_pays/`. Gap inventory is **not** in this folder. `[TODO-ARCH: publish live-vs-v2 gap list — owner, date]` |

## Ship blockers (fix before prod)

| # | Risk | Contract fix |
| :---: | :--- | :--- |
| 1 | Caller-supplied `exchange_rate` / `books_rate` can mint money | Rates **server-resolved** from `books_exchange_rates`; rate row id in `refs` (I35). Override needs `fx_override` + reason + tolerance band. |
| 2 | `public` RPCs may be callable by `anon` | `REVOKE EXECUTE … FROM PUBLIC, anon, authenticated`; grant only the 16 public RPCs to `authenticated`. Real assert — see [05-security.md](05-security.md). |
| 3 | `rpc_apply_document_settlement` can cross-tenant | Every bill/pot read/write includes `tenant_id = p_tenant_id`. |
| 4 | AP pay can mark bills paid without paying creditor; `from_pot = to_pot` | **Option C:** derive `to_pot` from payee profile + bill currency (I30, I31, I32). Reject missing payee pot. |
| 5 | Void then replay idempotency key moves cash again | Keys **permanent per tenant**; replay returns original result + current status (I24). New attempt needs new key. |
| 6 | `rpc_pay_bills` parameter order invalid in PostgreSQL | Required params first, `DEFAULT` params last. |

## Problem & why this exists

Money (cash pots, bills, settlements) must be one kernel so AR/AP/wallet/credit notes cannot diverge on balances, voids, or idempotency. Feature modules call RPCs only; they do not invent parallel ledgers.

**In scope:** tables, triggers, write/read RPCs, views, invariants, security contract, and the test matrix in this folder.

**Non-goals (out of this folder):** cutover adapters, dual-write with legacy `bills_pays` writers, UI desks, reporting rollups beyond the listed read RPCs/views, ops audit SQL (see kernel `08-AUDIT-RECONCILIATION-AND-RUNBOOK.md`).

## Mental model

```text
profile → cashbook (points / pots)
bill (who owes whom) → bill_settlements → pays (optional) → pots
```

- **Bill** = paper obligation (invoice, AP, credit note, debit note).
- **Settlement** = how much of a bill was satisfied (`pay` with cash, or `document` from a **credit_note**).
- **Pays** = one cash movement between pots (or to/from external). Only `settlement_kind=pay` rows link a pays row.
- **Pot `amount`** is the only live cash balance (see I5). Account header balances are not spine truth (`[OPEN QUESTION]` who may write `cashbook_accounts.*_balance` — see [01-schema.md](01-schema.md) §3.2).
- **Tenant self-profile:** one system `profiles` row per tenant (`is_tenant_self = true`). AR creditor `to_profile_id` = that profile (not an arbitrary id). Provisioned in `rpc_provision_tenant_cashbook`.

Reports and feature code call **only** the RPCs and views in [02-actions.md](02-actions.md). They do not write kernel tables. Kernel tables live in schema `money_kernel`; clients see thin `public.rpc_*` wrappers only.

## Locked decisions

| Topic | Rule |
| :--- | :--- |
| Credit note | CN is a bill (`parent_bill_id` required; parties = swap of parent). **`rpc_apply_document_settlement`** applies remaining CN due onto a target with the **same party pair** (`target.from = CN.to`, `target.to = CN.from`; often the parent, may be another open bill). Partial applies allowed. No cash. Debit notes = normal bills (cash pay only). |
| Settlements | `settlement_kind`: `pay` \| `document`. `pays_id` required for `pay`, null for `document`. `source_bill_id` = credit_note bill for `document`. |
| Events on settle | Any `paid_amount` change → `payment_applied` / `payment_reversed` (T6). Kind of settle is on `bill_settlements.settlement_kind`, not a separate event type. |
| Multi-bill cash | **`rpc_pay_bills`**: one pays + many `pay` settlements. **`rpc_pay_bill`**: one bill (wrapper). |
| Overpay | Each allocation ≤ that bill’s `due_amount`. Sum of `pay` settlement books ≤ `pays.books_amount`. Leftover cash may sit **unapplied** on the pays row. |
| Writers | **SECURITY DEFINER** + `SET search_path` + `assert_kernel_money_access`. Clients: `EXECUTE` on RPCs only, no table DML. |
| Document idempotency | `bill_settlements.idempotency_key` unique per tenant when set (permanent; void does not free). Partial CN applies allowed (no unique on bill+source). |
| FX | `kind=payment`: from pot, to pot, and bill share one `currency_code`; `exchange_rate = 1`. FX first via **`rpc_transfer_p2p`**. Transfer FX rates server-resolved like books rates (I35). |
| Pays kinds | `deposit`, `withdrawal`, `transfer`, `payment` only (no `adjustment`). |
| Bill parties | **Payer / payee**. `from_profile_id` = debtor. `to_profile_id` = creditor. Cash pay uses a pot owned by `from_profile_id`. AR: from=customer, to=**tenant self-profile**. AP: from=tenant self-profile, to=vendor. |
| Credit note cash | Never pay a `credit_note` with `rpc_pay_*`. Only `rpc_apply_document_settlement`. No write-off on CN (void or apply). Document target must not be a `credit_note`. |
| Multi-bill correct | `rpc_update_pays` restricted to `kind=payment`, single-bill allocations only; posting via `fn_post_pays()`. Multi-bill fix = `rpc_void_pays` + `rpc_pay_bills`. |
| Status reverse | Voiding a settlement may move `paid → partial/issued` and `partial → issued`. T4 allows those reverse paths. |
| Void cash | `rpc_void_pays` refuses if the to-pot no longer holds the credit (money already moved out). Transfer out first or top up before void. |
| Books alloc | Settlement `allocated_books_amount` covers allocated cash only; last line absorbs rounding. Unapplied cash leaves books on the pays row. **Bills use exact arithmetic; 0.01 tolerance only on books (D1).** |
| Multi-bill void | `rpc_void_bill` refuses if the bill sits on a multi-bill pays (would reverse sibling bills). Void that pays via `rpc_void_pays` first. |
| Create status | `rpc_create_bill` always inserts `draft`; issue only via `auto_issue` / `rpc_issue_bill`. `total_amount > 0` at issue. |
| Idempotency keys | **Permanent per tenant** for pays, bills, and settlements. Replay with same key returns the original row id(s) and **current** status (e.g. voided pays). Different payload with same key → `idempotency_conflict` via `request_hash`. New cash/bill/settlement attempt needs a **new** key. |
| CN parties | Credit note `from`/`to` = swap of parent (`from=parent.to`, `to=parent.from`). Parent must be issued/partial/paid/written_off. Same currency. Σ non-voided CN totals ≤ parent total (I33). |
| AR / AP to-pot | Kernel **derives** `to_pot` from each bill’s `to_profile_id` + bill `currency_code` (payee’s pot on that currency). Reject if payee has no pot. Caller may pass `p_to_pot_id` only when it equals that derived pot (explicit custody confirmation). No tenant-default collection pot fallback. |
| Lines at issue | Bill lines frozen after issue; Σ lines = `total_amount` at issue (I34, T8). |
| Invoice number | `invoice_no` null on draft; allocated at **`rpc_issue_bill`** (not create). |

## Alternatives (recorded)

| Decision | Chosen | Rejected | Why rejected |
| :--- | :--- | :--- | :--- |
| Cash truth | Pot `amount` via `fn_pays_apply` only | Parallel `cashbook_entries` ledger as spine truth | Old design dropped `cashbook_entries` ([01-schema.md](01-schema.md) §4); one balance writer avoids ledger/pot drift |
| Bill↔cash link | `bill_settlements` (`pay` \| `document`) | Separate `pay_allocations` + instruments tables | Dropped `pay_allocations` / `pay_instruments`; one allocation table covers cash and CN document apply |
| FX on payment | Forbid; `exchange_rate=1`; FX via `rpc_transfer_p2p` first | In-pay FX | Keeps I7b simple; books rate still snapshots BDT on the pays row |
| CN apply | Document settlement, no cash | Pay CN with `rpc_pay_*` | CN is obligation swap, not cash out |
| Multi-bill correct | Void pays + `rpc_pay_bills` | In-place `rpc_update_pays` for multi-bill | Update stays single-bill to avoid partial sibling rewrites |
| AP to-pot | Option C: derive from payee + currency | Option A: tenant default pot | Mis-custody on AP; process-only UI guard is insufficient |
| Party model for AR “tenant” | Self-profile per tenant | Polymorphic `(entity_type, entity_id)` | Smaller cutover; columns stay profile ids |
| Change feed | `money_outbox` + `xid8` visibility poll | Raw `bill_events.id` watermark only | Ids assign at insert; visibility at commit — watermark loses events |
| Idempotency on void | Permanent key; replay returns voided result | Void frees key | Late client retry would duplicate payment |

## Surface inventory

**Kernel schema:** `money_kernel` — tables, triggers, internal helpers. **Public:** thin `public.rpc_*`, read views, no direct table DML.

**Tables (14 + outbox):** `currencies`, `profiles`, `cashbook_accounts`, `cashbook_points`, `cashbook_point_pots`, `pays`, `bill_kind_registry`, `invoice_no_counters`, `bills`, `bill_lines`, `bill_settlements`, `bill_events`, `books_exchange_rates`, `money_outbox` — see [01-schema.md](01-schema.md).

**Write RPCs (17 = 16 public + 1 internal):**

| RPC | Job |
| :--- | :--- |
| `rpc_deposit` / `rpc_withdraw` | External ↔ profile pot |
| `rpc_transfer_same_profile` / `rpc_transfer_p2p` | Move between pots |
| `rpc_pay_bills` | One pays → N bills |
| `rpc_pay_bill` | One bill (wrapper → `rpc_pay_bills`) |
| `rpc_apply_document_settlement` | credit_note → target bill due |
| `rpc_void_document_settlement` | Remove one document apply |
| `rpc_void_pays` / `rpc_update_pays` | Reverse or correct cash |
| `rpc_create_bill` / `rpc_issue_bill` / `rpc_void_bill` / `rpc_write_off_bill` | Bill lifecycle |
| `rpc_provision_cashbook_currency` / `rpc_provision_tenant_cashbook` | Pots + self-profile |
| `rpc_allocate_invoice_no` | Internal (from `rpc_issue_bill` only) |

**Read RPCs (6):** `rpc_get_bill`, `rpc_query_bills`, `rpc_get_pot_balance`, `rpc_get_pot_balances`, `rpc_profile_transactions`, `rpc_list_bill_kinds`.

**Views (4):** `v_bills_unified`, `v_bill_lines_unified`, `v_bill_events`, `v_pot_balances`.

**Change feed:** `money_outbox` rows inserted in the same transaction as `bill_events` (or equivalent lifecycle writes). Consumers poll:

```sql
-- at-least-once; commit order via xid
SELECT * FROM money_kernel.money_outbox
WHERE tenant_id = $tenant
  AND xid < pg_snapshot_xmin(pg_current_snapshot())
  AND xid > $last_xid
ORDER BY xid, id
LIMIT $n;
```

Payload shape, consumer idempotency, and lag SLA: see [01-schema.md](01-schema.md) outbox DDL and [02-actions.md](02-actions.md) `v_bill_events` (no gapless `event_id` polling).

## Invariants (ids for cross-refs)

| Id | Rule | Enforced in |
| :--- | :--- | :--- |
| I1 | Pays touches ≥1 pot | `pays` CHECK |
| I2 | NULL pot leg = external | semantics |
| I3 | `pays.amount > 0` | CHECK |
| I4 | `pot.amount ≥ 0` | CHECK + `trg_pot_guard` |
| I5 | Pot amount only via `fn_pays_apply` | `trg_pot_guard` + `money.pot_writer` |
| I6 | Posted pays immutable except void | `trg_pays_guard_immutable` |
| I7 | Σ `allocated_books_amount` (pay settlements) ≤ `pays.books_amount` (±0.01 books only) | D1 deferred |
| I7b | Payment same currency on pots + bill | `rpc_pay_bill(s)` + T1 |
| I8 | `bills.kind` in registry | FK |
| I9 | `total = sum(lines)` at issue (exact) | T8 + `rpc_issue_bill` |
| I10–I11 | Non-negative amounts; `paid+due+written_off=total` unless `voided` (exact) | CHECK |
| I12 | Structural cols frozen after issue | T4 |
| I13 | Totals frozen once any settlement | T4 |
| I14 | `paid`/`due`/`status` from settle trigger + RPCs | T7 |
| I15–I16 | Events append-only; one event per bill action | T5, T6 |
| I17 | Document apply: source remaining ≥ alloc; target due ≥ alloc | `rpc_apply_document_settlement` |
| I18 | `from_profile_id` + `to_profile_id` required to issue | `rpc_issue_bill` |
| I19 | Sum of pay allocations ≤ `pays.amount` | `rpc_pay_bills` (+ D1 on books) |
| I20 | Void pays only if to-pot still holds the credited amount | `rpc_void_pays` |
| I21 | Totals freeze if bill is settle target **or** document source | T4 |
| I22 | Transfer to-pot credit uses server `exchange_rate` on post and void | T1 |
| I23 | `rpc_void_bill` does not void a multi-bill pays | `rpc_void_bill` |
| I24 | Idempotency key **unique per tenant** for pays/bills/settlements (permanent) | partial uniques on `pays`, `bills`, `bill_settlements` |
| I25 | CN parties = swap of parent; parent live status | `rpc_create_bill` |
| I26 | Voided bills immutable; draft status only → issued/voided | T4 |
| I27 | Void bill clears `written_off_amount`; T6 emits `voided` first | T6 + `rpc_void_bill` |
| I28 | Pay path never locks `cashbook_accounts` header rows | `rpc_pay_bills` |
| I29 | Document apply: `target.from = source.to` and `target.to = source.from` | RPC + settlement guard trigger |
| I30 | `from_pot_id` IS DISTINCT FROM `to_pot_id` | `pays` CHECK |
| I31 | Every `pay` settlement’s pays row is `posted`, `kind=payment`, same `tenant_id` as bill | settlement guard trigger |
| I32 | Multi-bill pays: one `to_profile_id` (payee) and one payer (`from_profile_id` on all bills) | `rpc_pay_bills` |
| I33 | Σ non-voided CN `total_amount` ≤ parent `total_amount` | `rpc_create_bill` |
| I34 | Bill lines immutable after issue; Σ lines = `total` at issue | T8 |
| I35 | `exchange_rate` and `books_rate` server-resolved; client override only with `fx_override` grant | write RPCs |
| I36 | Pot rows inserted only with `amount = 0` | T3 BEFORE INSERT |

## Assumptions (labeled)

| Id | Assumption | Evidence in pack |
| :--- | :--- | :--- |
| A1 | Books currency is BDT; `books_amount = amount × books_rate` | `01-schema` pays; rates from `books_exchange_rates` |
| A2 | **Exact** bill amount identity (`paid+due+written_off=total`). **0.01 tolerance only** on books allocation (D1). | `01-schema` CHECKs / D1 |
| A3 | Invoice numbers may have gaps under concurrency | `rpc_allocate_invoice_no` at issue |
| A4 | PG15+ required for `security_invoker = true` on views | `02-actions` / `05-security.md` |
| A5 | `[ASSUMPTION]` Live SQL lags v2 until cutover | README / this overview |
| A6 | `[ASSUMPTION]` Table “High / Very high” row notes are relative concern only — not measured rates | `01-schema` §4 summary |
| A7 | Business dates use tenant timezone: `(now() AT TIME ZONE tenant_tz)::date` | write RPCs |

## Non-functional requirements

| Area | Contract |
| :--- | :--- |
| Security | Assert + privilege matrix + full RLS — [05-security.md](05-security.md). No `anon` EXECUTE on kernel RPCs. |
| Consistency | Single DB transaction per write RPC; pot amount only via T1 with `money.pot_writer` |
| Observability | `bill_events` append-only + `money_outbox` for consumers |
| Lock timeouts | `SET lock_timeout = '3s'` at start of each write RPC |
| Hot rows | `fillfactor` ~70 on `cashbook_point_pots` and `bills`; aggressive autovacuum on pots; prefer one collection pot per cashier/branch per tenant |
| Reconciliation | Scheduled job: ∀ pots, `amount` = Σ signed deltas from posted pays (`from_balance_after` / `to_balance_after` snapshots); alert on drift |
| Latency / throughput | Target p99 `rpc_pay_bills` &lt; 500ms with ≤200 allocations under 50 concurrent pays per tenant (measure in TC-PERF) |
| Data retention | `bill_events` + voided pays: 7 years online; archive to cold storage after; outbox rows deleted after consumer ack + 30d |
| Cost | Money path index bloat budget: no unbounded GIN on pays refs; `request_hash` not full allocation JSON in `refs` |

## Risk & operability (kernel-local)

| Risk | Mitigation in pack | Remaining |
| :--- | :--- | :--- |
| Deadlock under multi-bill pay | Lock order bills → pots → pays; I28 | — |
| Void after money moved out | I20 / `rpc_void_pays` refuses | Ops must transfer/top-up first |
| Multi-bill void blast radius | I23 refuse `rpc_void_bill`; void pays first | — |
| Idempotent replay with different params | `request_hash` → `idempotency_conflict` | — |
| Paid bill void after cash moved | No automatic refund RPC yet | **Backlog:** refund/reversal RPC |
| Cutover / dual-run with live SQL | **Out of folder** | `[TODO-ARCH: migration path owner — owner, date]` |
| On-call recon | Kernel REFERENCE → `08-AUDIT-…`; pot snapshot columns | — |

## Backlog (kernel-adjacent)

| Item | Notes |
| :--- | :--- |
| Refund / payment reversal RPC | Voiding old paid bills fails once cash left the creditor pot |
| Period close | `books_period_locks` — block post/void into closed period |
| Write-off reversal | RPC to undo `written_off` within policy |
| Maker-checker | Second approver for void, write-off, large deposit |

## Open questions

| # | Question | Owner | Date |
| :---: | :--- | :--- | :--- |
| OQ1 | ~~Real assert body~~ | Resolved in [05-security.md](05-security.md) | — |
| OQ2 | ~~Full RLS~~ | Resolved in [05-security.md](05-security.md) | — |
| OQ3 | ~~AP to-pot~~ | **Option C** (locked above) | — |
| OQ4 | ~~Change feed~~ | **`money_outbox` + `xid8` poll** | — |
| OQ5 | Who maintains `cashbook_accounts.available/pending/locked_balance` if anyone? | `[TODO-ARCH: owner]` | `[TODO-ARCH: date]` |
| OQ6 | Cutover gap list + rollback (external doc link) | `[TODO-ARCH: owner]` | `[TODO-ARCH: date]` |

Tests: [03-tests.md](03-tests.md). Security: [05-security.md](05-security.md). Module RPCs: [04-module-rpcs.md](04-module-rpcs.md).
