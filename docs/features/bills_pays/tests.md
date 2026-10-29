# Bills & pays — tests and golden scenarios

**Job:** Regression baselines and what to automate. Narrative: [money-story](money-story.md). Rules: [kernel REFERENCE](../../kernel/REFERENCE.md). Product: [spec](spec.md).

**As-built:** pgTAP smoke + **kernel golden** fixtures in [`supabase/tests/`](../../../supabase/tests/) (`000_money_kernel_bootstrap.sql`, `001_cross_module_golden_helpers.sql`, `golden_bills_pays_*.sql`, `tier1_bills_pays_invariants.sql`). CI: `pnpm run backend:test`. Scenarios **A/B** automated in `golden_bills_pays_a_dropship_remittance.sql` and `golden_bills_pays_b_shipment_ap_fx.sql`.

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
| `post_money_out` | **620** out; `source_type = commission`, `source_id = O`; no alloc to B1; returns `pays` row ([BP24](00-gaps.md)) |

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
| **BP18** settlements vs allocations | [08 §1b](../../kernel/08-AUDIT-RECONCILIATION-AND-RUNBOOK.md) returns **zero rows** on prod after cutover; pgTAP [`bills_pays_bp18_settlements.sql`](../../../supabase/tests/bills_pays_bp18_settlements.sql) (no alloc→settle trigger; `_kernel_record_pay_bill_settlement`) |
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
| Compose source plug | Save draft from compose desk | `source_type = compose`, `source_id` = bill id (server stamp) |

### G — Note desk (BP8)

| Case | Steps | Expect |
| :--- | :--- | :--- |
| AR CN + cash refund | On issued AR bill, credit note with excess over due; check refund + till; issue | `create_bill_adjustment` with `p_refund_amount`; pay `source = customer_cash`; CN `due` reduced by refund |
| Shipment guided CN | Lock costs → material AP issued → Shipment settings **Commercial credit note** | Bill detail opens with composer; optional `suggestedAmount` query hint only |
| Note print | Preview issued CN/DN | Lines from `bill_lines`; reason on sheet |
| Apply CN to second bill | Issued AR bill A with open CN; **Apply credit to another bill** → bill B | `bill_settlements` `allocator_kind=credit_note`; CN `parent_bill_id` unchanged; B due down; CN open down (T4-2) |
| Custody to bill | Bill detail **Apply custody** when profile has custody balance | `apply_settlement_to_bill` `allocator_kind=custody_entry`; ledger custody debit |
| Collect pre-apply | Pay in → tick open CN / leftover → Post receipt | Settlements before `post_money_in`; optional section empty OK |

### H — Apply leftover / open credit (BP11)

| Case | Steps | Expect |
| :--- | :--- | :--- |
| AP payout leftover | Pay out vendor with unallocated remainder → Pay detail **Apply leftover** | `apply_settlement_to_bill` `allocator_kind=pay`; target AP bill due reduced |
| AR collect leftover | Same on customer cash/bank pay detail | Same RPC path as AP |
| pgTAP smoke | `supabase test db` → `bills_pays_bp11_apply_settlement.sql` | Functions exist; custody branch; recompute includes CN cross-apply |

### M — Cashbook points, FX pots, account class (BP15 + BP16 + BP21)

| Case | Steps | Expect |
| :--- | :--- | :--- |
| Collect point | Pay in → **Receive into** → Post | `pays.cashbook_point_id` / pot set; tenant ledger at point |
| FX pot | Non-BDT pot + books rate | Ledger line uses pot currency + frozen rate |
| Account class | Party detail | `account_class` distinguishes tenant asset vs profile custody |
| pgTAP | `bills_pays_bp15_collect_point.sql`, `bp16_fx_pots.sql`, `bp21_account_class.sql`, `bills_pays_bp15_transfer.sql` | Symbols + prosrc smoke; point transfer RPC |
| Point transfer | Cashbook **Move cash** between two active points | Same currency; pots net zero; no pay row |
| Golden **A** | `golden_bills_pays_a_dropship_remittance.sql` | Dropship remittance 2120 → bill 1500 + custody ~620 |
| Golden **B** | `golden_bills_pays_b_shipment_ap_fx.sql` | Shipment AP USD/GBP sync + freight pay @ 155.50 + FX refresh |
| Golden **D** | `golden_bills_pays_d_wholesale_take.sql` | Issue AR + collect → due 0 |
| Golden **C** | `golden_bills_pays_c_custody_offset.sql` | Overpay + custody apply + cash on second bill |

### L — Reverse pay + cheque bounce (BP12 + WA13)

| Case | Steps | Expect |
| :--- | :--- | :--- |
| Void AP payout | Pay detail **Void payout** on issued AP pay | `reverse_pay`; bill stays **issued**; due restored (T4-4) |
| Correct payment (UI) | Bill **Payment history → Correct** or pay detail **Correct amount or rate** → void + re-post | Same as void + new pay; T4-4 settlement axis. **Network:** open Correct uses bundle history only (no pay REST); void → one `get_bill_detail_bundle`; re-post AP skips extra `bills` shipment lookup when bill already loaded |
| Void remittance | Courier remittance pay void | Same kernel; no bill void |
| Cheque bounce (single) | CHEQUE instrument **Mark bounced** on one-instrument pay | Whole pay reversed via `reverse_pay` |
| Cheque bounce (split) | Multi-instrument pay; bounce one CHEQUE | Instrument `bounced_at`; partial ledger + LIFO settlement unwind; pay not voided |
| pgTAP | `bills_pays_bp12_reverse_pay.sql`, `bills_pays_wa13_cheque_bounce.sql`, `golden_bills_pays_t4_4_reverse_pay.sql`, `golden_bills_pays_t4_2_cn_cross_apply.sql` | Kernel + bounce + golden T4-2/T4-4 |

