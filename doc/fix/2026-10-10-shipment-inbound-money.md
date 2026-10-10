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
| Header `product_conversion_rate` + `cargo_conversion_rate` | Unit stamp ignores per-pay FX |
| Cost rows `payment_source` cash/credit/wallet + `pay_settle_shipment_costs` | Second cashbook next to pays |
| Duty folded into cargo AP; no VAT kind | Cannot split warehouse delivery vs refundable VAT |
| Outcome vendor credit vs unpaid AP vs VAT pay-in | Three “credits” mixed |

## Target rows

Each **cost event** is one `global_shipment_cost_entries` row (type, foreign amount, **that row’s** FX, payee). Each row owns **one AP bill**. Pays allocate to those bills. Drop one-bill-per-kind. Link `ap_shipment_id` + `cost_entry_id`.

| Cost type | Unit stamp | Cash |
| :--- | :--- | :--- |
| Product (goods) | Yes | Pay out to vendor AP |
| Warehouse delivery (company charge to foreign warehouse) | Yes | Pay out (vendor or cargo payee) |
| Cargo (separate cargo invoice) | Yes | Pay out to cargo AP |
| VAT | **No** | Pay out; later pay **in** when certificate returns it |
| Local opex | **No** (P&L only, spec US-8) | Pay out to local AP |

Header FX = display average of those rows.

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

## Local costs table (done 2026-10-10)

`global_shipment_local_costs` dropped. Local opex = `global_shipment_cost_entries` with `cost_type = local`; description in `metadata.description`. Migration: `20271010160000_drop_global_shipment_local_costs.sql`.

## Build order

1. Cost row = source of truth (type, foreign, row FX, payee). Header FX = average.
2. Sync one AP bill per cost row. Remove one-bill-per-kind unique.
3. All cash through Payments: pay out AP, pay in VAT/goods refund, leftover on middleman profile.
4. Stamp = product + warehouse delivery + cargo. Local + VAT off stamp.
5. Stop using settle columns and shipment wallet/credit flags.

## Open (write into spec before code)

When VAT is not fully refunded (fee, delay, never): leftover in **unit cost**, or always **P&L only** like local cost?
