# Return, Loss & Damage Scenarios

Bangladesh COD + courier model. Same physical events can hit wholesale and dropship; **who pays** and **how money moves** differ by channel.

| | Wholesale | Dropship |
|---|---|---|
| **Buyer** | Wholesale customer (shop / retailer) | Dropshipper (reseller / merchant) |
| **End receiver** | Usually the buyer (warehouse / shop) | Dropshipper’s end customer |
| **Product bill** | Supplier invoices buyer | Supplier bills dropshipper (cost / AP) |
| **COD** | Optional; if used, remits against buyer invoice / delivery | Courier collects from end customer → remits to supplier |
| **Return money** | Credit note / invoice return | Settlement + return charges; remittance / courier AR |
| **Existing hooks** | `process_wholesale_invoice_return` | `finalize_dropship_return`, `mark_dropship_order_returned`, remittance RPCs |

**Shared fault parties:** `customer` · `buyer_or_dropshipper` · `supplier` · `courier` · `fraud_dispute`

**Shared parcel conditions:** `sellable` · `damaged_transit` · `damaged_customer` · `wrong_sku` · `empty_pilfered` · `missing` · `switched`

**Shared decision fields (per case):**

1. `channel` — `wholesale` | `dropship`
2. `scenario_code` — e.g. `WS-1A`, `DS-3B`
3. `fault_party`
4. `parcel_condition`
5. `cod_state` — `none` | `not_collected` | `collected` | `mismatch` | `disputed`
6. `product_charge` — `charge` | `credit` | `waive` | `hold_claim`
7. `logistics_charge` — who + forward / return / packing / restock / penalty
8. `claim_status` — `none` | `open` | `accepted` | `rejected`
9. `aging_cutoff` — e.g. 21 days → treat as lost

---

## Part 1 — Wholesale

**Money model:** B2B invoice to buyer. Return → credit note / partial line return. Courier COD (if any) settles against buyer AR. Buyer owns address quality and most “change of mind” cost.

### 1. Refusal / undelivered (to buyer or buyer site)

#### WS-1A — Standard refusal (box intact)

| Field | Value |
|---|---|
| **Trigger** | Buyer cancels at door, unreachable, wrong address; parcel returns unopened / sellable |
| **Parcel condition** | `sellable` |
| **Fault** | `buyer_or_dropshipper` (buyer) |
| **Product / invoice** | Credit note + restock when warehouse receives OK |
| **Logistics** | Buyer pays forward + return (+ packing/restock if policy) |
| **COD** | None collected → no COD remittance; if advance paid, refund/adjust AR |
| **Ops** | Mark delivery failed → await physical return → QC → CN |

#### WS-1B — Partial delivery / partial return

| Field | Value |
|---|---|
| **Trigger** | Multi-line shipment; buyer accepts some lines, returns others |
| **Parcel condition** | Mix: accepted kept; returned `sellable` or damaged |
| **Fault** | Usually `buyer_or_dropshipper`; per-line if supplier wrong |
| **Product / invoice** | Keep AR for accepted lines; CN for returned lines after QC |
| **Logistics** | Return courier fees on returned qty per contract |
| **COD** | Collect only for accepted value (if COD used) |
| **Ops** | Line-level return (`process_wholesale_invoice_return` style) |

#### WS-1C — Fake / unreachable consignee (buyer-given address)

| Field | Value |
|---|---|
| **Trigger** | Non-existent / unreachable receiver on address buyer provided; box returns unopened |
| **Parcel condition** | `sellable` (if returned) |
| **Fault** | `buyer_or_dropshipper` |
| **Product / invoice** | CN if returned and restocked; else dispute / hold |
| **Logistics** | Buyer: full forward + return + penalty |
| **COD** | Not collected |
| **Ops** | Flag buyer risk; optional block on high fail rate |

### 2. Post-delivery return / exchange

#### WS-2A — Size / color / variant exchange

