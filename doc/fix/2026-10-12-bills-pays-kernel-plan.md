# Bills/pays kernel — plug plan

Not as-built. Product truth: [bills_pays spec](../../docs/features/bills_pays/spec.md), [gaps](../../docs/features/bills_pays/00-gaps.md), [money-story](../../docs/features/bills_pays/money-story.md). Pay dialog / AP issue: [bill-pay-dialog-and-credits](2026-10-12-bill-pay-dialog-and-credits.md).

**Job:** one money kernel other features plug into. They create paper and **read** pays/notes. They do not own `pays`.

**Do not:** second invoice table, `bill_notes` table, tax engine, GL, Koba/thrift money, silent edit of issued totals. Do not make stock compose the only bill UI. Do not add a second pay product per account type.

---

## Locked

| Object | Table | Notes |
| :--- | :--- | :--- |
| Party | `profiles` | Profile-only ([BP3](../../docs/features/bills_pays/00-gaps.md) closed); not `customer_groups` |
| Document | `bills` | `document_kind`: `standard` / `credit_note` / `debit_note`; notes use `parent_bill_id` |
| Pay | `pays` + instruments + `pay_allocations` | FX on the pay |
| Leftover | `cashbook_*` | On the profile |
| Comment | `bills.note` | Not a credit note |

Unpaid issued: still a **note**, not an amend of the original total.

---

## Out of this plan (later)

Attachments on a note, reason-code enum, aging/statement reports, cheque lifecycle beyond bounce, full GL.

---

## Phase 1 — Modular bill compose (BP13)

**Goal:** One compose screen for **any** bill. Stock is optional.

**As-built:** `BillComposePage` is trade/walk-in + stock search + FIFO issue.

**Files:**
- `web/src/modules/bills_pays/pages/BillComposePage.vue` — shell: party, direction (they owe / we owe), date, totals, issue
- Slots/components: stock line editor (existing search), **header/description lines** (no `global_stock_id`), AP snapshot optional
- `upsert_draft_bill` (phase 4) when kernel upsert exists; until then extend `create_sales_invoice_from_payload` so lines may be empty or description-only
- Print: skip SKU grid when there are no stock lines

**Rules:**
- Stock line → FIFO / `post_sales_invoice` as today
- No stock → no stock movement; still issue paper and collect/pay
- We-owe (AP-like) → no sales; pay out
- They-owe → collect
- Take/condition/walk-in remain options on **stock AR**, not the only bill kinds

---

## Phase 2 — Modular pay desk (BP14)

**Goal:** One pay UI: **receive** or **pay out**, from an **account**.

**Accounts (existing tables, not new products):**
- Bank / cash / cheque **instruments** (`pay_instruments`)
- Tenant **cashbook**
- Profile **cashbook** (leftover / **custody** — money held for that party)

**Files:**
- Payments desk (`CollectPayPage` / `PayoutPayPage` / bill `RecordBillPaymentDialog`) fold toward one dialog: direction, account, amount, FX, alloc to bills (optional)
- Writers stay `post_customer_receipt_with_allocations` / `post_ap_payout_with_allocations` + leftover apply; `source` distinguishes remittance vs customer vs AP vs custody draw

**Rules:**
- Alloc optional → unallocated = leftover on the chosen profile/tenant account
- Custody draw = debit that profile cashbook (already used for apply leftover)
- Do not build a new “custody” table

---

## Phase 3 — Note desk (BP8, WA15)

**Goal:** Staff can issue credit/debit on a bill and settle an open credit.

**Files:**
- `web/src/modules/bills_pays/pages/BillDetailPage.vue`
- New `CreateBillAdjustmentDialog.vue` + mutation wrapping `create_bill_adjustment`
- `BillPreviewPage.vue` (CN/DN title + parent invoice no)
- `RecordBillPaymentDialog.vue` — pay in when `credit_open` > 0 (AP)

**Change:**
- List `list_bill_adjustments`; totals from `get_bill_net_balances`
- Actions: Credit note / Debit note when parent `issued`, not void; grant `global_invoice` edit
- Reason required; amount > 0; kind sets sign
- After pay: invalidate bill + history + adjustments
- Shipment: no bucket edit after issue; optional later hook to restamp cost on credit (phase 6)

---

## Phase 4 — Apply leftover / open credit (BP11)

**Goal:** Same apply path for customer leftover, vendor leftover, and credit-note remainder onto the next bill of that profile.

**Files:**
- `supabase/schemas/bills_pays/03_rpcs.sql` — extend leftover apply (today AR FIFO on collect) so AP + credit notes use it
- Pay-in UI (`CollectPayPage` / bill dialog): pick open leftover / open credit

**Change:**
- One RPC: profile + target `bill_id` + amount ≤ open leftover or `credit_open`
- Alloc to target bill (or credit note if paying a refund the other way)
- Do not create a second cashbook product

---

## Phase 5 — Generic source plug (BP9)

**Goal:** Features pass source keys; no new FK per feature.

**Files:**
- `supabase/schemas/bills_pays/01_types.sql` / `02_tables.sql` — `source_type` text, `source_id` text, `source_key` text (nullable)
- Unique: standard AP still unique on shipment+bucket until backfill maps `ap_shipment_id` → source
- `create_bill_adjustment` copies parent source
- Wrap `sync_shipment_ap_bills` as the shipment adapter (still the only shipment writer)

