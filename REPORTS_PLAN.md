# Reports plan

Product list for **parent-level finance reporting** (wholesale, procurement, dropship). Not Thrift, Koba, or product-based costing — those have their own report surfaces.

**Five reports.** Filters and drill-downs live on these pages — not 31 separate screens.

**Global rule:** every money report shows **billed**, **returned**, **collected cash**, **cashbook applied**, and **still due** as separate numbers. Do not mix them.

**Money story:** [docs/features/bills_pays/money-story.md](docs/features/bills_pays/money-story.md). **Gross profit = shipment P&L** (batch view), not invoice-line COGS. Shipment spend = procurement cost rows + AP bills on the batch.

**Status (2026-11):** routes, hub tiles, RPCs, and UI live under `/app/finance/reports/*`. Shipment profit is the primary margin report.

---

## The five reports

| # | Report | What it does (high level) | Route |
|---|--------|---------------------------|-------|
| 1 | **Shipment cost & profit** | Answers “was this import batch worth it?” One shipment as a mini P&L: landed cost, sold GP so far, unsold stock value, damage/shrink, and projected GP if the rest clears. | `/app/finance/reports/shipment-profit` |
| 2 | **Cash in** | Answers “what money hit the till?” Tenant **receipts** (cash, bank, remit) by day and method. Excludes cashbook apply-only movements and payouts. | `/app/finance/reports/cash-in` |
| 3 | **Customer dues** | Answers “who do I chase today?” Live snapshot of wholesale customers who owe, with aging buckets and credit-limit flags. One row per billing profile. | `/app/finance/reports/customer-dues` |
| 4 | **Invoice book** | Answers “what did we sell?” The sales ledger — invoices issued in a date range, with paid, due, returned, and settlement status per invoice. | `/app/finance/reports/invoice-book` |
| 5 | **Money position** | Answers “how did the month go?” Owner one-pager: net sales, GP, cash collected, AR outstanding, as-of position tiles (bank, courier holding, AP, cashbook credits). Drill-down to desks, not collect. | `/app/finance/reports/month-snapshot` |

---

## Retired (not finance hub reports)

| Former report | Why dropped | Where the need lives |
|---------------|-------------|----------------------|
| Invoice / product profit | GP authority is **shipment P&L**, not invoice-line COGS | Shipment profit (#1) |
| Wallet liability | Kernel uses **profile cashbook**, not a wallet report | Payments / cashbook desks |
| Courier COD | Dropship reconciliation is ops, not parent finance v1 | Courier remit desk; cash in (net remittance) |

Legacy URLs redirect to the reports hub or the relevant desk.

---

## Out of scope (this plan)

| Area | Where it lives instead |
|------|------------------------|
| Thrift sales / shipment / COD | `/app/thrift/reports` |
| Koba orders | Koba module (no finance report v1) |
| Product-based costing backlog | PBC module |
| Investor profit & capital yield | Investor portal + `/app/capital` (`get_investor_capital_report`) |
| Day-to-day ops | Invoice list, dropship desk, cashbook statement, dashboards |

**Skip as its own report:** aging, staff collections, write-offs, slow SKU, RTO. Put them as tabs or columns on reports 3 or 1.

---

## Build order

1. Shipment cost & profit (1)
2. Cash in (2)
3. Customer dues (3)
4. Invoice book (4)
5. Money position (5)

Shipment cost & profit is the **batch** view and the only margin authority for wholesale GP.

---

## Report 1 detail — shipment cost & profit

One import / batch is a mini business.

**Cost (all in):** product buy, freight, duty, local carry, packing, plus damage / missing / samples. Total ÷ sellable units = **true unit cost**. If 100 left China and 8 died, 92 carry the cost of 100.

**Profit as goods leave**

| Piece | Meaning |
|---|---|
| Landed cost | money stuck in this batch |
| Sold so far | qty × sell price (after returns) |
| Cost of sold | qty sold × true unit cost |
| Gross profit so far | sold money − cost of sold |
| Still in stock | unsold qty × true unit cost (not profit) |
| Lost | damage / shrink you will never get back |
| Expected if we sell the rest | planning number at current wholesale prices |

Three profit numbers, not one:

- **Realized** — only already sold (honest)
- **On paper** — realized + unsold at cost (cash not in yet)
- **Fully cleared** — GP if remaining stock sold at today’s wholesale price

Without those three, a new shipment looks unprofitable in week 1, or fake-rich if unsold stock is counted as profit.

Cuts on the same shipment: by SKU; later by customer; returns that hit this batch must drop GP.

List line: batch name | landed | sold $ | GP so far | unsold $ | lost $ | % of batch sold. Open batch → cost stack + sold vs remaining + SKU table.

Cash/dues stay separate. A shipment can be profitable and still leave you broke if customers have not paid.

---

## Nav homes (how the five sit together)

1. **Profit** — report 1 (shipment)
2. **Cash & dues** — reports 2, 3
3. **Sales** — report 4
4. **Owner snapshot** — report 5
