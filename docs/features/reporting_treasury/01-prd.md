# Reporting & Treasury — PRD

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/reporting_treasury/` |
| UI | `web/src/modules/reporting_treasury/` (reports); pays at `web/src/modules/wallet/` |
| SQL | Report RPCs in `public.sql` |
| Access | `app`; parent books |
| Role | **Read** sales, cash, COD ops, cashbook. Do not post pays. |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` |
| In | Eight report views + month snapshot. CSV export. |
| Out | Creating invoices. Posting payments/remittance. Editing shipments. Shadow P&L tables. |

See [scopes](../../architecture/scopes.md). Money: [bills_pays](../bills_pays/01-prd.md). Numbers: [money-story](../bills_pays/money-story.md). Gaps: [00-gaps](00-gaps.md).

---

## Locked: four money layers

A number is **sales**, **cash**, **COD face**, or **payable**. Never blend them into one “revenue.”

| Layer | Source | Date filter |
| :--- | :--- | :--- |
| Sales | Issued **take** `total_amount`; **condition** bills only when **paid** | Invoice date (take) / paid date (condition) |
| Gross profit | **Shipment P&L** (not invoice-line cost) | Shipment / period on that report |
| Cash in | Receipts | Receipt date |
| AR | Take invoice `due_amount` is firm. Condition `due` is not guaranteed (stock may return) | As-of |
| COD ops | Order COD vs remittance | Delivered / remitted dates |
| Payable | Cashbook (merchant, store credit, courier) | As-of |

Dropship: sales = merchant **1,500**, not COD **2,200**. Cash = remittance **2,120**. Payable = **620**. [money-story](../bills_pays/money-story.md).

Sales reports filter `invoice_type` (wholesale / dropship / retail).

---

## Personas

| Role | Actions |
| :--- | :--- |
| Owner / CFO | Month tiles (separate). GP. Shipment P&L. |
| Treasury | Read AR aging, COD ops, cash in. **Posting cash is pays (wallet module).** |
| Auditor | Export; check sales ≠ cash ≠ COD |

---

## Stories

### US-1: Profit is per shipment, not per item
- Join **issued invoice lines** to lots → outcome/line → **`shipment_id`**. Revenue = those lines’ sell (not COD).
- Cost = that shipment’s **landed** entries **plus local costs** ([procurement US-8](../procurement_stock/01-prd.md)). Inbound unsellable/missing stays on the shipment, not on the bill.
- Bill lines are **sell only**. No `sales_invoice_item_costs` table. GP never COGS from the bill.
- [ ] Local costs in the same P&L number ([RT18](00-gaps.md)).
- [ ] Stop invoice-margin RPCs that COGS each line ([RT19](00-gaps.md)).

### US-2: Eight views, one question each

| # | View | Question | Must not |
| :--- | :--- | :--- | :--- |
| 1 | Invoice book | What bills did we issue? | COD face |
| 2 | Invoice sales | Billed totals in the period | Line cost / remittance as GP |
| 3 | Customer dues | Who owes **bills**? | Age Karim / recipient COD |
| 4 | Cash in | What hit the bank/till? | Invoice totals or COD face |
| 5 | Courier COD | Face vs remitted vs in-transit | Feed sales KPI |
| 6 | Cashbook liability | What we owe (split merchant / customer / courier) | One lump that hides payouts |
| 7 | Shipment P&L | Did the batch pay off? (invoice lines by shipment vs landed + local) | Per-SKU cost, COD as sales |
| 8 | Month snapshot | Four tiles + merchant payable | One blended “TOTAL REVENUE” |

Month tiles: **Sales** \| **Gross profit** (sum of shipment P&L) \| **Cash in** \| **AR due**. Optional fifth: **Merchant payable**. Caption: cash may exceed sales when courier remits reseller money.

### US-3: Reporting does not collect
- [x] Collect desk lives in **pays** (`PaymentsPage` / `CollectCustomerPaymentPage`). Report routes are read-only.

---

## Month snapshot (target)

```text
Sales (issued bills)     Gross profit
Cash in (receipts)       AR due (bills)
Merchant payable (ledger)
```
