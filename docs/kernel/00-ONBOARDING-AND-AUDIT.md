# Money kernel — onboarding primer and pack audit

**Audience:** Mid-level engineer (SQL/Postgres + web apps), new to this ledger.  
**Source pack:** README + `01`–`08` in this folder. External refs (`00-gaps.md`, `kernel-schema.md`, `money-story.md`, `spec.md`, `BP*`/`WA*`) are **not** in the nine files — treat as dangling unless you open them separately.

---

## TL;DR

- The **money kernel** is the shared ledger for **bills** (what was promised), **pays** (money moved), and **cashbook** (where cash lives and profile “store credit”).
- Other features (shipments, dropship shop, POS, delivery) must **plug in** via kernel **RPCs** and `(source_type, source_id, source_key)` — not by owning invoice tables.
- **LIVE** = what Postgres has today (`invoice_status`, `profile_id`, `invoice_id` on allocations). **TARGET** = the intended contract (`status`, `from_profile_id`/`to_profile_id`, `kernel_*` RPCs). The pack mixes both — always ask which you are reading.
- After **issue**, you never “edit the total”; you issue **credit/debit notes** (child bills).
- This is **not** full GAAP accounting: no tax model, no complete report catalog, no built idempotency/reverse-pay yet — see §5–§6.

---

## 1. One-page primer — What is this kernel?

### Problem it solves

Wholesale and dropship businesses need one place to record:

1. **Commercial paper** — “We sold X for Y” or “We owe the vendor Z” (bills).
2. **Cash movement** — money in/out, split tender, FX (pays).
3. **What is still owed** — after payments and adjustments (allocations + net balance).
4. **Where physical cash sits** — drawer, safe, bank pot (cashbook points/pots), plus **custody** (customer/merchant credit not tied to a till).

### Core entities (6 + profiles)

| Entity | Plain English | Role |
| :--- | :--- | :--- |
| **profiles** | Money party (customer, vendor, tenant, courier, …) | Who is on each side of a bill or pay |
| **bills** | Invoice / AP document header | Face amount, draft/issued/void, links to source feature |
| **bill_lines** | Line items on a bill | Stock, fees, descriptions; may reference warehouse stock |
| **pays** | One money movement event | Amount, date, counterparty profile, optional unallocated remainder |
| **pay_allocations** | Slice of a pay applied to a bill | Reduces what is due on that bill |
| **cashbook_entries** | Ledger line (credit/debit) | Profile custody or tenant books; **frozen FX** on the row |
| **cashbook_accounts** | Running balance per profile/tenant (books currency) | Custody / leftover home |
| **cashbook_point_pots** | Cash in one **place** × **currency** | Physical drawer/safe/bank pile |

### Relationship (ASCII)

```text
profiles ─────┬────────────── bills (header: total, status, source_*)
              │                    │
              │                    ├── bill_lines (optional stock → global_stock_id)
              │                    └── child bills (credit_note / debit_note → parent_bill_id)
              │
              ├── pays (amount, unallocated_amount, profile_id)
              │        ├── pay_allocations ──► bills
              │        └── pay_instruments (split tender → cashbook_point_id)
              │
              └── cashbook_entries ◄── tied to pays / adjustments
                        └── cashbook_point_pots (place × currency)
```

### Three questions the kernel answers

1. **Who owes whom?** — Derived from bill direction (AR: they owe tenant; AP: tenant owes them). **TARGET:** `from_profile_id` / `to_profile_id`. **LIVE:** often `invoice_type` + `profile_id`.
2. **How much is still due?** — `get_bill_net_balances(bill_id)` (face ± notes − pays). **LIVE cache:** `due_amount` (can drift — audit in 08).
3. **Where is the cash right now?** — Tenant: point/pot balances + ledger. Counterparty overpay: **profile custody** on `cashbook_accounts` / entries.

### What this is NOT

| In scope (kernel pack) | Out of scope (not in the 9 files) |
| :--- | :--- |
| Bills, pays, alloc, cashbook, notes | **Tax / VAT / GST** (not modelled) |
| Dropship remittance vs sales amount | Full **P&L / GL chart of accounts** |
| Shipment AP → landed cost **feedback** (named RPC) | **Report** product spec (aging, revenue dashboards) |
| Audit SQL for drift | Automated test suite (07 = roadmap only) |
| Stock deduct on issue (named in 02) | Shop cart ATP race (03 admits gap) |

