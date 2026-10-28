# Bills & pays — spec

One money pack. **Start here (target map + graphs):** [README.md](README.md). Layers: **bill** · **pay** · **cashbook**. Not a wallet. **Gaps:** [00-gaps](00-gaps.md). **Schema:** [kernel-schema](kernel-schema.md). **PR rules:** [REFERENCE](../../kernel/REFERENCE.md). **Tests:** [tests.md](tests.md). **Numbers:** [money-story](money-story.md).

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/bills_pays/spec.md` + [00-gaps](00-gaps.md) |
| UI | **Bills**, **Payments**, **Cashbook** in `bills_pays/` (`/app/bills`, `/app/finance/payments`, `/app/wallet`). Bills: list, compose (today stock take/condition/walk-in), print. **Target compose:** any paper, stock optional ([BP13](00-gaps.md)). **Target pay:** in/out from accounts ([BP14](00-gaps.md)). |
| SQL | **BP4 (2026-10):** tables `bills`, `bill_lines`, `pays`, `cashbook_*`; split `supabase/schemas/bills_pays/` + invoice domain |
| Access | `app`; `shop` merchant statement |
| Model | BW — [business-models](../../architecture/business-models.md) |

## Where to look

| Need | Path |
| :--- | :--- |
| Target kernel tables (from/to, source plug) | [kernel-schema.md](kernel-schema.md) |
| Invoice RPCs | `supabase/schemas/` invoice domain + grep `sales_invoices` |
| Kernel build | [doc/fix/2026-10-12-bills-pays-kernel-plan.md](../../../doc/fix/2026-10-12-bills-pays-kernel-plan.md) |
| Pays / ledger | Grep `global_payments`, `record_ledger_transaction` in `public.sql` |
| Desks (legacy paths) | `sales_invoice/`, `wallet/` module folders |
| Types | `web/src/types/database.types.ts` |

## Rename map (spec term → live)

| Spec | Table (live) | Legacy column names still in DB |
| :--- | :--- | :--- |
| `profiles` | `profiles` (`customer_group_id`, `operating_tenant_id` for customers) | — |
| `bills` | `bills` | `invoice_id` on children; was `sales_invoices` |
| `bill_lines` | `bill_lines` | was `sales_invoice_items` |
| `bill_charges` | **drop** — fold into `bill_lines` (`line_kind = charge`) | live still `bill_charges` |
| `pays` | `pays` | was `global_payments` |
| `pay_instruments` | `pay_instruments` | was `global_payment_instruments` |
| `pay_allocations` | `pay_allocations` | `invoice_id` = bill id; was `invoice_payments` |
| `cashbook_accounts` | `cashbook_accounts` | was `wallet_accounts` |
| `cashbook_points` | `cashbook_points` | Till/safe/drawer under a tenant cashbook account. Columns: [kernel-schema](kernel-schema.md). Pay tag / transfer: [BP15](00-gaps.md) |
| `cashbook_entries` | `cashbook_entries` | was `universal_wallet_ledger`; optional `cashbook_point_id` |
| `banks` | `bd_banks` | — |

FKs in RPCs/UI: `profile_id` on bills/pays and shop order; alloc `bill_id` often `invoice_id`. **Cashbook** is the product name; route `/app/wallet` is legacy path only.

**Profile** = money party (`profile_type` customer, merchant, …). Not `recipient_profiles` (delivery). `customer_groups` until [BP3](00-gaps.md).

## Scope

| | |
| :--- | :--- |
| Surfaces | `app`; `shop` statement |
| In | Money **kernel**: profile, bill (stock lines optional), credit/debit note, pay in/out, alloc, cashbook (incl. profile custody / leftover). Features **plug in**. |
| Out | Delivery paper / proforma; packing slip / COD face; SKU qty / landed cost rows; reports; investor withdraw; Koba/thrift; shipment outcome qty |

## Desks

| Desk | Job | Code route |
| :--- | :--- | :--- |
| Bills | Issue / void / print / compose | `bills_pays/` + `billsRepository` — `/app/bills` |
| Payments | Receive, pay out, from accounts | `wallet/` — `/app/finance/payments` |
| Cashbook | Audit leftover / custody | `wallet/` — `/app/wallet` |

Paper: `draft` / `issued` / `voided`. Money: `due` / `partially_paid` / `paid`. **Document:** `standard` / `credit_note` / `debit_note` on the same `bills` row (`parent_bill_id` on notes). `bills.note` is a comment, not a credit note. **Settle:** `take` (sell now, pay later) vs `condition` (sales when paid) — target column `settlement_kind` ([kernel-schema](kernel-schema.md)); live `channel_meta.delivery_kind`. Trade compose: one kind per bill. Walk-in: take only. Proforma = Delivery paper, not a bill.

**Compose is modular.** Party + direction (they owe / we owe) + totals. **Stock lines are a slot**, not required. Header / description lines for fees, AP, service. FIFO stock issue only when a line has `global_stock_id`. Same issue / void / print / notes / pay on every bill.

**Pay desk is modular.** One flow: **receive** or **pay out**, from **bank / cash instrument** or **cashbook account** (tenant cash, profile leftover = custody). Alloc to bills optional; remainder stays on that account. Courier remittance and AP payout are the same writers with a source, not separate products. Each pay (and each split-tender slice) stores **`cashbook_point_id`** so you can find where that amount is ([kernel-schema](kernel-schema.md)).

**Cash points** (product label; not “location” — stock uses locations): a **place** (till, safe, bank, fintech). No currency on the point. On-hand cash is `cashbook_point_pots` (place × currency). Each ledger line freezes cash amount, currency, **BDT per 1 cash**, and books amount. Rate list `books_exchange_rates` is a default pick; posted lines do not look it up again. [kernel-schema](kernel-schema.md). Point CRUD live; FX pots not wired on refund/collect yet ([BP16](00-gaps.md)). Profile custody: no points in v1. Point-to-point transfer: later ([BP15](00-gaps.md)).

### Kernel (features plug in)

Bills/pays is independent. Features call it; they do not own pays.

| Call | Job |
| :--- | :--- |
| Upsert draft / issue / void | Commercial paper (`source_type` + `source_id` + optional key) |
| `create_bill_adjustment` | Credit or debit **child** of an issued bill. Positive amount. Kind is the sign. |
| Pay in / out + alloc | Settle a bill or an open credit note |
| Apply leftover | Cashbook / open credit onto another bill of the same profile |
| Reverse pay | Bounce / wrong pay; do not edit the bill ([WA13](00-gaps.md)) |
| `get_bill_net_balances` + list by source | Original ± notes − pays. Features do not re-sum allocs. |

Build order: [kernel plan](../../../doc/fix/2026-10-12-bills-pays-kernel-plan.md).

**Adapter (shipment):** cost buckets → AP drafts. FX from pays. After issue, do not edit that bucket; shortage/VAT → credit note, then costing follows the note. **Unpaid issued:** still a note (no silent amend of the original total).

`sell` / `total` = tenant sell. COD ≠ sales. Cost never on print / GP.

| Paper | Cash | Sales |
| :--- | :--- | :--- |
| Proforma | No | No |
| Take | After pay | At issue |
| Condition | After pay | When paid |
| Dropship merchant | Remittance | At issue (merchant total; issue at ship) |
| Walk-in | Collect | At issue |
| AP (per shipment cost bucket) | Pay out (`ap_payout`) | Never sales |

**Pay in** → ALLOC to AR bills; remainder → profile cashbook. **UI:** Customer tab (collect) + **Courier** tab (dropship net bank in → same writer, `courier_remittance`). **Pay out:** dropship shop profit via `post_money_out` (`source_type=commission`; legacy `dispense_middleman_payout_from_tenant` wraps spine) or AP alloc (`post_ap_payout_with_allocations`). Inbound AP sync: `sync_shipment_ap_bills` ([WA15](00-gaps.md)).

### AP paper (not AR compose)

AR bills use `bill_lines` (item, qty, sell, disc). AP bills have **no** `bill_lines`. Created by `sync_shipment_ap_bills` (inbound) or `upsert_dropship_courier_ap_bill` (dropship courier, `source_type=dropship_courier`). While shipment `costs_locked` is false, bucket bills stay **`draft`** and sync updates totals; **`lock_global_shipment_costs`** runs sync then `issue_shipment_ap_bills` (`draft` → `issued`). **Issued** standard AP bills are immutable for face totals — sync must not rewrite them; shortage/VAT = credit note ([REFERENCE inv. 19](../../kernel/REFERENCE.md)). Dropship courier AP is **`issued` at ship**. Print snapshot in `bills.channel_meta.ap_paper` (refreshed while unpaid and no pay yet).

| `ap_kind` (= cost bucket) | Print shows | Not on paper |
| :--- | :--- | :--- |
| `material` | Foreign product total, conversion rate, BDT due | SKU / qty lines |
| `freight` | Weight (kg), foreign price, conversion rate, BDT due | Item grid |
| `customs`, `handling`, `finance`, `other` | Description + amount per cost row in bucket | Sell / discount |

Legacy `vendor` / `cargo` / `local` may remain on old bills; sync voids unpaid legacy bills when bucket bills are refreshed.

**Shipment FX:** not stored on `global_shipments`. `shipment_ap_bucket_paid_totals` uses pay `exchange_rate` × foreign allocation (bill currency). `_global_shipment_landed_fx_inputs` / `refresh_global_shipment_fx_from_ap_payments` return product rate (material), cargo FX (freight), cargo per kg, and money-weighted `transaction_rate`. `post_ap_payout_with_allocations` then restamps landed cost. Leftover on an FX payout is Taka minus (foreign alloc × rate).

UI: `ApBillPaper` on bill detail/preview when `invoice_type = ap`. **Parties on paper:** `material` = vendor **From**; `freight` / `customs` = cargo **From**; other buckets = tenant **Payable by**. `profile_id` stays the payee for pay-out. List filters they-owe vs we-owe. Manual AP / header bills from compose ([BP13](00-gaps.md)); shipment sync stays the inbound adapter.

## Stories

### Bills
- [x] US-1 FIFO issue; print; compose (stock take/condition/walk-in).
- [x] US-1b Trade take/condition; walk-in take; condition held until paid.
- [x] US-17 Modular compose: bill with or without stock; they-owe and we-owe ([BP13](00-gaps.md)).
- [x] US-18 Modular pay: receive / pay out from instruments or cashbook (custody) ([BP14](00-gaps.md)).
- [ ] US-2 Returns emit a credit note; excess → customer cashbook. Not a silent total edit ([BP5](00-gaps.md)).
- [ ] US-3 Never issue bill from pay.
- [x] US-4 Dropship merchant at ship; packing slip ≠ bill.
- [x] US-5 Delivery paper close → bills ([SI19](00-gaps.md)).

### Pays + leftover
- [x] US-6 Cashbook via ledger writer only; collect tags **cash point + pot** ([BP15](00-gaps.md), [BP16](00-gaps.md)).
- [x] US-7 One pay-in writer (collect + remittance).
- [x] US-8 Split tender at collect; **cheque bounce v1** reverses whole pay ([WA13](00-gaps.md)) — partial split-tender bounce still later.
- [x] US-9 Merchant leftover payout; not ALLOC (remittance → cashbook; Pay out / finance hub step 3).
- [x] US-10 Customer overpay / leftover: cashbook at collect; apply on Pay in (FIFO) or later from the payment.
- [x] US-11 Shipment AP auto-sync; outcome qty costing; commercial credit = bill note ([BP8](00-gaps.md)).
- [ ] US-12 Credit/debit notes on `bills`. Same RPCs for AR and AP. Desk + print ([BP8](00-gaps.md)).
- [ ] US-13 Generic `source_type` / `source_id` / `source_key`; one upsert for adapters ([BP9](00-gaps.md)).
- [ ] US-14 Reads: balances, pays/FX, documents by source and by profile ([BP10](00-gaps.md)).
- [x] US-15 Apply leftover / open credit / **profile custody** to bills — pay detail, bill detail, collect ([BP11](00-gaps.md)).
- [x] US-16 Reverse a pay (receipt, AP payout, remittance); cheque bounce v1 ([BP12](00-gaps.md), [WA13](00-gaps.md)).
