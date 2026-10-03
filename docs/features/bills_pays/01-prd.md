# Bills & pays — PRD

One money pack. Layers: **bill** · **pay** · **cashbook**. Not a wallet. Table names: [02](02-data-model.md). Target desks: Bills · Payments · Cashbook ([BP5](00-gaps.md)).

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/bills_pays/` |
| UI | Blank desks at `/app/sales/invoices`, `/app/finance/payments`, `/app/wallet` (`bills_pays/`). No issue/pay/ledger actions yet ([BP5](00-gaps.md)). |
| SQL | Live names in [02 rename map](02-data-model.md#rename-map-spec--live) |
| Access | `app`; `shop` merchant statement |
| Model | BW — [business-models](../../architecture/business-models.md) |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app`; `shop` statement |
| In | Issued bills (take / condition / dropship merchant; later AP). Pay in/out. Cashbook leftover. Shared **profile**. |
| Out | Delivery paper / optional proforma. Packing slip / COD face. Reports. Investor withdraw. Koba / thrift. Vendor **cost** credit (outcomes) until [WA15](00-gaps.md). |

Numbers: [money-story](money-story.md). Gaps: [00-gaps](00-gaps.md).

---

## Desks

| Desk | Job | Code |
| :--- | :--- | :--- |
| Bills | Issue / void / print | `sales_invoice/` — `/app/sales/invoices` |
| Payments | Pay in / pay out | `wallet/` — `/app/finance/payments` |
| Cashbook | Audit leftover | `wallet/` — `/app/wallet` |

`sell` / `total` = tenant sell. COD never sales. Cost never print / GP.

| Paper | Cash | Sales |
| :--- | :--- | :--- |
| Proforma | No | No |
| Take | After pay | At issue |
| Condition | After pay | When paid |
| Dropship merchant | Remittance | Issued merchant total |
| Walk-in | Collect | At issue |

Pay in → ALLOC to open bills. Remainder → **cashbook on that profile** (we owe them). Pay out settles cashbook. Not ALLOC. Merchant pay out now; vendor/cargo later ([WA15](00-gaps.md)).

---

## Stories

### Bills
- [ ] US-1 FIFO issue. Print qty, sell, charges.
- [ ] US-2 Returns: `return_quantity` only. Excess paid → customer cashbook.
- [ ] US-3 Never issue a bill from a pay.
- [ ] US-4 Dropship merchant bill at ship. Packing slip ≠ bill. COD ≠ bill.
- [ ] US-5 Delivery paper desk close (dropdown take / condition / return); optional proforma; then take and/or condition bills ([SI19](00-gaps.md)).

### Pays + leftover
- [ ] US-6 Cashbook only via ledger writer. Reverse entries. Parent books.
- [ ] US-7 One pay-in writer (collect + remittance). Never rewrite sell.
- [ ] US-8 Split tender. Cheque bounce v2 ([WA13](00-gaps.md)).
- [ ] US-9 Merchant leftover from pay remainder; pay out. Not ALLOC. Live RPC `dispense_middleman_payout_from_tenant` until BP2.
- [ ] US-10 Customer overpay / return leftover → customer cashbook. Next collect may apply it.
- [ ] US-11 Vendor cheaper goods = shipment outcomes today. AP bill + cashbook later ([WA15](00-gaps.md)). Not a take bill.