### I — Kernel upsert adapters (BP9)

| Case | Steps | Expect |
| :--- | :--- | :--- |
| Compose upsert | Create bill from compose desk | `upsert_draft_bill` with `adapter: compose`; default path uses `_kernel_upsert_compose_draft` |
| Wholesale stock issue | Issue wholesale bill with stock lines | `commit_wholesale_bill_stock` then `_kernel_issue_wholesale_stock` via `issue_wholesale_bill` ([BP17](00-gaps.md)) |
| Dropship courier AP | Ship dropship order | `_kernel_upsert_dropship_courier_ap`; `source_type = dropship_courier` |
| pgTAP smoke | `bills_pays_bp9_upsert_adapters.sql` | Kernel symbols exist; `upsert_draft_bill` prosrc has no `create_sales_invoice_from_payload` |

---

### J — Kernel reads (BP10 + BP23)

| Case | Steps | Expect |
| :--- | :--- | :--- |
| Source bills | `list_bills_for_source(parent, 'shipment_cost', shipment_id)` | AP standard bills + `net_balances`; shipment drawer uses same via finance bundle |
| Profile open | `list_open_on_profile(parent, profile_id)` | `due_bills`, `open_credit_notes`, `pay_leftover` arrays |
| Desk view | `list_bills_desk_page` row | `open_books` matches `v_kernel_bill_summaries` for issued standards |
| pgTAP | `bills_pays_bp10_bp23_reads.sql` | View + list RPCs exist; desk + shipment wired |

---

### K — Returns credit notes (BP5)

| Case | Steps | Expect |
| :--- | :--- | :--- |
| Wholesale return | `process_wholesale_invoice_return` on paid/partial bill | Parent `total_amount` unchanged; child `credit_note` issued; `get_bill_net_balances` open drops |
| Dropship finalize | `finalize_dropship_return` with items | No `recompute_global_invoice_totals`; CN when return credit > 0 |
| pgTAP | `bills_pays_bp5_return_cn.sql` | prosrc checks on return RPCs |

---

### N — Commission payout (BP24)

| Case | Steps | Expect |
| :--- | :--- | :--- |
| Merchant cash out | Collect desk **Cash out** or dropship profit pay | `post_money_out` with `source_type=commission`; `pays.source=commission`; ledger + FIFO settlement |
| pgTAP | `bills_pays_bp24_commission_payout.sql` | Kernel writer wired; **`dispense_middleman_payout_from_tenant` absent** |

### O — Wholesale stock before issue (BP17)

| Case | Steps | Expect |
| :--- | :--- | :--- |
| Stock commit | `commit_sales_bill_stock` on draft bill (wholesale take / retail) | Posted movement; `global_stocks` deducted once |
| Issue | `issue_wholesale_bill` / `post_sales_invoice` take path | Status issued; commit idempotent |
| Line meta | Compose / adjustment stock lines | **`line_meta.stock_ref.global_stock_id` only** (no physical column) |
| pgTAP | `bills_pays_bp17_wholesale_stock_issue.sql` | `commit_sales_bill_stock` + issue wrappers |

### P — Ledger pot audit (BP16‑r)

| RPC / path | Tenant cash leg | Pot metadata |
| :--- | :--- | :--- |
| `_kernel_reverse_payment` · `commission` | Credit tenant (void payout) | `cashbook_point_pot_id` from pay |
| `_kernel_reverse_payment` · `ap_payout` | Credit tenant | `cashbook_point_pot_id` from pay |
| `create_bill_adjustment` · credit note cash refund | Debit tenant | `_kernel_ensure_cashbook_point_pot` + FX fields on pay |
| `post_money_in` / `post_ap_payout_with_allocations` | Collect / AP payout | Already wired in `12_cashbook_wiring` / BP25 |
| Returns wallet / profile-only legs | No point | Pot not required (documented skip) |

| pgTAP | `bills_pays_bp16_ledger_pots.sql` | prosrc smoke + column drop |

---

### F — Modular pay desk (BP14)

| Case | Steps | Expect |
| :--- | :--- | :--- |
| Partial collect | Profile → Pay in, amount 1000, alloc 600 to one bill | `pay_allocations` 600; profile leftover 400 |
| Vendor AP payout | Vendor profile → Pay out with alloc to open AP bill | `post_money_out` + settlements to open AP bill (`from` = vendor, `to` = tenant); `get_bill_net_balances` open books → 0 (live: `post_ap_payout_with_allocations`) |

---

## CI (as-built)

| Job | Scope |
| :--- | :--- |
| `backend:reset` | Migrations replay (GitHub `supabase-db.yml`) |
| `pnpm run backend:test` / `supabase test db` | Full [`supabase/tests/`](../../../supabase/tests/) after reset |
| Nightly | Tier 3 optional |

---

## Money PR checklist

- [ ] [REFERENCE](../../kernel/REFERENCE.md) invariants + PR checklist
- [ ] Flow changed? Update golden scenario **A–D** above
- [ ] New RPC? Grep `supabase/schemas/` + regenerate `database.types.ts`
- [ ] Run audit queries in [08](../../kernel/08-AUDIT-RECONCILIATION-AND-RUNBOOK.md) on local seed data
