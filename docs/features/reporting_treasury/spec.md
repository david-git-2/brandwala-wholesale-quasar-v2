# Reporting & treasury — spec

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/reporting_treasury/spec.md` + [00-gaps](00-gaps.md) |
| UI | `reporting_treasury/`; pays in `wallet/` |
| SQL | Report RPCs in `public.sql` |
| Access | `app`; parent books |
| Role | **Read** sales, cash, COD ops, cashbook — do not post pays |

## Where to look

| Need | Path |
| :--- | :--- |
| Report RPCs | Grep `get_tenant_`, `report` in `public.sql` / types |
| Pages | `web/src/modules/reporting_treasury/pages/` |
| Collect (out of scope) | `wallet/` Payments routes |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` |
| In | Eight report views + month snapshot; CSV export |
| Out | Creating invoices; posting pays/remittance; editing shipments; shadow P&L |

Money: [bills_pays spec](../bills_pays/spec.md). Numbers: [money-story](../bills_pays/money-story.md).

## Locked: money layers

| Layer | Source | Date filter |
| :--- | :--- | :--- |
| Sales | Issued **take** `total_amount`; **condition** when **paid** | Invoice / paid date |
| Gross profit | **Shipment P&L** (not invoice-line cost) | Shipment period |
| Cash in | Receipts | Receipt date |
| AR | Take `due_amount` firm; condition due not guaranteed | As-of |
| COD ops | Order COD vs remittance | Delivered / remitted |
| Payable | Cashbook splits | As-of |

Dropship: sales = merchant total, not COD face. Sales reports filter `invoice_type`.

## Stories

### US-1: Shipment P&L
- Invoice lines → lots → shipment; cost = landed + local ([procurement US-8](../procurement_stock/spec.md)).
- [ ] Local costs in P&L ([RT18](00-gaps.md)).
- [ ] No invoice-line COGS RPCs ([RT19](00-gaps.md)).

### US-2: Eight views

| # | View | Question |
| :--- | :--- | :--- |
| 1 | Invoice book | Bills issued |
| 2 | Invoice sales | Billed totals in period |
| 3 | Customer dues | Who owes bills |
| 4 | Cash in | Bank/till receipts |
| 5 | Courier COD | Face vs remitted |
| 6 | Cashbook liability | Merchant / customer / courier owed |
| 7 | Shipment P&L | Batch payoff |
| 8 | Month snapshot | Four tiles + optional merchant payable |

### US-3: Reporting does not collect
- [x] Collect on Payments desk only; report routes read-only.
