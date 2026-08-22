# Reports plan (later)

Not implementation. Product list only. Work this later; do not treat as current app inventory.

Rule for every money report: show **billed**, **returned**, **collected cash**, **wallet applied**, and **still due** as separate numbers. Do not mix them.

These are questions with numbers, not 31 pages. **Eight reports.** Filters and drill-downs live on these pages.

| # | Report | What you see | Why it exists |
|---|---|---|---|
| 1 | **Cash in** | Money that arrived (cash / bank / wallet apply), by day and method | Know what hit the till |
| 2 | **Customer dues** | Who owes, how old, credit limit | Chase list |
| 3 | **Invoice book** | Invoices issued, paid, due, returned | The sales record |
| 4 | **Invoice / product profit** | Sell vs cost, after returns, by invoice and SKU | Catch selling at a loss |
| 5 | **Shipment cost & profit** | One batch: landed cost, sold, GP so far, unsold value, damage, “if we clear the rest” | Was this container worth it |
| 6 | **Wallet** | Credit in, applied out, still owed to customers | Wallet is a debt, not cash |
| 7 | **Courier COD** | Delivered vs remitted, short/over | Only if you use couriers |
| 8 | **Month snapshot** | Net sales, cost, GP, cash collected, AR, wallet liability, stock in shipments | Owner / investor one-pager |

Skip as its own report: aging, staff collections, write-offs, slow SKU, RTO. Put them as tabs or columns on 2, 5, or 7.

**Build order**

- First: 2, 1, 5, 4
- Next: 3, 6
- If dropship: 7
- Last: 8

Shipment cost & profit (5) is the batch view. Invoice / product profit (4) is the sale view. Need both.

---

## Shipment cost & profit (report 5)

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

## Homes (how the eight sit together)

1. **Cash & dues** — reports 1, 2, 6
2. **Sales** — report 3
3. **Profit** — reports 4, 5
4. **Courier** — report 7 (only if COD dropship)
5. **Owner snapshot** — report 8
