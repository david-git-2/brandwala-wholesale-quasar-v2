# Shipment inbound money (target)

Not as-built. Spec today: [procurement](../../docs/features/procurement_stock/spec.md) US-1 / US-8, [bills_pays](../../docs/features/bills_pays/spec.md) AP paper, [money-story inbound AP](../../docs/features/bills_pays/money-story.md).

## Jobs

| Object | Job | Not its job |
| :--- | :--- | :--- |
| Shipment + cost rows | What this inbound **cost** (goods, cargo-to-warehouse, VAT, local). Unit stamp + P&L | Who paid, which bank, leftover with a middleman |
| Bills + pays | Who we owe, who we paid, leftover, refund. Many pays, many rates | SKU qty, land splits, stock |

Shipment keeps **final costing amounts** (sums of cost rows). Payments keep **cash detail**. Do not put only a lump on the shipment and hide the split in pays. Do not record bank pays on the shipment.

## Why current fails

| Today | Breaks |
| :--- | :--- |
| Unique one AP bill per shipment per `ap_kind` (`vendor` / `cargo` / `local`) | Many pays at different FX blend into one rate |
| Header `product_conversion_rate` + `cargo_conversion_rate` typed manually | **Fixed (2026-10-10):** `refresh_global_shipment_fx_from_ap_payments` after AP payout; stamp uses material/freight BDT + header rates |
| Cost rows `payment_source` cash/credit/wallet + `pay_settle_shipment_costs` | Second cashbook next to pays |
| Duty folded into cargo AP; no VAT kind | Cannot split warehouse delivery vs refundable VAT |
| Outcome vendor credit vs unpaid AP vs VAT pay-in | Three “credits” mixed |

## Target rows

Each **cost event** is one `global_shipment_cost_entries` row (**bucket** × **component**, BDT `amount`, `is_capitalizable`). **One AP bill per cost bucket** (`ap_kind` = bucket name). Pays allocate to those bills via `pay_allocations`. Legacy `vendor` / `cargo` / `local` AP kinds voided on sync.

| Bucket (examples) | Unit stamp (`is_capitalizable`) | Cash |
| :--- | :--- | :--- |
| `material` (goods, warehouse delivery subtotal) | Yes | Pay out to vendor AP |
| `freight` (ocean/air) | Yes | Pay out to cargo AP |
| `customs` (`vat_tax` = CD/RD/AIT) | Usually **no** | Pay out; VAT pay-in when certificate returns |
| `handling` / `finance` | Per row flag | Pay out to local or finance AP |
| `other` (tips, repack, fines) | Yes if needed to receive goods; **no** if penalty | Local AP |

**Components:** `subtotal`, `carriage`, `vat_tax`, `misc` — see procurement spec US-1 matrix.

Header FX is **computed**, not stored. Material pays → product rate. Freight pays → cargo FX. Freight foreign ÷ kg → cargo rate. Transaction rate = money-weighted blend of those two pays only. Allocations on FX pays are **foreign**; Taka = foreign × `exchange_rate`. Stamp: SKU price × product rate + kg share × cargo FX. `post_ap_payout_with_allocations` restamps.

**Middleman float:** profile cashbook, not `payment_source = wallet` on the shipment. Pay middleman (leftover on profile) or pay vendor from their leftover.

**Vendor “pay later”:** AP bill stays `due`. Not a shipment settle. Not outcome credit.

**Outcome cheaper / missing qty:** `global_shipment_outcome_vendor_credits` — costing timing only. Cash still moves on bills/pays if money comes back.

**Do not:** delete cost rows and keep only a bill id on the shipment. **Do not** keep `pay_settle_shipment_costs` next to `post_ap_payout_with_allocations`.

---

## Worked example

Vendor-side **280** = goods **200** + VAT **50** + warehouse delivery **30**. Separate cargo **100**.

Pays: goods **200 @ 166**; **80 @ 168** (= VAT 50 + delivery 30); cargo **100 @ 169**. All paid. Later vendor confirms goods **180**; return **20** goods + **50** VAT (certificate). Delivery **30** and cargo **100** stay.

Foreign amounts. Taka = foreign × row rate.

### After first pay (think we bought 200)

**Shipment**

| Table | What |
| :--- | :--- |
| `global_shipments` | Display: goods 200, VAT 50, warehouse delivery 30, cargo 100 |
| `global_shipment_cost_entries` | Four rows below |

| Row | Type | Foreign | Rate | Taka | Stamp |
| :--- | :--- | :--- | :--- | :--- | :--- |
| P | product | 200 | 166 | 33,200 | Yes |
| V | vat *(kind not in code yet)* | 50 | 168 | 8,400 | No |
| D | warehouse delivery | 30 | 168 | 5,040 | Yes |
| C | cargo | 100 | 169 | 16,900 | Yes |