---

## 2. Glossary

| Term | Plain English | Doc | LIVE vs TARGET |
| :--- | :--- | :--- | :--- |
| bill | Commercial document (sale or payable) | 01–02 | Table `bills` |
| draft | Editable; not final | 02 | **LIVE:** `invoice_status = 'draft'` · **TARGET:** `status = 'draft'` |
| issued | Final paper; totals frozen | 01 §1 | **LIVE:** `invoice_status = 'issued'` |
| voided | Cancelled paper | 02 | **LIVE:** `invoice_status = 'voided'` |
| credit_note / debit_note | Child bill adjusting parent | 01 §1, 02 | **TARGET:** `document_kind` · **LIVE:** same on `bills` when migrated |
| parent_bill_id | Link child note → original | 01 | LIVE column when present |
| document_kind | `standard` \| `credit_note` \| `debit_note` | 01 | TARGET; LIVE may use related enums |
| AR | They owe **us** (collect) | 01 §2 | Derived; never store `is_ar` |
| AP | **We** owe them (pay out) | 01 §2 | **LIVE:** `invoice_type = 'ap'` shortcut |
| tenant profile | Books-side profile for the company | 05 | `profiles.profile_type` tenant/company |
| from_profile_id / to_profile_id | Bill from / bill to | 01 §2 | **TARGET** · **LIVE:** infer from `profile_id` + type |
| profile_type | Kind of party | 05 | customer, vendor, cargo, … |
| subject_id | Domain id for that profile type | 05 | With `profile_type` |
| total_amount | Issued face in books currency | 01 §1 | Frozen after issue |
| due_amount | Cached amount still owed | 08 | **LIVE**; prefer `get_bill_net_balances` |
| net balance | Face ± notes − allocations | 02 §3, 04 | RPC `get_bill_net_balances` |
| pay | One receipt or payout | 02 §3 | Table `pays` (was `global_payments`) |
| pay_allocation | Pay slice applied to a bill | 02 §3 | **LIVE:** `bill_id` and/or `invoice_id` / `global_invoice_id` |
| unallocated_amount | Pay remainder not yet on a bill | 01 §7 | Becomes custody |
| custody (profile custody) | Store credit / leftover on profile ledger | 01 §7, 02 §3 | Not tenant till cash |
| cashbook_entry | Immutable ledger line | 01 §5 | `cashbook_entries` |
| cashbook_point | Physical place (drawer, safe, bank) | 01 §6 | `cashbook_points` |
| cashbook_point_pot | Cash balance at place × currency | 01 §6 | `cashbook_point_pots` |
| cashbook_account | Profile/tenant balance account | 01 §7 | `cashbook_accounts` |
| ledger transaction | **LIVE RPC name:** `record_ledger_transaction` | 01 §7, 08 | Writer for custody/books |
| frozen FX | Rate copied onto entry at post time | 01 §5 | `exchange_rate`, `quote_currency_code`, `rate_date`, `base_amount` |
| settlement_kind | Sell-now vs sell-when-paid | 02 §2 | **TARGET** · **LIVE:** `channel_meta.delivery_kind` |
| take | Revenue at **issue**; firm AR | 02 §2 | `settlement_kind = take` |
| condition | Revenue when **paid** | 02 §2 | `settlement_kind = condition` |
| source_type / source_id / source_key | Adapter plug tuple | 05 | **TARGET**; LIVE uses FKs too |
| source plug | Bill linked to feature row via source_* | 05 | No new FKs (target) |
| standard bill | Normal bill, not a note | 05 | `document_kind = standard` |
| bucket | Shipment cost group (material, freight, …) | 05, 06 B | **LIVE:** `ap_kind` |
| landed cost | Inventory unit cost after shipment FX | 06 B | `refresh_global_shipment_fx_from_ap_payments()` |
| dropship | Shop sells; tenant fulfills; COD ≠ sales | 06 A | Feature module |
| remittance | Bank net from courier after delivery | 06 A | Pay `source = courier_remittance` |
| dispense | Pay merchant profit from custody | 05, 06 A | **LIVE:** `dispense_middleman_payout_from_tenant` |
| write-off | Not defined in pack | — | **LIVE table:** `invoice_write_offs` listed in 01 §3 only |
| bill_charges | Legacy fee table | 01 §3 | Fold into `bill_lines` (TARGET) |
| bill_lines | Line items | 01 §3 | **LIVE FK:** `invoice_id` |
| global_stock_id | Warehouse stock row | 02 §5 | FIFO at issue |
| FIFO | First stock consumed on issue order | 02 §2 | At `kernel_issue_bill` / **LIVE:** `issue_sales_invoice` |
| ATP | Available to promise qty | 03 | `global_stock_atp_qty` (shop; not bill) |
| idempotency key | Retry-safe pay id | 03, 04 | **TARGET only** (`p_idempotency_key`) |
| FOR UPDATE | Row lock in RPC transaction | 03 | Postgres |
| READ COMMITTED | Default isolation | 03 | Postgres default |
| SECURITY DEFINER | RPC runs with owner rights | 04 | All kernel RPCs |

