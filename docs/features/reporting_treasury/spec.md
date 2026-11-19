# Reporting & treasury — spec

## Status

| | |
| :--- | :--- |
| **Draft (2026-11)** | Shipment P&amp;L + investor block on shipment detail; money_kernel layers below |
| **As-built** | Five hub reports under `/app/finance/reports/*`; shipment hub route `shipment-report` (legacy `shipment-profit` redirects) |
| **Money** | [bridge § Atlas](../money_bill_bridge/spec.md#atlas); report books in **BDT** (`books_amount` on pays / lines) |

Parent-level finance only (wholesale, procurement, dropship). Thrift `/app/thrift/reports`, Koba, PBC own their surfaces.

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/reporting_treasury/spec.md` + [00-gaps](00-gaps.md) |
| UI | `reporting_treasury/`; pays in `cashbook/` / `payments/` |
| SQL | Report RPCs in `supabase/schemas/` (e.g. `public.sql`, domain splits) |
| Access | `app`; parent books |
| Role | **Read** sales, cash, cashbook — do not post pays |

## Where to look

| Need | Path |
| :--- | :--- |
| Report RPCs | Grep `get_tenant_`, `report` in schemas / types |
| Shipment detail / list | `get_tenant_shipment_report_detail`, `get_tenant_shipment_profit_report` |
| Investor on batch | Grep `shipment_investments` in schemas; staff `investor_capital/` |
| Pages | `web/src/modules/reporting_treasury/pages/` |
| Collect (out of scope) | Payments / cashbook routes |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` |
| In | Five finance report views + CSV export; shipment batch P&amp;L; **draft** investor rows on shipment detail |
| Out | Posting pays/bills; editing shipments; invoice-line profit; wallet liability hub; courier COD hub; partner portal UX ([investor_capital](../investor_capital/spec.md)) |

**Global rule:** show **billed**, **returned**, **collected cash**, **cashbook applied**, and **still due** as separate numbers — do not mix them on one KPI.

**Out of scope (other modules):** investor capital yield / portal profit list → `get_investor_capital_report` + `/app/capital`; aging, write-offs, slow SKU → columns on customer dues or shipment, not new hub reports.

## Locked: money layers (money_kernel)

| Layer | Source | Date filter |
| :--- | :--- | :--- |
| Sales | Issued **take** bill `total_amount`; **condition** when **paid** | Issue / paid date |
| Gross profit | **Shipment P&amp;L** (not invoice-line COGS) | Batch period |
| Cash in | Receipt pays (`kind` deposit / inflow) | Receipt date |
| AR | Take bill `due_amount`; condition due not guaranteed | As-of |
| Payable | AP bills + cashbook | As-of |

Dropship: sales = merchant total, not COD face — filter `invoice_type` on sales reports.

## Draft: shipment P&amp;L numbers

| Number | Meaning | Source idea |
| :--- | :--- | :--- |
| Total cost | Landed + AP on batch | Procurement cost rows + AP bills / `shipment_id` |
| Sold qty / sell BDT | Issued take lines on batch | `money_kernel.bill_lines` (`shipment_item_id` / `shipment_id` / `global_stock_id`) |
| Receive loss | Missing/damaged × unit cost | Loss qty × `landed_cost_bdt` |
| Gross profit | Sell − total cost (loss shown, not subtracted twice) | US-1 KPI |
| Unpaid on batch | Open due on issued bills tied to batch | Bills `due_amount` |
| Warehouse value | Remaining sellable × cost | Stock on shipment |
| Investor capital in | Per partner on batch | `shipment_investments` |
| Investor share of GP | Shipment GP × `cost_share_pct` (sum ≤ 100% per shipment) | [investor rules](../investor_capital/spec.md) |

**Three profit labels (planning, draft):**

| Label | Meaning |
| :--- | :--- |
| Realized | GP on qty already sold |
| On paper | Realized + unsold at cost (cash not in yet) |
| Fully cleared | GP if remaining stock sold at current wholesale price |

As-built detail KPI strip shows cost / sell / profit; extended three-way split is not built until product asks.

## Retired finance hub reports

| Former | Why | Where instead |
| :--- | :--- | :--- |
| Invoice / product profit | GP authority = shipment P&amp;L | Shipment report (#1) |
| Wallet liability | Profile cashbook, not a report | Cashbook / payments desks |
| Courier COD | Ops / dropship desk | Cash in (net remittance) |
| Customer dues | Replaced by Customers browse + detail | `/app/finance/reports/customers` (legacy `customer-dues` redirects) |

Legacy URLs redirect to hub or desks.

## Nav homes (five reports)

| Hub group | Reports |
| :--- | :--- |
| Profit | Shipment report |
| Cash &amp; dues | Cash in, customers |
| Sales | Invoice book |
| Owner snapshot | Money position |

Build order was shipment → cash in → customers → invoice book → month snapshot. Shipment is the **only** wholesale GP authority.

## Stories

### US-1: Shipment report
- List: `list_inbound_shipments_workspace` at `/app/finance/reports/shipment-report`.
- Detail UI (story order): **Profit &amp; loss (hero)** → **Shipment** (meta) → **Pieces** (qty + optional SKU table) → **Cost in** (FX rates + AP bills + cost by type) → **Sales out** (customer rollup, product lines, still owed when due &gt; 0).
- Detail route: `/app/finance/reports/shipment-report/:shipmentId` — same data as RPC; plain English sections; links to procurement / bills when grants allow.
- Sell attribution: `bill_lines.shipment_item_id` when set; else coalesce stock / shipment line by `product_id`. **Issued only**.
- RPC: `get_tenant_shipment_report_detail` + `get_tenant_shipment_profit_report`.
- [ ] Local non-capitalizable costs in P&amp;L ([RT18](00-gaps.md)).
- [ ] **Draft:** investor capital + share-of-GP block on detail ([RT20](00-gaps.md)).

### US-2: Five finance views

| # | View | Question | Route |
| :--- | :--- | :--- | :--- |
| 1 | Shipment report | Was this batch worth it? | `/app/finance/reports/shipment-report` |
| 2 | Cash in | What hit the till? | `/app/finance/reports/cash-in` |
| 3 | Customers | Who bought, paid, and owes? | `/app/finance/reports/customers` |
| 4 | Invoice book | What did we sell? | `/app/finance/reports/invoice-book` |
| 5 | Money position | How did the month go? | `/app/finance/reports/month-snapshot` |

### US-5: Customers report (replaces Customer dues)
- List: `/app/finance/reports/customers` — cursor search over customer groups; KPI columns `still_due`, store credit.
- Detail: `/app/finance/reports/customers/:customerGroupId` — header once; long lists via cursor sections (do not bundle all history in one RPC).
- RPCs (`reporting_treasury` view grant):
  - `list_customers_report(p_tenant_id, p_search, p_limit, p_cursor)` → `{ items, next_cursor }`
  - `get_customer_report_header(p_tenant_id, p_customer_group_id)` → identity, members, shop access, money KPIs only
  - `list_customer_report_section(p_tenant_id, p_customer_group_id, p_kind, p_limit, p_cursor)` — `p_kind` ∈ `payments` | `orders` | `bills` | `ledger`
- Read-only; same money separation as other reports (billed / cash / wallet / still due).
- `get_customer_dues_report` remains in DB but **retired** from hub UI (no replacement aging hub).

### US-3: Reporting does not collect
- [x] Collect on Payments desk only; report routes read-only.

### US-4: Investor on shipment (draft)
- Staff shipment detail shows `shipment_investments` rows and profit share vs shipment GP.
- Cashbook truth for investor in/out stays [investor_capital](../investor_capital/spec.md); no duplicate ledger report here.
- [ ] Not built ([RT20](00-gaps.md)).