| Field | Value |
|---|---|
| **Trigger** | Buyer wants different variant after receipt |
| **Parcel condition** | Inbound return `sellable`; new outbound fresh |
| **Fault** | `buyer_or_dropshipper` (unless supplier shipped wrong — then WS-2C) |
| **Product / invoice** | Swap, or CN + new invoice for replacement |
| **Logistics** | Buyer pays reverse + new forward (unless contract says else) |
| **COD** | If replacement COD, collect new amount; settle old if already paid |
| **Ops** | Link exchange order to original return |

#### WS-2B — Change of mind / overstock return

| Field | Value |
|---|---|
| **Trigger** | Buyer received intact goods, paid (or on credit), wants refund / credit |
| **Parcel condition** | `sellable` |
| **Fault** | `buyer_or_dropshipper` |
| **Product / invoice** | CN only inside return window + policy |
| **Logistics** | Buyer: return freight + restock / handling % |
| **COD** | If COD already remitted, reverse via CN / cash refund path |
| **Ops** | Enforce window, seals, unused condition |

#### WS-2C — Defective / wrong item (supplier fault)

| Field | Value |
|---|---|
| **Trigger** | Wrong SKU packed or factory defect |
| **Parcel condition** | `wrong_sku` or defective |
| **Fault** | `supplier` |
| **Product / invoice** | Full CN + optional replacement at no charge |
| **Logistics** | Supplier absorbs return / exchange courier |
| **COD** | Refund or replace; no restock fee to buyer |
| **Ops** | No penalty to buyer; QA feedback to pack |

### 3. Product damage

#### WS-3A — Transit damage (courier fault)

| Field | Value |
|---|---|
| **Trigger** | Outer box crushed, wet, broken in courier handling |
| **Parcel condition** | `damaged_transit` |
| **Fault** | `courier` |
| **Product / invoice** | Hold AR / issue CN after claim accepted |
| **Logistics** | Courier claim covers product (declared / invoice value) |
| **COD** | Do not treat as buyer debt for damaged goods |
| **Ops** | Photos + AWB + claim ticket before final money |

#### WS-3B — Buyer / receiver inflicted damage

| Field | Value |
|---|---|
| **Trigger** | Opened, used, seals/tags broken; forces return |
| **Parcel condition** | `damaged_customer` / unsellable |
| **Fault** | `buyer_or_dropshipper` |
| **Product / invoice** | No CN (or negotiated partial only) |
| **Logistics** | Buyer bears return cost if they insist on shipping back |
| **COD** | Keep collected / keep AR |
| **Ops** | Inbound QC photos; deny credit |

#### WS-3C — Poor packaging (supplier fault)

| Field | Value |
|---|---|
| **Trigger** | Fragile broke due to missing bubble wrap / bad box |
| **Parcel condition** | Damaged; packing fault |
| **Fault** | `supplier` |
| **Product / invoice** | CN + absorb loss |
| **Logistics** | Supplier pays return / replacement shipping |
| **COD** | Buyer not charged for ruined goods |
| **Ops** | Packing audit; packing video if available |

### 4. Lost / missing

#### WS-4A — Lost in transit (to buyer)

| Field | Value |
|---|---|
| **Trigger** | Parcel missing at hub / rider before delivery |
| **Parcel condition** | `missing` |
| **Fault** | `courier` |
| **Product / invoice** | Do not collect / CN; claim courier for invoice value |
| **Logistics** | Claim vs courier |
| **COD** | No COD due |
| **Ops** | After aging cutoff (see WS-5D) auto-map to lost |

#### WS-4B — Empty box / pilferage

| Field | Value |
|---|---|
| **Trigger** | Empty box or filler (stones/bricks) on delivery / open |
| **Parcel condition** | `empty_pilfered` |
| **Fault** | `fraud_dispute` (courier / transit) |
| **Product / invoice** | Hold; CN only when claim accepted |
| **Logistics** | Claim; packing video from supplier required |
| **COD** | Hold remittance / AR |
| **Ops** | Freeze settlement until claim closed |

#### WS-4C — Return parcel lost (RTO / reverse missing)