### Terms used but not defined in the pack (see §6)

`BP9`, `BP10`, `BP11`, `BP12`, `BP15`, `WA13`, `WA15`, `sync_shipment_ap_bills`, `issue_shipment_ap_bills`, `lock_global_shipment_costs`, `upsert_dropship_courier_ap_bill`, `post_ap_payout_with_allocations`, `get_bill_detail_bundle`, `list_*_for_source`, `payment_status`, `proforma`, `delivery paper`, `costs_locked`, `entity_type` on cashbook, `US-3`, `books_exchange_rates`, `BP16` (in other repo docs, not in 01–08 body).

---

## 3. Document map

### Per file

**README.md** — Index of the eight topic docs + pointers to external schema/gaps. **Owns:** navigation. **Defers:** all substance to `01`–`08`. **Read when:** first visit to `docs/kernel/`.

**01-SYSTEM-INVARIANTS.md** — Seven non-negotiable rules (immutable issued bills, derived AR/AP, no stray FKs, single-currency AP, frozen FX, cash points, overpay → custody). **Owns:** merge gate checklist. **Defers:** how to transition states (02), RPC names (04). **Read when:** every money PR review.

**02-STATE-MACHINES-AND-LIFECYCLES.md** — Draft/issue/void, take vs condition revenue, pay flows, shipment AP sync, stock edges. **Owns:** lifecycle diagram. **Defers:** locking (03), adapter plugs (05). **Read when:** changing status enums or issue/void behavior.

**03-TRANSACTIONS-LOCKING-AND-CONCURRENCY.md** — READ COMMITTED, `FOR UPDATE`, lock ordering, idempotency gaps, CHECK constraints. **Owns:** concurrency expectations. **Defers:** RPC signatures (04). **Read when:** multi-row or high-contention pay/issue code.

**04-RPC-AND-API-CONTRACTS.md** — Target `kernel_*` vs live function names, params, errors. **Owns:** API surface. **Defers:** adapter matrix (05), golden numbers (06). **Read when:** adding or calling kernel RPCs.

**05-ADAPTER-INTEGRATION-GUIDE.md** — source_* matrix, profiles, shipment bucket×currency, what not to SQL. **Owns:** feature integration rules. **Defers:** RPC bodies (04), scenarios (06). **Read when:** wiring shipments, shop, POS, delivery.

**06-ACCOUNTING-FLOWS-AND-GOLDEN-SCENARIOS.md** — Scenarios A–D row sketches. **Owns:** regression baselines. **Defers:** narrative prose ([money-story] — external). **Read when:** writing tests or debugging reconciliation.

**07-TDD-AND-VERIFICATION-SUITE.md** — Three-tier test pyramid (mostly **not built**). **Owns:** test roadmap. **Defers:** audit SQL (08). **Read when:** planning CI for `bills_pays/`.

**08-AUDIT-RECONCILIATION-AND-RUNBOOK.md** — Drift SQL, SOPs (cheque, till transfer, count). **Owns:** ops. **Defers:** invariants (01). **Read when:** production incident or periodic recon.

| File | Job | Owns | Defers to | Read when |
| :--- | :--- | :--- | :--- | :--- |
| README | Index | Links | 01–08 | Entry |
| 01 | Invariants | 7 rules, PR checklist | 02, 04 | Money PR |
| 02 | Lifecycles | States, take/condition | 03, 05 | Status/issue/void |
| 03 | Concurrency | Locks, isolation | 04 | Hot paths |
| 04 | RPC contract | kernel_* ↔ live | 05 | RPC changes |
| 05 | Adapters | source_*, profiles | 04, 06 | Feature plugs |
| 06 | Golden scenarios | A–D tables | 08, 07 | Tests/debug |
| 07 | TDD roadmap | Pyramid | 06, 08 | CI planning |
| 08 | Audit/runbook | SQL, SOPs | 01 | Ops |

