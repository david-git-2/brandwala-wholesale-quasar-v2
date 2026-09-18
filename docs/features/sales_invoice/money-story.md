# Invoice → payment (worked example)

Same SKU. Landed **cost 1,000 BDT** (internal snapshot only; not on the bill). Use these numbers when wiring invoice, receipts, dropship, or reports.

Target rules: [sales_invoice 01](01-prd.md), [wallet 01](../wallet/01-prd.md). Code may still differ: [sales_invoice gaps](00-gaps.md), [wallet gaps](../wallet/00-gaps.md).

Same bill table. **Two desks. Do not mix.**

| Step | Wholesale | Dropship |
| :--- | :--- | :--- |
| Who is billed | Buyer `billing_profile` | Reseller `billing_profile` |
| Stock | FIFO sellable on **Issue** (`create_sales_invoice_from_payload`) | Held **picks**, then issue on **Mark as shipped** |
| Bill RPC | Invoice desk payload RPC | Order RPC `ship_dropship_order_and_issue_merchant_bill` → `issue_dropship_tenant_b2b_invoice` |
| `collection_source` | `billing_profile` | `billing_profile` (COD is not this) |
| Parcel | Optional on the invoice | `shop_orders` status only |
| Cash-in | Collect on invoice detail | Courier remittance after `delivered` |
| Receipt amount | What the buyer paid (usually = bill) | **Net bank in**, not COD face |
| Allocate | Up to wholesale `total_amount` | Up to merchant `total_amount` |
| Leftover | Unallocated / store credit | Merchant wallet, then payout |
| Not a bill | — | Packing slip / COD face |
| Catalog shop order | `fulfill_shop_order_to_invoice` (not dropship) | Never that RPC |

---

## Wholesale — `INV-WS-001`

Buyer **ABC Traders**. Sell **1,500**. They pay you. No COD.

| Step | What | Numbers |
| :--- | :--- | :--- |
| Issue bill | Invoice desk. `invoice_type=wholesale`, billed to ABC. Deduct sellable stock. | `sell` 1,500 → `total_amount` **1,500**. `issued` / `due`. Cost 1,000 hidden. |
| Print | Voucher | Qty, 1,500. No cost. No COD. |
| Parcel | Optional fulfillment on this invoice | Not a shop_order dropship stage |
| Receipt | Collect dialog. `source=bank` (or cash / store credit) | **1,500**. Buyer `billing_profile` |
| Allocate | To `INV-WS-001` | 1,500 → `paid`. No merchant leftover |
| Ledger | Tenant cash | **+1,500** |
| Sales report | Issued total | **1,500** (margin 500) |

One line: billed 1,500, they paid 1,500.

---

## Dropship — order + `INV-DS-001`

Reseller **Glamour Closet**. Merchant price **1,500**. Recipient **Karim** COD **2,200**. Courier fee **80**. Bank from courier **2,120**.

| Step | What | Numbers |
| :--- | :--- | :--- |
| Order | Pick / ship. Packing slip for Karim | Collect **2,200**. **Not** a `sales_invoices` row. COD/resell on order (and invoice `channel_meta`). |
| Issue bill | Same **Mark as shipped** RPC as the order. Lines = held picks. `invoice_type=dropship`, billed to Glamour | `sell` 1,500 (merchant price) → `total_amount` **1,500**. `issued` / `due`. Not 2,200. |
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
| Dropship issue from wholesale create page | Dropship: ship RPC on the order |
| Wholesale issue from dropship ship | Wholesale: invoice desk payload RPC |
| Invoice total = 2,200 COD | Invoice total = 1,500 tenant sell |
| Wholesale collect uses remittance RPC | Wholesale: `create_billing_profile_payment_with_allocations` |
| Receipt amount = 2,200 face | Dropship receipt = 2,120 remitted |
| Sales = remittance or COD | Sales = issued `total_amount` (both channels) |
| Cost on print | Cost on `sales_invoice_item_costs` |
| Deliver posts cash | Deliver = parcel; remittance = receipt |
| Second payments product for dropship | Same receipt table; `source` differs |