**Change:**
- `source_type` examples: `shipment_cost`, `wholesale_sale`, `dropship_merchant`, `delivery_close`
- `source_key` = cost bucket when AP
- Keep `ap_shipment_id` until adapters stop reading it (do not drop in this phase)

---

## Phase 6 — One upsert family (BP9)

**Goal:** Adapters call named kernel RPCs, not private invoice creators.

**RPCs (names):**
- `upsert_draft_bill` — party, direction (AR/AP via existing `invoice_type`), total or lines, source, currency snapshot
- `issue_bill` / `void_bill` — existing issue/void wrapped; void still blocked if paid or live children
- `create_bill_adjustment` — already shipped
- Pay writers stay `post_customer_receipt_with_allocations` / `post_ap_payout_with_allocations`

**Change:**
- Wholesale compose and shipment sync become callers. No behavior change for take/condition/dropship paper rules.

---

## Phase 7 — Kernel reads (BP10)

**Goal:** Features never sum `pay_allocations` themselves.

**RPCs:**
- `get_bill_net_balances` — exists
- `list_bills_for_source(p_source_type, p_source_id)` — standard + notes
- `list_pays_for_source` — includes FX fields (shipment restamp uses this instead of a private join)
- `list_open_on_profile` — due bills + leftover + credit_open

**Files:** shipment FX refresh (`refresh_global_shipment_fx_from_ap_payments`) switches to `list_pays_for_source` when ready.

---

## Phase 8 — Shipment adapter complete (WA15 rest)

**Goal:** Shipment is a client.

**Files:** `procurement/` sync already; restamp on **credit** as well as payout; freeze issued bucket (fix doc).

**Change:**
- After issue: sync must not change that standard bill
- Shortage/VAT: `create_bill_adjustment` then restamp remaining qty / costing
- Pay in on credit (phase 1) lands here for VAT refund

---

## Phase 9 — Reverse pay (BP12, WA13)

**Goal:** Wrong pay / cheque bounce reverses the pay. Bill totals recompute. No silent bill edit.

**Files:**
- Extend `void_customer_receipt` pattern to AP payout
- Bounce: mark instrument bounced → reverse pay

**Change:**
- Allocations unwind; leftover reverse if that pay created it
- Issued paper stays; staff use a note if the commercial amount was wrong

---

## Phase 10 — Returns use notes (BP5, US-2)

**Goal:** Goods stay in after-sales. Money is a credit note.

**Files:** `process_wholesale_invoice_return` / after-sales finalize — call `create_bill_adjustment`; excess → cashbook (existing leftover). Do not lower `bills.total_amount` on the original.

**Change:**
- `return_quantity` still on lines for stock
- Commercial paper = CN child

---

## Phase 11 — Cash pots + frozen FX (BP16)

**Goal:** Each place can hold more than one currency. Each cash movement stores **amount, currency, rate pair, BDT**.

**Do not:** new `locations` / `transactions` tables. Point = place. Pot = place × currency. Rate list = default for the form.

**Files:**
- `supabase/schemas/bills_pays/02_tables.sql` — `cashbook_point_pots`, `books_exchange_rates`; `cashbook_entries.cashbook_point_pot_id`, `quote_currency_code`, `rate_date`; `pays.quote_currency_code`
- Later: `record_ledger_transaction` upserts pot; `post_vendor_credit_refund` (and collect/AP) pass cash currency + rate, not BDT @ 1
- Later: `CashbookPartyPage.vue` — pots on the point chip; ledger shows cash + books

**Rules:**
- Pot has **no** single rate
- `exchange_rate` = quote (BDT) per 1 cash currency
- Existing BDT ledger rows stay valid (`currency_code=BDT`, rate 1)

---

## Order (2026-10-27 — architecture spine first)

Resolutions: [2026-10-27-bills-pays-architecture-resolutions.md](2026-10-27-bills-pays-architecture-resolutions.md).

**Money spine (before new pay/bill writers):** BP20 → BP18 (+ audit 08 §1b) → BP25 → BP22 → BP19. Tier 1 tests in [tests.md](../../docs/features/bills_pays/tests.md).

**Then product track:** BP8 notes → BP11 apply (needs BP18) → BP9 upsert → BP10 + BP23 reads → WA15 shipment (advisory lock) → BP12/WA13 reverse → BP5 returns → BP15/BP16 points (after BP22).

Compose (phase 1) and pay desk (phase 2) **UI** may continue on live RPCs; **no new SECURITY DEFINER money writers** until spine cutover.

Stock compose stays a **slot** on the bill shell. **BP17** FIFO outside issue, **BP21** account class, **BP24** retire dispense — see [00-gaps](../../docs/features/bills_pays/00-gaps.md).

---

## Phase 0 — Money spine (was “Phase 12+”)

See [kernel-schema §0b](../../docs/features/bills_pays/kernel-schema.md) and [00-gaps spine table](../../docs/features/bills_pays/00-gaps.md).

| ID | Deliverable |
| :--- | :--- |
| BP20 | Void-excluding `source_*` unique index |
| BP18 | `bill_settlements`, dual-write, 08 §1b gate, cutover |
| BP25 | `pays.idempotency_key` |
| BP22 | Append-only ledger, pot trigger, lock order in RPCs |
| BP19 | Txn face + `fx_realized_books_delta` on settlements |
