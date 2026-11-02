# Reporting & treasury — spec

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/reporting_treasury/spec.md` + [00-gaps](00-gaps.md) |
| UI | `reporting_treasury/`; pays in `cashbook/` / `payments/` |
| SQL | Report RPCs in `public.sql` |
| Access | `app`; parent books |
| Role | **Read** sales, cash, cashbook — do not post pays |

## Where to look

| Need | Path |
| :--- | :--- |
| Report RPCs | Grep `get_tenant_`, `report` in `public.sql` / types |
| Pages | `web/src/modules/reporting_treasury/pages/` |
| Collect (out of scope) | Payments / cashbook routes |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` |
| In | Five finance report views + CSV export; see [REPORTS_PLAN.md](../../../REPORTS_PLAN.md) |
| Out | Creating invoices; posting pays/remittance; editing shipments; invoice-line profit report; wallet liability report; courier COD report |

Money: [bills_pays spec](../bills_pays/spec.md). Numbers: [money-story](../bills_pays/money-story.md).

## Locked: money layers

| Layer | Source | Date filter |
| :--- | :--- | :--- |
| Sales | Issued **take** `total_amount`; **condition** when **paid** | Invoice / paid date |
| Gross profit | **Shipment P&L** (not invoice-line cost) | Shipment period |
| Cash in | Receipts | Receipt date |
| AR | Take `due_amount` firm; condition due not guaranteed | As-of |
| Payable | Cashbook splits | As-of |

Dropship: sales = merchant total, not COD face. Sales reports filter `invoice_type`.

## Stories

### US-1: Shipment P&L
- Invoice lines → lots → shipment; cost = landed + local ([procurement US-8](../procurement_stock/spec.md)).
- [ ] Local costs in P&L ([RT18](00-gaps.md)).

### US-2: Five finance views

| # | View | Question | Route |
| :--- | :--- | :--- | :--- |
| 1 | Shipment P&L | Batch payoff | `/app/finance/reports/shipment-profit` |
| 2 | Cash in | Bank/till receipts | `/app/finance/reports/cash-in` |
| 3 | Customer dues | Who owes bills | `/app/finance/reports/customer-dues` |
| 4 | Invoice book | Bills issued | `/app/finance/reports/invoice-book` |
| 5 | Money position | As-of buffer + month KPIs; drill to desks | `/app/finance/reports/month-snapshot` |

**Retired:** invoice/product profit, wallet liability, courier COD finance reports — see [REPORTS_PLAN.md](../../../REPORTS_PLAN.md).

### US-3: Reporting does not collect
- [x] Collect on Payments desk only; report routes read-only.
