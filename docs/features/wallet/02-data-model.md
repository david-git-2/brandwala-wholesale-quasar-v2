# Wallet & receipts — data model

Live SQL: ledger in `public.sql` (wallet schema stub). Payments today: `global_payments`, `invoice_payments`. Target below. Gaps: [00-gaps](00-gaps.md).

```text
RECEIPT (money in) — one customer visit / one bank drop
    ├─ instrument lines (cash, cheque, bkash, …)
    ├─ allocations → sales_invoices (up to total_amount)
    └─ remainder → record_ledger_transaction
         tenant cash | customer store credit | courier | merchant payable

PAYOUT (money out) → ledger + tenant cash
```

COD **face** is not a receipt row. It lives on `shop_orders` (and invoice `channel_meta` snapshot).

---

## Three layers (industry AR)

| Layer | Table (target) | Job |
| :--- | :--- | :--- |
| Receipt | `global_payments` | Money the payer gave you in one posting. Header total, date, note, payer. |
| Instrument line | `global_payment_instruments` (new) | How that money was paid: cash row, cheque row, bKash row, … |
| Allocation | `invoice_payments` | How much of the receipt applies to each open bill. |

Invoice rows only store **`paid_amount` / `due_amount` / `payment_status`** after allocation. They do **not** store cheque numbers or bKash trx ids.

One invoice can have many receipts over time. One receipt can allocate to many invoices (billing-profile collect).

---

## Receipt header (target; extend `global_payments`)

Reuse/extend `global_payments` (or rename in a later split). Essentials:

| Column | Meaning |
| :--- | :--- |
| `parent_tenant_id`, `operating_tenant_id` | Books vs desk |
| `billing_profile_id` | Payer (wholesale buyer or dropship merchant) |
| `source` | High-level channel: `customer_cash` \| `bank` \| `store_credit` \| `courier_remittance` |
| `amount` | **Sum of instrument lines** (dropship remittance = **net remitted**, not COD face) |
| `received_on` | Date money was taken at desk / hit bank |
| `reference` | Optional voucher / batch ref for the whole receipt |
| `note` | Free-text note for the whole visit |
| `shop_order_id` | Optional; dropship remittance |

`amount` must equal `SUM(instrument_lines.amount)`. Do not store `cod_collect_amount` as `amount`.

---

## Instrument lines (target; new table)

Child of `global_payments`. One receipt can have **many lines** (split tender).

| Column | Meaning |
| :--- | :--- |
| `payment_id` | FK → `global_payments` |
| `payment_method_code` | FK → `payment_methods.code` (`cash`, `cheque`, `bkash`, `bank_transfer`, …) |
| `amount` | Line amount (> 0) |
| `reference` | bKash / bank trx id, or short note on this line |
| `bd_bank_id` | FK → `bd_banks.id`. **Required when** `payment_method_code = cheque` |
| `cheque_number` | **Required when** cheque |
| `cheque_date` | **Required when** cheque (issue / post-dated date on the instrument) |

Rules:

- At least one line per receipt (except `store_credit`-only receipts, which may stay a single header row until unified).
- Cheque bank comes from [global reference `bd_banks`](../global_reference/02-data-model.md), not free text.
- bKash uses `payment_methods` catalog + `reference` for trx id. No separate bKash table.
- Cash line: `amount` only; optional line `reference` for till / counter note.

**v1 clearing:** cheque lines count toward receipt `amount` and cash-in when posted at the desk (PDC accepted). Bounce / dishonour is a **reversing receipt** later — not in v1.

---

## Allocation (target)

Existing `invoice_payments`: receipt → invoice, `amount` ≤ due.

- Sum of allocations ≤ receipt `amount`.
- Updates invoice `paid_amount` / `due_amount` / `payment_status` only.
- Allocations attach to the **receipt header**, not to individual instrument lines.

Wholesale: allocate collect to the **buyer** bill. Dropship: allocate **min(net remittance, merchant invoice due)**. Remainder → merchant (courier fee already netted out of receipt, or a fee line — not extra sales).

---

## Collect entry points (same tables)

| Desk | Starts from | Posts |
| :--- | :--- | :--- |
| Invoice collect | One open bill | Receipt + lines + allocation to **that** invoice (and optionally others if due remains) |
| Billing-profile collect | Customer account / billing balances | Receipt + lines + allocations across **open bills** for that profile |

Both are wallet receipts. Do not add a second payments product per screen.

---

## Ledger (as-built intent)

One account per `(parent_tenant_id, entity_type, entity_id, currency)`. Lines only via `record_ledger_transaction`.

| Entity | Typical use |
| :--- | :--- |
| `tenant` | Operating cash (parent pool) |
| `customer` | Store credit; dropship merchant payable (`billing_profile`) |
| `courier` | Optional in-transit / fee clearing — **not** a second COD sales book |
| `vendor` / `cargo` / `investor` | Other books; investor **no** withdraw |

`source_type` on a ledger line should point at the **receipt** (or payout), not a parallel “delivered_costing” purpose for the same cash.

---

## Payout

Debit merchant wallet, debit tenant cash. Not an invoice allocation. Not investor portal.

---

## Report split

| Sum | Source |
| :--- | :--- |
| Tenant sales | Issued invoices (`total_amount`) |
| Cash in | Receipt headers (`global_payments.amount`) |
| By method | Instrument lines joined to `payment_methods` |
| Cheque detail | Instrument lines where method = `cheque` + `bd_banks` |
| Courier vs bank | Receipts with `source = courier_remittance` |
| What we owe resellers | Merchant wallet / ledger |

Never treat receipt `amount` as sales. Never `SUM(COD face)` as revenue.

---

## Worked split-tender example

Buyer due **30,000** on one bill. They pay in one visit:

| Line | Method | Amount | Extra |
| :--- | :--- | ---: | :--- |
| 1 | cash | 5,000 | — |
| 2 | cheque | 15,000 | Sonali Bank, #88421, dated 2026-09-25 |
| 3 | cheque | 10,000 | BRAC Bank, #1102, dated 2026-09-20 |

→ Receipt `amount` = **30,000**, `note` = optional visit note.  
→ One allocation **30,000** → invoice → `paid`.  
→ Cash-in report: 5k cash + 25k cheque (by instrument), total 30k.