| Field | Value |
|---|---|
| **Trigger** | Marked returned but box never arrives at warehouse |
| **Parcel condition** | `missing` |
| **Fault** | `courier` |
| **Product / invoice** | Do not reverse stock until claim; money follows claim |
| **Logistics** | Supplier claims loss from courier |
| **COD** | Buyer not charged product for phantom return stock |
| **Ops** | Separate “return missing” claim from forward lost |

#### WS-4D — Return fraud (switched goods)

| Field | Value |
|---|---|
| **Trigger** | Buyer keeps good item; returns old/fake in box |
| **Parcel condition** | `switched` |
| **Fault** | `buyer_or_dropshipper` |
| **Product / invoice** | Deny CN |
| **Logistics** | Buyer pays any reverse freight already incurred |
| **COD** | Keep sale |
| **Ops** | Inbound QC / serial / seal check |

### 5. Financial & billing edge cases

#### WS-5A — Paid / COD taken but falsely marked returned

| Field | Value |
|---|---|
| **Trigger** | Rider took cash (or payment recorded) but system shows Returned without box |
| **Parcel condition** | Unknown / disputed |
| **Fault** | `fraud_dispute` (courier) |
| **Product / invoice** | Keep sale if COD proven; claim courier fraud |
| **Logistics** | No fake RTO fees to buyer |
| **COD** | Recover remittance from courier |
| **Ops** | Hold buyer AR clean; escalate claim |

#### WS-5B — COD / remittance amount mismatch

| Field | Value |
|---|---|
| **Trigger** | Courier remitted less than invoice / expected COD |
| **Parcel condition** | N/A (money only) |
| **Fault** | `courier` (or cash handling) |
| **Product / invoice** | Adjust AR: courier owes shortfall |
| **Logistics** | Unchanged |
| **COD** | Book collected vs expected; shortfall claim |
| **Ops** | Remittance reconcile line |

#### WS-5C — Negative balance / unpaid return charges

| Field | Value |
|---|---|
| **Trigger** | Return freight + restock exceed open credit / CN |
| **Parcel condition** | Per linked returns |
| **Fault** | `buyer_or_dropshipper` |
| **Product / invoice** | Debit note or cash invoice for net due |
| **Logistics** | Already in the debit |
| **COD** | N/A |
| **Ops** | Buyer must pay out-of-pocket |

#### WS-5D — Stuck / delayed (aging parcel)

| Field | Value |
|---|---|
| **Trigger** | “In transit” / “hold at hub” 15–30+ days; no deliver or return |
| **Parcel condition** | Treat as `missing` after cutoff |
| **Fault** | `courier` (after cutoff) |
| **Product / invoice** | Map to WS-4A / WS-4C |
| **Logistics** | Open courier claim |
| **COD** | Pause dunning until rule fires |
| **Ops** | **Cutoff rule (default proposal: 21 days)** → Lost |

### Wholesale condition checklist

| Code | Name | Product | Logistics payer | Claim? |
|---|---|---|---|---|
| WS-1A | Intact refusal | CN + restock | Buyer | No |
| WS-1B | Partial return | Line CN | Buyer (returned qty) | No |
| WS-1C | Fake / unreachable | CN if returned | Buyer + penalty | No |
| WS-2A | Variant exchange | Swap / CN+new | Buyer (two-way) | No |
| WS-2B | Change of mind | CN if policy | Buyer + restock | No |
| WS-2C | Supplier defect/wrong | Full CN | Supplier | No |
| WS-3A | Transit damage | CN after claim | Courier | Yes |
| WS-3B | Buyer damage | No CN | Buyer | No |
| WS-3C | Bad packaging | CN | Supplier | No |
| WS-4A | Lost forward | CN / don’t collect | Courier | Yes |
| WS-4B | Pilferage | Hold → CN | Courier | Yes |
| WS-4C | Return missing | Claim; no false stock | Courier | Yes |
| WS-4D | Switch fraud | Deny CN | Buyer | No |
| WS-5A | Fake returned + COD | Keep sale; claim | Courier | Yes |
| WS-5B | COD short | Adjust AR | Courier | Yes |
| WS-5C | Negative after fees | Debit buyer | Buyer | No |
| WS-5D | Aging stuck | → Lost | Courier | Yes |

