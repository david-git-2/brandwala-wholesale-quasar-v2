# Reports plan

Product list for **parent-level finance reporting** (wholesale, wallet, procurement, dropship). Not Thrift, Koba, or product-based costing — those have their own report surfaces.

**Eight reports.** Filters and drill-downs live on these pages — not 31 separate screens.

**Global rule:** every money report shows **billed**, **returned**, **collected cash**, **wallet applied**, and **still due** as separate numbers. Do not mix them.

**Status (2026-08):** routes and hub tiles exist under `/app/finance/reports/*`. Report pages are stubs. Only `get_tenant_cash_in_report` RPC exists today. Investor profit report lives in the investor portal (out of scope here).

---

## The eight reports

| # | Report | What it does (high level) | Route |
|---|--------|---------------------------|-------|
| 1 | **Cash in** | Answers “what money hit the till?” Shows tenant-wallet **credits only** (cash, bank, remit) by day and payment method. Excludes store-credit apply and payouts. | `/app/finance/reports/cash-in` |
| 2 | **Customer dues** | Answers “who do I chase today?” Live snapshot of wholesale customers who owe, with aging buckets and credit-limit flags. One row per billing profile. | `/app/finance/reports/customer-dues` |
| 3 | **Invoice book** | Answers “what did we sell?” The sales ledger — invoices issued in a date range, with paid, due, returned, and settlement status per invoice. | `/app/finance/reports/invoice-book` |
| 4 | **Invoice / product profit** | Answers “are we selling at a loss?” Sell price vs cost snapshot per invoice line and SKU, after returns. Invoice-level margin view. | `/app/finance/reports/invoice-profit` |
| 5 | **Shipment cost & profit** | Answers “was this import batch worth it?” One shipment as a mini P&L: landed cost, sold GP so far, unsold stock value, damage/shrink, and projected GP if the rest clears. | `/app/finance/reports/shipment-profit` |
| 6 | **Wallet** | Answers “how much store credit do we owe customers?” Credit issued in, applied on invoices, and outstanding liability. Wallet is a debt, not cash. | `/app/finance/reports/wallet` |
| 7 | **Courier COD** | Answers “did the courier remit what they collected?” Delivered COD vs bank deposits, short/over per courier batch. Only needed when dropship is active. | `/app/finance/reports/courier-cod` |
| 8 | **Month snapshot** | Answers “how did the month go?” Owner one-pager: net sales, cost, gross profit, cash collected, AR outstanding, wallet liability, stock still in shipments. | `/app/finance/reports/month-snapshot` |

### Spec deep-dives

- Report 1: [`doc/reporting_treasury/CASH_IN.md`](doc/reporting_treasury/CASH_IN.md)
- Report 2: [`doc/reporting_treasury/CUSTOMER_DUES.md`](doc/reporting_treasury/CUSTOMER_DUES.md)

---

## Out of scope (this plan)

| Area | Where it lives instead |
|------|------------------------|
| Thrift sales / shipment / COD | `/app/thrift/reports` |
| Koba orders | Koba module (no finance report v1) |
| Product-based costing backlog | PBC module |
| Investor profit & capital yield | Investor portal + `/app/capital` (`get_investor_capital_report`) |
| Day-to-day ops | Invoice list, dropship desk, wallet statement, dashboards |

**Skip as its own report:** aging, staff collections, write-offs, slow SKU, RTO. Put them as tabs or columns on reports 2, 5, or 7.

---

## Build order

1. Customer dues (2)
2. Cash in (1)
3. Shipment cost & profit (5)
4. Invoice / product profit (4)
5. Invoice book (3)
6. Wallet (6)
7. Courier COD (7) — if dropship
8. Month snapshot (8)

Shipment cost & profit (5) is the **batch** view. Invoice / product profit (4) is the **sale** view. Need both.

---

## Report 5 detail — shipment cost & profit

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

## Nav homes (how the eight sit together)

1. **Cash & dues** — reports 1, 2, 6
2. **Sales** — report 3
3. **Profit** — reports 4, 5
4. **Courier** — report 7 (dropship only)
5. **Owner snapshot** — report 8
