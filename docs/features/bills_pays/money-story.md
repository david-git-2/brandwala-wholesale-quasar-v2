# Bill → pay (worked example)

Same SKU. Shipment cost stays on the **shipment**. GP = [shipment P&L](../reporting_treasury/spec.md).

Layers: **profile · bill · pay · alloc · cashbook**. Not a wallet. Rename map: [spec](spec.md#rename-map-spec--live).

Same `bills` table. **Different paper.** Do not mix desks. Delivery paper **proforma** is not issued.

| Step | Wholesale | Dropship |
| :--- | :--- | :--- |
| Who (profile) | Buyer | Shop |
| Issued bill | Take and/or condition (compose or paper) | Merchant bill at ship |
| Pay in | Collect | Courier remittance after `delivered` |
| Pay amount | What they handed you | **Net bank in**, not COD face |
| Leftover | Customer cashbook | Shop cashbook, then pay out |
| Not a bill | Delivery paper / proforma | Packing slip / COD face |

---

## Wholesale take — `INV-WS-001`

Buyer **ABC**. Sell **1,500**. Pay **1,500** cash.

| Layer | Store |
| :--- | :--- |
| PROFILE | ABC |
| BILL | Take issued / due 1,500 |
| PAY + ALLOC | 1,500 → bill paid |
| CASHBOOK | Tenant cash +1,500 |

Sales **1,500**. GP = shipment P&L.

**Overpay 2,000:** ALLOC 1,500; customer cashbook **+500**. No second bill. Next take: apply leftover via pay in.

---

## Dropship merchant — `INV-DS-001`

Shop **Glamour Closet** **1,500**. Karim COD **2,200**. Courier fee **80**. Bank **2,120**.

| Layer | Store |
| :--- | :--- |
| PROFILE | Shop |
| BILL | Merchant 1,500 issued / due. Not 2,200 |
| CASHBOOK (deliver) | Courier +2,200. Not tenant cash. Not sales |
| PAY | Remittance 2,120 |
| ALLOC | 1,500 on merchant bill |
| CASHBOOK | Shop leftover **+620**; tenant +2,120; courier down |
| PAY out later | Shop 620. Cashbook only. No ALLOC |

**Month both deals:** sales **3,000** · cash in **3,620** · we-owe shop **620**.

---

## Inbound shipment AP — `INV-AP-20261004-0001`

Shipment **S-42**. Vendor goods **80,000**. Cargo+duty **12,000**. Local opex **3,000**.

| Layer | Store |
| :--- | :--- |
| PROCUREMENT | Cost rows on shipment (not customer sales) |
| BILL ×3 | AP issued / due per kind (`vendor`, `cargo`, `local`); sync when costs change while unpaid |
| PAY out | Bank **95,000** with ALLOC across the three AP bills → all `paid` |
| CASHBOOK | Tenant cash **−95,000** (not Collect) |

Vendor **outcome credit** (cheaper price) still adjusts costing only until sold — not folded into these AP headers.

## Vendor credit (outcomes)

Better price on shipment **outcomes** = costing timing. Not a take bill. AP headers follow **product cost entries** / header purchase total.

---

## Do not

| Wrong | Right |
| :--- | :--- |
| Wallet / credit invoice | Cashbook on profile |
| Delivery paper create = issued bill | Optional proforma; close dropdown take / condition / return |
| Condition only from Delivery | Trade compose can issue condition too; walk-in cannot |
| Invoice total = COD | Tenant sell / merchant sell |
| Deliver posts tenant cash | Remittance is tenant cash |
| Second pay product for dropship | Same `pays`; `source` differs |
| Unpaid condition as sales | Sales = issued **take** + **paid** condition |
| Vendor credit on buyer bill | Outcomes now; AP later |