---

## Part 2 — Dropship

**Money model:** Supplier bills dropshipper for product. Courier collects COD from end customer and remits to supplier. Dropshipper earns margin after remittance. Dropshipper pays forward/return fees unless fault is supplier or courier.

### 1. Customer refusal / undelivered (RTO)

#### DS-1A — Standard refusal (box intact)

| Field | Value |
|---|---|
| **Trigger** | End customer cancels at door, no answer, wrong address; box returns sellable |
| **Parcel condition** | `sellable` |
| **Fault** | `customer` / dropshipper order quality |
| **Product bill** | Credit / waive product bill when restocked |
| **Logistics** | Dropshipper: forward + return (+ packing/restock if policy) |
| **COD** | Not collected; no profit payout |
| **Ops** | RTO receive → QC → `finalize_dropship_return` / settlement |

#### DS-1B — Partial delivery / partial return

| Field | Value |
|---|---|
| **Trigger** | Customer orders N items; accepts some; returns rest |
| **Parcel condition** | Mix |
| **Fault** | Usually customer / dropshipper; split if supplier wrong on returned lines |
| **Product bill** | Charge accepted lines; credit returned if sellable |
| **Logistics** | Dropshipper pays courier fees on returned portion |
| **COD** | Collected = accepted value only |
| **Ops** | Split settlement: delivered vs returned lines |

#### DS-1C — Fake / prank order

| Field | Value |
|---|---|
| **Trigger** | Non-existent customer / unreachable number; unopened RTO |
| **Parcel condition** | `sellable` if returned |
| **Fault** | `buyer_or_dropshipper` (dropshipper) |
| **Product bill** | Credit if returned; else hold |
| **Logistics** | Dropshipper: full logistics + invoice penalty |
| **COD** | Not collected |
| **Ops** | Risk flag / auto penalty on repeat |

### 2. Post-delivery return / exchange (COD already paid)

#### DS-2A — Size / color / variant exchange

| Field | Value |
|---|---|
| **Trigger** | End customer wants different size/color |
| **Parcel condition** | Return `sellable`; new forward fresh |
| **Fault** | Customer / dropshipper (unless supplier wrong → DS-2C) |
| **Product bill** | Usually no product loss if swap completes |
| **Logistics** | Dropshipper: reverse pickup + new forward |
| **COD** | Old COD remitted; new COD on replacement if price differs |
| **Ops** | Two consignments linked to one exchange case |

#### DS-2B — Change of mind return

| Field | Value |
|---|---|
| **Trigger** | Customer paid COD, intact product, wants refund |
| **Parcel condition** | `sellable` |
| **Fault** | `customer` / dropshipper policy promise |
| **Product bill** | Credit after QC restock; reverse dropshipper settlement as needed |
| **Logistics** | Dropshipper: return shipping + handling/restock |
| **COD** | Refund path to customer (dropshipper/supplier per policy); claw back profit |
| **Ops** | Policy window; `return_reason_note` |

#### DS-2C — Defective / wrong item (supplier)

| Field | Value |
|---|---|
| **Trigger** | Supplier packed wrong SKU or factory defect |
| **Parcel condition** | `wrong_sku` / defective |
| **Fault** | `supplier` |
| **Product bill** | Waive / credit; no penalty to dropshipper |
| **Logistics** | Supplier absorbs return / exchange cost |
| **COD** | Refund or replace customer; dropshipper margin protected per policy |
| **Ops** | Do not bill dropshipper logistics |

### 3. Product damage

#### DS-3A — Transit damage (courier fault)

| Field | Value |
|---|---|
| **Trigger** | Crushed / wet / broken in courier handling |
| **Parcel condition** | `damaged_transit` |
| **Fault** | `courier` |
| **Product bill** | Waive/credit dropshipper if claim accepted |
| **Logistics** | Courier compensation to supplier |
| **COD** | Usually not collected; if collected then dispute |
| **Ops** | AWB + photos + claim before final settlement |

