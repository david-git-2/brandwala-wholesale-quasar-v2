# Bills & pays — tests and golden scenarios

**Job:** Regression baselines and what to automate. Narrative: [money-story](money-story.md). Rules: [kernel REFERENCE](../../kernel/REFERENCE.md). Product: [spec](spec.md).

**As-built:** Most coverage is manual + audit SQL in [08 runbook](../../kernel/08-AUDIT-RECONCILIATION-AND-RUNBOOK.md). pgTAP / CI golden fixtures are **not_built** — implement against this doc.

**Target fixtures** ([kernel-schema](kernel-schema.md)): assert `bills.status` (`issued` \| `draft` \| `voided`), `from_profile_id` / `to_profile_id`, and `(source_type, source_id, source_key)` — not legacy `invoice_status`, `invoice_type`, `shop_order_id`, or `shop_orders.global_invoice_id`. Pay writers: `post_money_in` / `post_money_out` ([BP24](00-gaps.md)); live RPC names in parentheses below where code still lags.

Tables: `bills`, `bill_lines`, `pays`, `pay_allocations`, `cashbook_entries`, `cashbook_accounts`, `profiles`.

---

## Golden scenarios (Tier 2)

### A — Dropship order, courier net remittance

**Actors:** Tenant T, dropshipper profile P, courier profile C. Order O at ship. **COD ≠ sales.**

#### At ship (dispatch)

| Table | Rows (effect) |
| :--- | :--- |
| `bills` | **B1** AR: `from_profile_id` = tenant T, `to_profile_id` = merchant P, `status = issued`, `total_amount = 1500`, `source_type = shop_order`, `source_id = O` |
| `bills` | **B2** AP: `from_profile_id` = courier C, `to_profile_id` = tenant T, `status = issued`, `total_amount = 80`, `source_type = shop_order`, `source_id = O`, `source_key` = courier AP slice (adapter-defined) |
| `bill_lines` | B1: lines totaling 1500 (not COD 2200) |

#### At delivery (courier custody)

| Table | Rows |
| :--- | :--- |
| `cashbook_entries` | Courier entity **credit 2200** (custody — not tenant sales) |

#### Remittance (bank net 2120)

| Step | Table | Effect |
| :--- | :--- | :--- |
| Pay in | `pays` | **Pay R**: `amount = 2120`, `source = courier_remittance` |
| Alloc | `pay_allocations` | 1500 → B1 |
| Leftover | custody | Merchant P **+620** |
| Cash | `cashbook_entries` | Tenant operating **+2120** |

#### Merchant payout later

| Step | Effect |
| :--- | :--- |
| `post_money_out` | **620** out; `source_type = commission`, `source_id = O`; no alloc to B1 (live: `dispense_middleman_payout_from_tenant` until [BP24](00-gaps.md)) |

**Assert:** Sales = 1500; cash in = 2120; merchant custody 0 after payout.

---

### B — Multi-currency shipment AP and landed cost

Shipment **S-42**. Target: one bill per `(bucket, currency)`; live may differ until [WA15](00-gaps.md).

| `bills` | `source_key` | Currency |
| :--- | :--- | :--- |
| AP-1 | `material:USD` | USD |
| AP-2 | `freight:GBP` | GBP |

Pay freight: `exchange_rate = 155.50` frozen on `cashbook_entries`. `refresh_global_shipment_fx_from_ap_payments()` uses **paid** rates for landed cost.

---

### C — Wholesale take with overpayment and custody offset

| Step | State |
| :--- | :--- |
| B1 issued | `total_amount = 1500` |
| Collect 2000 | Alloc 1500 → B1; custody **+500** |
| B2 issued | 800 |
| Settle B2 | Apply 500 custody + 300 cash → B2 paid |

**Assert:** No extra bill for 500; `get_bill_net_balances(B2).due = 0`.

---

### D — Wholesale take (simple)

Buyer ABC, sell 1500, pay 1500 cash — see [money-story § Wholesale take](money-story.md).

| Layer | Store |
| :--- | :--- |
| BILL | Take issued, paid |
| PAY + ALLOC | 1500 → bill |
| CASHBOOK | Tenant +1500 |

**Harness:** Seed fixtures → run adapter + RPC chain → compare ids + `get_bill_net_balances` JSON. Frozen fixtures target: `supabase/tests/fixtures/` (**to create**).

---

## Invariant tests (Tier 1)

Run in transaction + `ROLLBACK` or isolated DB (`backend:reset` fixture).

