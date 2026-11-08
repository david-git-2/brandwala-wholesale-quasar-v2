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

### US-1: Shipment report
- List: all inbound shipments (`list_inbound_shipments_workspace`) at `/app/finance/reports/shipment-report`.
- Detail: admin checklist at `/app/finance/reports/shipment-report/:shipmentId` (no per-product item table):
  - **At a glance:** total cost, total sell, receive loss (BDT), profit/loss + margin %, unpaid customer total, warehouse value (BDT).
  - **Pieces:** should arrive, arrived, loss, stalled (held), remaining (sellable), sold.
  - **Exchange rates** when payments exist.
  - **Cost by type** (all AP kinds) + expandable supplier bills; correct currency symbols.
  - **Sell:** total + each **issued** invoice line (bill no, product, qty, BDT).
  - **Not paid yet:** customers with issued bills tied to this batch and open due &gt; 0.
  - Links to procurement shipment and bills when grants allow.
- Sell attribution: `bill_lines.shipment_item_id` when set (stamped on delivery-paper close via stock pick or product resolution); else `coalesce(gii.shipment_item_id, global_stocks.shipment_item_id, shipment line by product_id)`. **issued only** (not draft+paid).
- Delivery-paper take bills: `apply_delivery_paper_outcome` + `_insert_bill_line_from_compose_payload` set `shipment_item_id` and `line_meta.shipment_ref` `{ shipment_id, shipment_item_id }`.
- Receive loss = missing+damaged qty × `landed_cost_bdt`; profit = sell − total cost (loss shown, not subtracted twice).
- RPC: `get_tenant_shipment_report_detail` + aligned sales join in `get_tenant_shipment_profit_report`.
- Invoice lines → lots → shipment; cost = landed + local ([procurement US-8](../procurement_stock/spec.md)).
- [ ] Local costs in P&L ([RT18](00-gaps.md)).

### US-2: Five finance views

| # | View | Question | Route |
| :--- | :--- | :--- | :--- |
| 1 | Shipment report | Batch list + payoff detail | `/app/finance/reports/shipment-report` |
| 2 | Cash in | Bank/till receipts | `/app/finance/reports/cash-in` |
| 3 | Customer dues | Who owes bills | `/app/finance/reports/customer-dues` |
| 4 | Invoice book | Bills issued | `/app/finance/reports/invoice-book` |
| 5 | Money position | As-of buffer + month KPIs; drill to desks | `/app/finance/reports/month-snapshot` |

**Retired:** invoice/product profit, wallet liability, courier COD finance reports — see [REPORTS_PLAN.md](../../../REPORTS_PLAN.md).

### US-3: Reporting does not collect
- [x] Collect on Payments desk only; report routes read-only.