---

## 4. End-to-end flows

### 4.1 Bill lifecycle

1. Adapter creates **draft** — **TARGET:** `kernel_upsert_draft_bill` · **LIVE:** `create_sales_invoice` / `sync_shipment_ap_bills` (draft).
2. User/system **issues** — **TARGET:** `kernel_issue_bill` · **LIVE:** `issue_sales_invoice`, `issue_shipment_ap_bills`, dropship at ship.
3. **Pay** allocates → `payment_status` → paid (cached).
4. **Void** draft anytime; **void issued** only if no pays (and stock rules) — **LIVE RPCs** per 02.
5. After issue, correction → **TARGET:** `kernel_create_bill_adjustment` · **LIVE:** `create_bill_adjustment` + `issue_bill_adjustment`.

```text
draft --issue--> issued --alloc--> paid
  |                 |
 void              void (no pays)
                      |
                      +--> credit_note / debit_note (child)
```

**If broken (invariant 1):** Editing `total_amount` on issued bill corrupts AR/AP and reports; notes can no longer reconcile.

### 4.2 Pay-in (collect / remittance)

1. **LIVE:** `post_customer_receipt_with_allocations` (**TARGET:** `kernel_post_payment`).
2. Insert `pays` + `pay_instruments` (optional splits).
3. Insert `pay_allocations` → reduce bill due.
4. `unallocated_amount` → **custody** ledger (`record_ledger_transaction` / writer in RPC).
5. Tenant cash → `cashbook_entries` (+ pot if wired).

**Verify:** `get_bill_net_balances(bill_id)`; sum custody for `profile_id`.

**If broken (invariant 7):** Overpay disappears → customer money lost or double-counted as revenue.

### 4.3 Pay-out (AP / merchant dispense)

1. **AP:** **LIVE** `post_ap_payout_with_allocations` — debit tenant cash, alloc AP bills, FX on line.
2. **Dropship profit:** **LIVE** `dispense_middleman_payout_from_tenant` — cashbook only, no bill alloc.
3. Foreign AP pay may call **`refresh_global_shipment_fx_from_ap_payments()`** (landed cost).

**If broken (invariant 5):** Landed cost uses today’s rate table → inventory value wrong historically.

### 4.4 Overpayment → custody → next bill

1. Bill B1 due 1500; pay 2000 → alloc 1500, **custody +500** (no second bill).
2. Bill B2 due 800; pay 300 cash + apply 500 custody → B2 paid.

**LIVE:** leftover apply partially in product ([BP11] external). **Verify:** `get_bill_net_balances(B2).due = 0`; custody 0.

**If broken (invariant 7):** Second invoice for 500 or revenue inflated.

### 4.5 Correction after issue

1. Only **credit_note** / **debit_note** child with `parent_bill_id`.
2. Never `UPDATE total_amount` on parent.

**If broken (invariant 1):** Audit trail lost; net balance RPC disagrees with finance.

### 4.6 Dropship (Scenario A)

| Step | Money | Numbers |
| :--- | :--- | :--- |
| Ship | Issue B1 merchant AR 1500; B2 courier AP 80 | COD face 2200 **not** on B1 |
| Deliver | Courier custody +2200 | Not tenant sales |
| Remittance | Pay in 2120 (= 2200 − 80) | Alloc 1500 → B1; custody +620 |
| Payout | Dispense 620 | No alloc to B1 |

**Reconcile:** Sales 1500; cash in 2120; 1500+620=2120 ✓.

**If broken (invariant 2 / money-story):** Using COD as sales → revenue wrong.

### 4.7 Multi-currency AP → landed cost (Scenario B)

1. **TARGET:** AP-1 `material:USD`, AP-2 `freight:GBP` ( **LIVE:** may differ until WA15).
2. Pay freight with `exchange_rate = 155.50` on **cashbook_entries**.
3. **`refresh_global_shipment_fx_from_ap_payments()`** updates costing.

**If broken (invariant 4):** Mixed-currency on one AP bill → FX and print wrong.

