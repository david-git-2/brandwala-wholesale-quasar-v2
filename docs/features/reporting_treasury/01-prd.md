# Reporting & Treasury — PRD

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/reporting_treasury/` |
| UI | `web/src/modules/reporting_treasury/` |
| SQL | Report RPCs in `public.sql` |
| Access | `app`; parent books |
| Role | **Read** sales, cash, COD ops, wallets. Do not post receipts (wallet). |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` |
| In | Eight report views + month snapshot. CSV export. |
| Out | Creating invoices. Posting payments/remittance. Editing shipments. Shadow P&L tables. |

See [scopes](../../architecture/scopes.md). Bills: [sales_invoice 01](../sales_invoice/01-prd.md). Receipts: [wallet 01](../wallet/01-prd.md). Numbers: [money-story](../sales_invoice/money-story.md). Gaps: [00-gaps](00-gaps.md).

---

## Locked: four money layers

A number is **sales**, **cash**, **COD face**, or **payable**. Never blend them into one “revenue.”

| Layer | Source | Date filter |
| :--- | :--- | :--- |
| Sales / GP | Issued `sales_invoices.total_amount`; cost snapshot | Invoice date |
| Cash in | Receipts | Receipt date |
| AR | Invoice `due_amount` by **billed** profile | As-of |
| COD ops | Order COD vs remittance | Delivered / remitted dates |
| Payable | Ledger (merchant, store credit, courier) | As-of |

Dropship: sales = merchant **1,500**, not COD **2,200**. Cash = remittance **2,120**. Payable = **620**. [money-story](../sales_invoice/money-story.md).

Sales reports filter `invoice_type` (wholesale / dropship / retail).

---

## Personas

| Role | Actions |
| :--- | :--- |
| Owner / CFO | Month tiles (separate). GP. Shipment P&L. |
| Treasury | Read AR aging, COD ops, cash in. **Posting cash is wallet.** |
| Auditor | Export; check sales ≠ cash ≠ COD |

---

## Stories

### US-1: Margin from issued bills + cost snapshot
- [ ] Invoice profit uses cost at issue (`sales_invoice_item_costs` when built; today `unit_cost_price` on the line).
- [ ] Shipment P&L realized revenue = **invoice sell** on that stock, not COD.

### US-2: Eight views, one question each

| # | View | Question | Must not |
| :--- | :--- | :--- | :--- |
| 1 | Invoice book | What bills did we issue? | COD face |
| 2 | Invoice profit | Sales vs COGS | Remittance as revenue |
| 3 | Customer dues | Who owes **bills**? | Age Karim / recipient COD |
| 4 | Cash in | What hit the bank/till? | Invoice totals or COD face |
| 5 | Courier COD | Face vs remitted vs in-transit | Feed sales KPI |
| 6 | Wallet liability | What we owe (split merchant / customer / courier) | One lump that hides payouts |
| 7 | Shipment P&L | Did the batch pay off? | COD as realized sales |
| 8 | Month snapshot | Four tiles + merchant payable | One blended “TOTAL REVENUE” |

Month tiles: **Sales** \| **Gross profit** \| **Cash in** \| **AR due**. Optional fifth: **Merchant payable**. Caption: cash may exceed sales when courier remits reseller money.

### US-3: Reporting does not collect
- [ ] `create_billing_profile_payment_with_allocations` is **wallet**. Billing Balances page may stay; it is not a report.

---

## Month snapshot (target)

```text
Sales (issued bills)     Gross profit
Cash in (receipts)       AR due (bills)
Merchant payable (ledger)
```
