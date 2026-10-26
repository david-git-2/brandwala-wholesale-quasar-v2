# Bill → pay (worked example)

Same SKU. Shipment cost stays on the **shipment**. GP = [shipment P&L](../reporting_treasury/spec.md).

Layers: **profile · bill · pay · alloc · cashbook**. Not a wallet. Rename map: [spec](spec.md#rename-map-spec--live). Golden row-level scenarios: [06-ACCOUNTING-FLOWS-AND-GOLDEN-SCENARIOS](../../kernel/06-ACCOUNTING-FLOWS-AND-GOLDEN-SCENARIOS.md).

Same `bills` table. **Different paper.** Stock lines optional (header/AP/service bills still issue and pay). Delivery paper **proforma** is not issued. Pays: receive or pay out from instruments or cashbook (profile leftover = custody).

| Step | Wholesale | Dropship |
| :--- | :--- | :--- |
| Who (profile) | Buyer | Dropshipper (customer) |
| Issued bill | Take and/or condition (compose or paper) | Customer invoice + courier AP issued at ship |
| Pay in | Collect | Courier remittance after `delivered` |
| Pay amount | What they handed you | **Net bank in**, not COD face |
| Leftover | Customer cashbook | Dropshipper cashbook, then pay out |
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

**Overpay 2,000:** ALLOC 1,500; customer cashbook **+500**. No second bill. Next take: apply leftover via pay in, or open the pay and attach leftover to bills (oldest first).

---

## Dropship merchant — `INV-DS-001`

Dropshipper **Glamour Closet** **1,500**. Recipient Karim COD **2,200**. Courier fee **80**. Bank **2,120**.

| Layer | Store |
| :--- | :--- |
| PROFILE | Dropshipper |
| BILL | Customer invoice 1,500 issued / due at ship. Not 2,200 |
| BILL | Courier AP (we owe) issued at ship (fee e.g. 80). Later change = note |
| CASHBOOK (deliver) | Courier +2,200. Not tenant cash. Not sales |
| PAY | Remittance 2,120 |
| ALLOC | 1,500 on customer invoice |
| CASHBOOK | Dropshipper leftover **+620**; supplier tenant +2,120; courier down |
| PAY out later | Dropshipper 620. Cashbook only. No ALLOC. Remittance does not mark payout paid until dispense. |

**Month both deals:** sales **3,000** · cash in **3,620** · we-owe dropshipper **620**.

**Dropship gifts:** recipient COD unchanged. Warehouse gift cost charged to **dropshipper** increases customer invoice at ship (like margin deductions). Charged to **supplier (tenant)** does not change customer invoice. Customer-stock gifts have no money line.

---

## Inbound shipment AP — `INV-AP-20261004-0001`

Shipment **S-42**. Vendor goods **80,000**. Cargo+duty **12,000**. Local opex **3,000**.

| Layer | Store |
| :--- | :--- |
| PROCUREMENT | Cost rows on shipment (not customer sales) |
| BILL ×3 | AP issued / due per kind (`vendor`, `cargo`, `local`); sync when costs change while unpaid |
| PAY out | Bank **95,000** with ALLOC across the three AP bills → all `paid` |
| CASHBOOK | Tenant cash **−95,000** (not Collect) |

Vendor **outcome qty** still adjusts costing until sold. Commercial short/VAT after issue = **credit note** on that AP bill (same `bills` table), then pay in / leftover. Do not rewrite the issued total.

**What prints (snapshot on each AP bill):**

| Kind | Fields on paper |
| :--- | :--- |
| Vendor | Foreign amount · FX rate · **BDT** total |
| Cargo | Weight (kg) · foreign price · FX rate · **BDT** total |
| Local | Line list: description · amount (BDT) |

## Vendor credit (outcomes)

Better price on shipment **outcomes** = costing timing. Not a take bill. AP headers follow **product cost entries** / header purchase total.

---

## Do not

| Wrong | Right |
| :--- | :--- |
| Wallet / credit invoice | Cashbook on profile |
| Delivery paper create = issued bill | Optional proforma; close dropdown take / condition / return |
| Condition only from Delivery | Trade compose can issue condition too; walk-in cannot |
| Invoice total = COD | Supplier sell / B2B to dropshipper |
| Deliver posts tenant cash | Remittance is tenant cash |
| Second pay product for dropship | Same `pays`; `source` differs |
| Unpaid condition as sales | Sales = issued **take** + **paid** condition |
| Vendor credit on buyer bill | Outcomes = qty/costing; AP money = credit note on the AP bill |
