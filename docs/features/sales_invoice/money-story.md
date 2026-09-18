# Invoice → payment (worked example)

Same SKU. Landed **cost 1,000 BDT** (internal snapshot only; not on the bill). Use these numbers when wiring invoice, receipts, dropship, or reports.

Target rules: [sales_invoice 01](01-prd.md), [wallet 01](../wallet/01-prd.md). Code may still differ: [sales_invoice gaps](00-gaps.md), [wallet gaps](../wallet/00-gaps.md).

---

## Wholesale — `INV-WS-001`

Buyer **ABC Traders**. Sell **1,500**. They pay you. No COD.

| Step | What | Numbers |
| :--- | :--- | :--- |
| Issue bill | `invoice_type=wholesale`, billed to ABC | `sell` 1,500 → `total_amount` **1,500**. `issued` / `due`. Cost 1,000 hidden. |
| Print | Voucher | Qty, 1,500. No cost. |
| Parcel | From this invoice | — |
| Receipt | `source=bank` | **1,500** |
| Allocate | To `INV-WS-001` | 1,500 → `paid` |
| Ledger | Tenant cash | **+1,500** |
| Sales report | Issued total | **1,500** (margin 500) |

One line: billed 1,500, they paid 1,500.

---

## Dropship — order + `INV-DS-001`

Reseller **Glamour Closet**. Merchant price **1,500**. Recipient **Karim** COD **2,200**. Courier fee **80**. Bank from courier **2,120**.

| Step | What | Numbers |
| :--- | :--- | :--- |
| Order | Pick / ship. Packing slip for Karim | Collect **2,200**. **Not** a `sales_invoices` row. COD/resell on order (and invoice `channel_meta`). |
| Issue bill | At ready/ship. `invoice_type=dropship`, billed to Glamour | `sell` 1,500 (merchant price) → `total_amount` **1,500**. `issued` / `due`. Not 2,200. |
| Print merchant | Invoice voucher | 1,500. No cost. No COD as total. |
| Deliver | Order status only | No cash. Invoice may still be `due`. |
| Receipt | `source=courier_remittance` | **2,120** (net, not COD face) |
| Allocate | To `INV-DS-001` | **1,500** → invoice `paid` |
| Remainder | Ledger merchant payable | **620** Glamour wallet |
| Tenant cash | Receipt | **+2,120** |
| Sales report | Issued total | **1,500** (margin 500). Not 2,200 or 2,120. |
| Payout later | Money out | Glamour withdraws 620. Not a receipt. |

**Reports (both deals in one month):** sales **3,000** · GP **1,000** · cash in **3,620** · AR **0** (if both bills paid) · merchant payable **620**. See [reporting 01](../reporting_treasury/01-prd.md).

One line: billed reseller 1,500; Karim paid courier 2,200; you received 2,120; 1,500 settled the bill; 620 is theirs.

---

## Do not

| Wrong | Right |
| :--- | :--- |
| Invoice total = 2,200 COD | Invoice total = 1,500 tenant sell |
| Receipt amount = 2,200 face | Receipt = 2,120 remitted |
| Sales = remittance or COD | Sales = issued `total_amount` |
| Cost on print | Cost on `sales_invoice_item_costs` |
| Deliver posts cash | Deliver = parcel; remittance = receipt |
| Second payments product for dropship | Same receipt table; `source` differs |