| Test | Assert |
| :--- | :--- |
| Issue then `UPDATE total_amount` | Blocked by RPC policy or trigger (target); today rely on code review + audit #4 in [08](../../kernel/08-AUDIT-RECONCILIATION-AND-RUNBOOK.md) |
| Alloc > pay amount | RPC raises; no `pay_allocations` row |
| Alloc > `get_bill_net_balances.due` | RPC raises |
| Void issued bill with pays | `cannot void a paid` |
| Negative pot / ledger | CHECK violation on insert |
| Credit note without parent | RPC raises |
| `cross_tenant_denied` (each money RPC) | Tenant A session cannot act on tenant B bill/pay |
| **BP18** settlements vs allocations | [08 §1b](../../kernel/08-AUDIT-RECONCILIATION-AND-RUNBOOK.md) returns **zero rows**; pgTAP [`bills_pays_bp18_settlements.sql`](../../../supabase/tests/bills_pays_bp18_settlements.sql) |
| **BP25** duplicate `idempotency_key` | Second `post_money_in` same key → same `pays.id`; one cashbook movement |
| **Issued** AP sync | `sync_shipment_ap_bills` does not change `total_amount` on `status = issued` standard bills |

Implement as SQL tests with `raises_ok` (pgTAP) or Supabase test harness when added. **Spine cutover:** Tier 1 must be green on PRs touching `bills_pays/` schemas ([00-gaps](00-gaps.md) S1–S2).

---

## Design scenarios (Tier 4 — not built)

Target behavior ([kernel-schema](kernel-schema.md), [BP17–BP24](00-gaps.md)). **T4-1** moves to Tier 2 when [BP19](00-gaps.md) lands.

| # | Scenario | Assert |
| :--- | :--- | :--- |
| T4-1 | AP bill issued **USD 100** @ 120 BDT; pay **USD 100** from GBP pot @ different books rate | `open_txn = 0`; `bill_settlements.fx_realized_books_delta` ≠ 0 when settle rate ≠ issue `books_exchange_rate` |
| T4-2 | Issued CN with open remainder applied to **second** bill | New `bill_settlements` row (`allocator_kind=credit_note`); **no** `parent_bill_id` update on CN |
| T4-3 | Standard bill voided on `source_*` plug; re-sync adapter | New standard bill allowed (partial unique index excludes voided) |
| T4-4 | Bill **settled**; `reverse_pay` on last alloc | `lifecycle_status` still `issued`; `settlement_status` → `partial` or `unpaid` |

---

## Concurrency (Tier 3)

| Scenario | Expect |
| :--- | :--- |
| Two parallel collects on same bill due | One succeeds; one fails over-allocation OR serializes via bill `FOR UPDATE` |
| Two parallel issues on same stock line | One insufficient stock after lock |
| Double remittance POST (same order) | Second no-op — [BP25](00-gaps.md) (also Tier 1 when column exists) |
| Shipment sync vs AP payout | Payout locks bills + shipment advisory; sync uses same advisory — one session waits |
| Direct UPDATE on `cashbook_entries` as app role | Rejected (append-only); fixes are new ledger lines |

Use `pg_sleep` + two sessions or stress script against local Supabase. CI nightly when stable.

---

### E — Modular compose (BP13)

| Case | Steps | Expect |
| :--- | :--- | :--- |
| Header-only AR | Compose: they owe, description line only, issue | `bill_lines.line_kind = description`; no stock movement; `status = issued`; `from_profile_id` = tenant, `to_profile_id` = customer |
| Manual AP | Compose: we owe, vendor From, description line, issue | `status = issued`; `from_profile_id` = vendor, `to_profile_id` = tenant; `source_type = compose`; pay out via Payments profile dialog |

### F — Modular pay desk (BP14)

| Case | Steps | Expect |
| :--- | :--- | :--- |
| Partial collect | Profile → Pay in, amount 1000, alloc 600 to one bill | `pay_allocations` 600; profile leftover 400 |
| Vendor AP payout | Vendor profile → Pay out with alloc to open AP bill | `post_money_out` + settlements to open AP bill (`from` = vendor, `to` = tenant); `get_bill_net_balances` open books → 0 (live: `post_ap_payout_with_allocations`) |

---

## CI (target)

| Job | Scope |
| :--- | :--- |
| `backend:reset` | Migrations replay (existing) |
| `supabase test db` | Tier 1 + 2 on PR touching `bills_pays/` schemas or `supabase/tests/`; **BP18/BP25** tests required before spine cutover PR |
| Nightly | Tier 3 optional |

---

## Money PR checklist

- [ ] [REFERENCE](../../kernel/REFERENCE.md) invariants + PR checklist
- [ ] Flow changed? Update golden scenario **A–D** above
- [ ] New RPC? Grep `supabase/schemas/` + regenerate `database.types.ts`
- [ ] Run audit queries in [08](../../kernel/08-AUDIT-RECONCILIATION-AND-RUNBOOK.md) on local seed data