Do not stamp **280** on stock.

**Bills + pays**

| Table | What |
| :--- | :--- |
| `bills` | Four AP bills, one per cost row |
| `pays` + `pay_instruments` | Three pay-outs |
| `pay_allocations` | Pay → bill |
| `cashbook_entries` | Cash down |

| Pay | Foreign | Rate | Taka | Alloc |
| :--- | :--- | :--- | :--- | :--- |
| Source 1 | 200 | 166 | 33,200 | Bill P |
| Source 2 | 80 | 168 | 13,440 | Bill V 8,400 + Bill D 5,040 |
| Cargo | 100 | 169 | 16,900 | Bill C |

All four bills `paid`. Shipment does not store “paid from source 1”.

### After confirm 180 + VAT certificate

**Goods 180, not 200** — costing and cash

| Where | Change |
| :--- | :--- |
| Cost row P | 200 → **180** (or keep 200 + −20 row). Stamp uses 180 |
| AP bill P | Overpay 20 × 166 = **3,320** |
| `pays` | **Pay in** 3,320 (or vendor-profile leftover), alloc to bill P |
| `global_shipment_outcome_vendor_credits` | Only if landing-paper qty/price for P&L timing. Does not replace pay-in |
| Stock | Receive **180** |

**VAT 50 back** — cash only

| Where | Change |
| :--- | :--- |
| Cost row V | Stays 50; recoverable then settled. Still off stamp |
| AP bill V | **Pay in** 50 × 168 = **8,400**, alloc to bill V |
| `cashbook_entries` | Taka back to tenant (or middleman profile first) |

### Final picture

| Layer | Amounts |
| :--- | :--- |
| Stamp | Goods **180** @ 166 + delivery **30** @ 168 + cargo **100** @ 169 |
| Off stamp | VAT **50** @ 168, refunded |
| Pays | Three pay-outs; two pay-ins (20 goods + 50 VAT) |
| Net cash | ≈ (180×166) + (30×168) + (100×169). VAT and extra 20 wash |

Do not only note 20+50 on the shipment. Do not set shipment total to 210 and leave bills at 280 paid.

---

## Cost entry axes (done 2026-10-10)

`global_shipment_local_costs` dropped. P&L-only rows = `is_capitalizable = false` (often `other` + `misc`). `description` column + `metadata.description`. Migration: `20271010180000_global_shipment_cost_bucket_axes.sql`.

## Unit stamp (align 2026-10-10)

Cost rows are **Taka**. `currency_id` is the voucher currency. One AP bill per bucket is cash only — mixed currencies in a bucket still stamp as **sum of those Taka rows**, then one split. Do not invent a bucket FX for SKUs. Do not fold customs/handling/finance/other into `transaction_rate`.

Locked in [procurement US-1](../../docs/features/procurement_stock/spec.md):

| Bucket | On stock if flag on | Split |
| :--- | :--- | :--- |
| `material` | Line `purchase_price` (extras keep own price) | Not re-spread. Material `carriage` → goods **value**. |
| `freight` | Yes | Gross **kg** (fallback qty). Foreign share via `cargo_conversion_rate`. |
| `customs` | Usually VAT **off**; CD/RD **on** when flagged | **CIF Taka** (goods + freight share). |
| `handling` | Per row | **Qty**. |
| `finance` | Per row | **Goods Taka**. |
| `other` | Per row (repack on; fine off) | **Qty** when on. |

`section_id` set → pool and drivers only for that section’s lines.

**VAT leftover:** no special rule. Unrefunded VAT is stock only if that row is `is_capitalizable`. Else P&L ([US-8](../../docs/features/procurement_stock/spec.md)).

## Build order

1. **Done:** Cost rows = BDT amounts per bucket × component; capitalizable flag drives stamp.
2. **Done:** `sync_shipment_ap_bills` — one AP bill per bucket; migration `20271010190000`.
3. **Done:** Cash via Payments AP payout; legacy `pay_settle_shipment_costs` stubbed; settle columns dropped (`20271010210000`).
4. **Partial:** Stamp uses capitalizable `material` + `freight` BDT; freight by weight in **foreign** using `cargo_conversion_rate`; blended `transaction_rate` for goods+cargo only ([PS13](../../docs/features/procurement_stock/00-gaps.md)).
5. **Open:** Stamp remaining buckets per table above (`stamp_global_shipment_landed_costs`, `calculate_landed_unit_cost`, line-cost UI).
6. **Open:** AP pay-in for VAT/goods refund; middleman profile float UI; per-row AP (if ever needed).