### 4.8 Wholesale overpay (Scenario C)

Same as §4.4 with B1=1500, B2=800, custody 500 consumed.

**If broken (invariant 6):** Cash without `cashbook_point_id` → cannot reconcile till.

---

## 5. Tax and reports — coverage check

### 5.1 What the pack DOES say

- **Revenue timing:** 02 §2 — `take` “Recognized at **issued**”; `condition` “When **paid**”; “Unpaid condition is not firm sales **in reports**” (word “reports” appears; no report definitions).
- **Net balance reads:** 02 §3, 04 — `get_bill_net_balances(p_bill_id)`; 08 audit prefers it over `due_amount` cache.
- **Landed cost:** 06 Scenario B — `refresh_global_shipment_fx_from_ap_payments()`; 08 escalation table.
- **Legacy charges:** 01 §3 — `bill_charges` legacy, fold to `bill_lines`.
- **Reconciliation SQL:** 08 §1–4 — bill due drift, pot vs ledger, orphaned unallocated, issued mutation smell.
- **Dropship sales vs cash:** 06 A golden assert “Sales = 1500; cash in = 2120”.
- **AP / expense:** 02 §2 — `settlement_kind` null on AP; “N/A (expense / COGS via shipment costing)”.

### 5.2 What the pack does NOT say

**Tax:** VAT/GST/sales tax/withholding/tax codes are **not modelled anywhere in these nine files.**

**Reports:** No spec for aging buckets, AR/AP trial balance, cash flow statement, or which UI module reads which table. Only hints: firm AR for `take`, condition excluded from firm sales until paid; audit queries in 08.

**GAPS (questions for owners — not facts):**

| Topic | Open questions |
| :--- | :--- |
| Tax line | Per `bill_lines`, per-bill charges, or separate tax table? |
| Tax in total | Included in `total_amount` or additive? Does `get_bill_net_balances` include tax? |
| Notes | Do CN/DN copy tax breakdown? |
| Adapters | Which `source_type`s need tax (sales vs AP vs dropship)? |
| Reporting default | Is official revenue `take` at issue, `condition` at pay, or mixed by desk? |

---

## 6. Fault audit

| ID | File | Section | Sev | Fault | Suggested fix |
| :--- | :--- | :--- | :--- | :--- | :--- |
| F01 | README | — | minor | Says “Eight docs” but pack is README + 8 = **9 files** | State “8 topic docs + README” |
| F02 | All | — | **major** | **LIVE vs TARGET** not labeled on every RPC/column mention | Add legend box to README; tag tables in 04 |
| F03 | 01–08 | — | **major** | **Dangling refs:** `00-gaps`, `kernel-schema`, `money-story`, `spec`, `BP*`, `WA*`, `architecture/database.md` | README “Prerequisites” list with paths; or inline one-line gloss for each ticket |
| F04 | 01 §3 vs live | Kernel isolation | **blocker** | Invariant forbids feature FKs to `bills` but **live** `shop_orders.global_invoice_id` still exists; pack says “retire” only | State explicitly: **violation allowed until BP9 migration**; merge gate for *new* FKs only |
| F05 | 02 §4 vs 01 §1 | Shipment sync | **major** | “Sync may update **unpaid issued**” vs zero silent mutation on issued `total_amount` | Clarify: sync may refresh **draft**; issued changes only via notes OR document allowed refresh rules in spec (external) |
| F06 | 08 §1 vs 02 §3 | Audit SQL | **major** | Audit #1 compares `total_amount − SUM(alloc)` to `due_amount` — **ignores credit/debit notes**; text says use `get_bill_net_balances` | Replace or supplement SQL; warn not to use #1 alone |
| F07 | 03 vs 02 | Stock | major | Shop cart ATP without `FOR UPDATE` admitted; not cross-linked from 02 stock section | Link 03→02; classify as known oversell risk |
| F08 | 04 | kernel_reverse_payment | major | Documented as target; live “partial” — no live function name listed | Add live void/collect RPC names from schema grep |
| F09 | 03, 04 | Idempotency | major | Pay idempotency **not built**; remittance double-post risk | Elevate in README “known production risks” |
| F10 | 01 §6 | BP15 | major | Invariant requires `cashbook_point_id`; same doc admits column not on all writers | Mark invariant 6 as **target-enforced** with live exception until BP15 |
| F11 | 06 A | Numbers | minor | Courier AP 80 and net 2120 implied; not shown as 2200−80 in table | Add one-line arithmetic in 06 |
| F12 | 02 | Void | minor | “No pays (or reverse pays first)” vs 03 “cannot void paid” — same idea, different order | Single void rule block in 02 |
| F13 | 01 §3 | write-off | minor | `invoice_write_offs` listed as kernel child but never explained | Glossary or delete from list until documented |
| F14 | 07 | — | minor | `supabase/tests/fixtures/` does not exist | Mark “proposed path” |
| F15 | 05 | BP10 | minor | `list_*_for_source` referenced but not named | “Not built (BP10)” |
| F16 | 08 §3 | Orphan SQL | minor | `source_type` list may not match all live writers | Document “verify against `record_ledger_transaction` callers” |
| F17 | — | Tax/reports | **blocker** (doc gap) | No tax or report contract | §5.2 gaps; link `reporting_treasury` external |
| F18 | 04 | get_bill_detail_bundle | minor | Named without signature | Grep schema or remove |