#### DS-3B — Customer-inflicted damage (used / tampered)

| Field | Value |
|---|---|
| **Trigger** | Customer opens, uses, breaks seals/tags, forces return |
| **Parcel condition** | `damaged_customer` / unsellable |
| **Fault** | `customer` → billed to dropshipper |
| **Product bill** | **Charge dropshipper full product invoice** |
| **Logistics** | Dropshipper pays return fee |
| **COD** | Keep remittance; no customer product refund (or dropshipper funds goodwill) |
| **Ops** | Open-box / seal verify on reverse |

#### DS-3C — Poor packaging (supplier fault)

| Field | Value |
|---|---|
| **Trigger** | Fragile broke from bad packing |
| **Parcel condition** | Damaged; packing fault |
| **Fault** | `supplier` |
| **Product bill** | Supplier absorbs; credit dropshipper |
| **Logistics** | Supplier |
| **COD** | Protect customer + dropshipper |
| **Ops** | Packing video preferred |

### 4. Lost / missing

#### DS-4A — Lost in transit (courier lost parcel)

| Field | Value |
|---|---|
| **Trigger** | Missing at hub / rider before delivery |
| **Parcel condition** | `missing` |
| **Fault** | `courier` |
| **Product bill** | Waive/credit dropshipper; courier reimburses supplier |
| **Logistics** | Claim |
| **COD** | None |
| **Ops** | Aging cutoff → auto Lost |

#### DS-4B — Empty box / pilferage

| Field | Value |
|---|---|
| **Trigger** | Empty box or filler delivered / found |
| **Parcel condition** | `empty_pilfered` |
| **Fault** | `fraud_dispute` |
| **Product bill** | Hold until claim; then credit if courier liable |
| **Logistics** | Claim; require packing video |
| **COD** | Hold remittance / settlement |
| **Ops** | Freeze dropshipper charges for product |

#### DS-4C — RTO parcel lost (marked returned, never arrives)

| Field | Value |
|---|---|
| **Trigger** | Customer refused; courier marked Returned; box never at warehouse |
| **Parcel condition** | `missing` |
| **Fault** | `courier` |
| **Product bill** | Dropshipper **not** charged product; claim courier |
| **Logistics** | May still assess attempted-delivery fees per policy until claim proves loss |
| **COD** | Not collected |
| **Ops** | Do not finalize product charge until receive or claim |

#### DS-4D — Wrong product switched by customer (return fraud)

| Field | Value |
|---|---|
| **Trigger** | Customer keeps original; puts fake/old item in return box |
| **Parcel condition** | `switched` |
| **Fault** | `customer` → usually dropshipper if no open-box verify |
| **Product bill** | Charge dropshipper (or shared if courier failed open-box duty) |
| **Logistics** | Dropshipper |
| **COD** | Keep original remittance |
| **Ops** | Policy: require open-box at reverse pickup |

### 5. Financial & billing edge cases

#### DS-5A — COD collected, return falsely marked

| Field | Value |
|---|---|
| **Trigger** | Rider took cash; marked Returned; no box back |
| **Parcel condition** | Disputed |
| **Fault** | `fraud_dispute` (courier) |
| **Product bill** | Dropshipper should **not** pay product as RTO |
| **Logistics** | No fake RTO fee stack |
| **COD** | Claim full COD from courier |
| **Ops** | Hold settlement; courier fraud claim |

#### DS-5B — COD amount mismatch

| Field | Value |
|---|---|
| **Trigger** | Courier collected less than invoice / booked COD |
| **Parcel condition** | N/A |
| **Fault** | `courier` |
| **Product bill** | Unchanged; money shortfall is courier AR |
| **Logistics** | Unchanged |
| **COD** | Settlement uses **collected**, not booked; courier owes difference |
| **Ops** | Remittance reconcile (`collected_cod_amount` vs calculated) |

#### DS-5C — Negative balance / unpaid return charges