### Top 5 issues to fix first

1. **F04 + F02** — Engineers will violate “no FK” or mix live/target and ship wrong code. Clarify migration exceptions and label every name.
2. **F06** — Audit SQL can falsely flag healthy bills or miss note-adjusted dues; ops trust wrong queries.
3. **F05** — Issued AP sync vs immutability confuses implementers of WA15.
4. **F09** — Double remittance/collect with no idempotency is real money duplication.
5. **F03** — BP/WA tickets are meaningless without `00-gaps.md` in the pack; add a kernel-local “ticket glossary” table.

---

## 7. Corrected docs (major / blocker only)

### F02 — README legend (proposed addition)

**Before:** (no legend)

**After:**

```markdown
## Naming in this pack

| Label | Meaning |
| :--- | :--- |
| **LIVE** | Column/RPC in `supabase/schemas/bills_pays/` today |
| **TARGET** | Intended contract (`kernel_*`, `from_profile_id`, `status`) |
| **GAP** | Described but not fully implemented — see `docs/features/bills_pays/00-gaps.md` |
```

### F04 — 01 §3 Kernel isolation (proposed replacement paragraph)

**Before:** “Live exceptions being retired: … do not add new FKs”

**After:**

```markdown
**New FKs:** Feature tables must not add new references to `bills.id` or `pays.id`.

**Legacy LIVE (do not extend):** `shop_orders.global_invoice_id`, `bills.ap_shipment_id`,
`bills.shop_order_id` — removal tracked in BP9. Existing FKs remain until migration.
```

### F05 — 02 §4 Shipment AP sync (proposed clarification)

**After (insert after table):**

```markdown
> **Immutability:** Unpaid **issued** AP bills must not have `total_amount` changed silently
> (invariant 1). While `costs_locked = false`, sync may update **draft** bills freely.
> Changes to **issued** AP totals require credit/debit notes or an explicitly documented
> sync rule in `spec.md` (not repeated in this pack).
```

> TODO(owner): Confirm whether live `sync_shipment_ap_bills` still mutates issued unpaid headers.

### F06 — 08 §1 Net balance (proposed replacement intro)

**Before:** SQL only, then one line on `get_bill_net_balances`.

**After:**

```markdown
## 1. Net balance integrity

**Do not use the query below as sole truth** — it ignores credit/debit notes and net adjustments.

**Preferred:** `SELECT public.get_bill_net_balances(:bill_id);`

The SQL below only detects cache drift on **simple** issued bills (alloc vs `due_amount`):
```

### F09 — README known risks (proposed block)

```markdown
## Known LIVE gaps (money at risk)

| Risk | Mitigation |
| :--- | :--- |
| No pay `idempotency_key` (BP12) | Adapter must not retry remittance without dedup |
| Partial reverse pay (WA13) | Cheque bounce SOP manual |
| `cashbook_point_id` not on all pays (BP15) | Till recon incomplete |
```

### F17 — Tax (no invented rules)

> TODO(owner): Add `09-TAX-AND-REPORTING.md` or extend `docs/features/reporting_treasury/spec.md` with: tax line model, inclusion in `total_amount`, CN/DN tax behavior, and revenue default (`take` vs `condition`) per report.

---

*End of onboarding and audit. For edits to the pack itself, apply §7 snippets via PR after owner answers TODOs.*