| Field | Value |
|---|---|
| **Trigger** | Many returns; return shipping + packing > pending COD / payout |
| **Parcel condition** | Per linked RTOs |
| **Fault** | `buyer_or_dropshipper` |
| **Product bill** | Any charged product + fees → net debit |
| **Logistics** | Included in debit |
| **COD** | Insufficient to clear |
| **Ops** | Dropshipper pays out-of-pocket / wallet debit invoice |

#### DS-5D — Stuck / delayed return (aging parcel)

| Field | Value |
|---|---|
| **Trigger** | In transit / hold 15–30+ days; not delivered or returned |
| **Parcel condition** | After cutoff → `missing` |
| **Fault** | `courier` |
| **Product bill** | Map to DS-4A or DS-4C; waive product pending claim |
| **Logistics** | Pause extra fees until rule fires |
| **COD** | Hold |
| **Ops** | **Cutoff (default proposal: 21 days)** → Lost + claim |

### Dropship condition checklist

| Code | Name | Product bill | Logistics payer | Claim? |
|---|---|---|---|---|
| DS-1A | Intact RTO | Credit if restocked | Dropshipper | No |
| DS-1B | Partial return | Split charge/credit | Dropshipper (returned) | No |
| DS-1C | Prank / fake | Credit if returned | Dropshipper + penalty | No |
| DS-2A | Variant exchange | Neutral if swap OK | Dropshipper (two-way) | No |
| DS-2B | Change of mind | Credit after QC | Dropshipper + restock | No |
| DS-2C | Supplier defect/wrong | Credit; no penalty | Supplier | No |
| DS-3A | Transit damage | Credit if claim OK | Courier | Yes |
| DS-3B | Customer damage | **Full charge** | Dropshipper | No |
| DS-3C | Bad packaging | Credit | Supplier | No |
| DS-4A | Lost forward | Waive/credit | Courier | Yes |
| DS-4B | Pilferage | Hold → credit | Courier | Yes |
| DS-4C | RTO missing | No product charge | Courier | Yes |
| DS-4D | Switch fraud | Charge dropshipper* | Dropshipper | Maybe |
| DS-5A | Fake returned + COD | No RTO product bill | Courier | Yes |
| DS-5B | COD short | — | Courier owes Δ | Yes |
| DS-5C | Negative after fees | Net debit | Dropshipper | No |
| DS-5D | Aging stuck | → Lost | Courier | Yes |

\*Unless open-box verify was courier’s duty and failed — then dispute share.

---

## Side-by-side (same event)

| Event | Wholesale default | Dropship default |
|---|---|---|
| Intact RTO | Buyer: fees; CN if restocked | Dropshipper: fees; credit product if restocked |
| Supplier wrong / defect | Supplier | Supplier |
| Courier damage / lost | Claim; CN / don’t collect | Claim; credit dropshipper product |
| Receiver damaged return | Buyer — no CN | Dropshipper — full product bill |
| COD short / fake “returned” | Courier claim; protect buyer AR | Courier claim; protect dropshipper |
| Fees exceed credit / payout | Buyer debit | Dropshipper out-of-pocket / wallet |

---

## Policy choices to lock

1. **Partial COD + partial return** — one settlement vs separate delivered/returned lines.
2. **Open-box on reverse pickup** — required for DS-3B / DS-4D / WS-4D or optional.
3. **Aging days** — 15 / 21 / 30 before Lost (doc default: **21**).
4. **Prank / high RTO** — penalty % and auto-block threshold.
5. **Wholesale COD** — in scope for BD lanes, or invoice-only.
6. **Exchange** — new linked order vs same-order rewrite.
7. **Restock fee %** — wholesale vs dropship rates.

---

## Codebase fit (today)

- Wholesale: invoice return via `process_wholesale_invoice_return` (credit-note style).
- Dropship: `finalize_dropship_return`, `mark_dropship_order_returned`, remittance / courier AR, `return_reason_note` on settlement.
- This file is the **scenario catalog**. Codes are not all separate DB statuses yet; use them as ops reason / playbook IDs when implementing.
