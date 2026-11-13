# Shipment & warehouse

Product-decision catalog for **goods in, warehouse, and catalog delivery trips**.  
**Pairs with:** [roles.md](roles.md) · [money-flow-guide.md](money-flow-guide.md) (bills, landed cost, shipment P&L) · [investor-shipment-guide.md](investor-shipment-guide.md) (capital + profit share) · [shop-and-orders-guide.md](shop-and-orders-guide.md) (dropship = no delivery trip) · [decision board](money-flow-pnl-product-review.md).

> This catalog is **goods and trips**. Money treatment points to money scenarios by ID. Investor capital on a batch → investor catalog (hook **IN12**).

---

## 1. Plain words + one running idea

> **We buy a batch → it travels → we receive and cost it → we store it → (catalog / pre-order) we deliver in several trips → we bill what the customer kept.**

| Leg | Meaning | Example |
| :--- | :--- | :--- |
| **Inbound shipment** | One vendor batch + import costs | 500 units on one UK container |
| **Demand / buy** | After customer confirms qty, plan vendors | Need 50 → Vendor A 30, B 20 |
| **Delivery trip** | Part of an order leaves today | Trip 1 ships 15 of 50 |
| **Warehouse** | Bins, moves, damage, counts | 10 units to quarantine |
| **Carton register** | Shipping weight vs received weight | Cargo 480 kg; floor 475 kg |
| **Batch / expiry file** | Vendor batch codes matched to lines | Paste supplier Excel; warn short expiry |

**Dropship reseller orders** use the same warehouse stock but the **shop** playbook — no demand buy sheet and no catalog delivery trip.

---

## 2. Locked rules

1. **Inbound shipment statuses** (only these; progress tags ≠ status):

   | Status | Meaning |
   | :--- | :--- |
   | **draft** (planned) | Vendor, SKUs, ordered qty recorded; no warehouse stock |
   | **in_transit** | Left vendor / on the way; still no bins |
   | **received** | Sellable stock was **posted** to warehouse — not a paper checkbox |
   | **cancelled** | Stopped before meaningful receive; no stock post |

   Notes like “at port” are tags only — they are not a status and not receive.

2. Land split per SKU: sellable + missing + damaged + discount = ordered before post.
3. Damage **after** receive = warehouse adjustment — not a fake new import line.
4. Landed unit cost = capitalized import stack; shared freight/customs split with a written basis (money **SH7**, **S11**). Non-shelf fees → shipment profit, not unit cost (money **SH9**).
5. One vendor shipment bill per cost type and currency — no silent mix (money **SH10**).
6. One delivery trip = one outbound story; many trips per catalog order is normal. Stock leaves on **dispatch**; bill **accepted** door lines only.
7. Dropship never uses catalog delivery-trip steps (shop catalog).
8. Box register: shipping weight + received weight; explain gaps before trusting freight per kg.
9. Batch file (when used): paste/match **before** post; short expiry is a buying decision, not a door fix.
10. Who names: [roles.md](roles.md) only. Documents: inbound shipment, land outcome lines, demand/buy plan, delivery trip, stock lot, carton row, batch code list.

---

## 3. Scenarios we may cover

### 3.1 Inbound lifecycle
### IN1 — Open a new inbound batch
- **What’s happening:** Record vendor, SKUs, ordered qty before goods move.
- **Example:** PO 100 × 50 BDT FOB; status planned.
- **Who:** Procurement / Buyer · Vendor
- **Need in product:** Shipment header + ordered lines; no warehouse stock yet.
- **Cover?:** Must
- **Watch out:** No stock before receive.
### IN2 — Goods in transit
- **What’s happening:** Left vendor / on water; not in our bins.
- **Example:** Container sailed; ETA 3 weeks.
- **Who:** Shipping Coordinator · Cargo Company
- **Need in product:** In-transit date + cargo ref; no warehouse stock.
- **Cover?:** Must
- **Watch out:** Do not invent receive.
### IN3 — Land split at receive
- **What’s happening:** Physical vs PO: sellable, short, damaged, concession.
- **Example:** Ordered 100; sellable 95; missing 3; damaged 2.
- **Who:** Receiver · Approver / Manager
- **Need in product:** Outcome lines sum to ordered per SKU before post.
- **Cover?:** Must
- **Watch out:** No post until split ties.
### IN4 — Post sellable to warehouse
- **What’s happening:** Sellable units become inventory lots.
- **Example:** 95 lots at 120 BDT landed each.
- **Who:** Receiver · Warehouse / Inventory Manager
- **Need in product:** Bin, qty, unit landed cost; shipment → received.
- **Cover?:** Must
- **Watch out:** Paper receive without post is not receive.
### IN5 — Vendor credit for short/damage
- **What’s happening:** Vendor credit for missing/damaged.
- **Example:** 2 damaged × 500 = 1,000 credit.
- **Who:** Receiver · AP Clerk · Vendor
- **Need in product:** Credit linked to shipment line (money **V4**).
- **Cover?:** Must
- **Watch out:** Do not hide damage as sellable.
### IN6 — Shelf life after receive
- **What’s happening:** Grade/hold/bin change after shipment closed on paper.
- **Example:** 10 units to quarantine pending QC.
- **Who:** Warehouse / Inventory Manager
- **Need in product:** Warehouse move only; inbound paper unchanged.
- **Cover?:** Must
- **Watch out:** Not a new inbound line.
### IN7 — Cancelled inbound
- **What’s happening:** Cancelled before meaningful receive.
- **Example:** Factory cancelled PO.
- **Who:** Procurement / Buyer · Vendor · Treasury / Cashier / Finance
- **Need in product:** Cancelled status; no stock; unwind prepay (money **V3**).
- **Cover?:** Must
- **Watch out:** No silent stock.
### IN8 — Close shipment for audit
- **What’s happening:** Freeze qty/cost edits without supervisor. Money close → money **SH4**; month → **S21**.
- **Example:** Month-end; costs locked after AP paid.
- **Who:** Receiver · Treasury / Cashier / Finance · Approver / Manager
- **Need in product:** Close date + who locked; no silent edits.
- **Cover?:** Must
- **Watch out:** Investor close pack is money/investor — not goods edits here.

### 3.2 Shipment costs (money / investor pointers)

Goods view only. Full money bodies live in the money catalog; investor bodies in the investor catalog.
### IN9 — Material, freight, customs, handling
- **What’s happening:** Import stack into buckets; product lines + shared-cost split.
- **Example:** Goods 5,000 USD; freight 500 USD; customs 80,000 BDT.
- **Who:** AP Clerk · Shipping Coordinator · Vendor · Cargo Company · Customs Authority
- **Need in product:** Payables + capitalize per policy → money **R6**, **CA1–CA3**, **SH1**, **SH7**, **R20**.
- **Cover?:** Must
- **Watch out:** Cargo fee ≠ customs duty; accrue if bill late but known.
### IN10 — Restamp unit cost after pay
- **What’s happening:** Paid FX restamps lot unit cost; sold catch-up → money **SH8**.
- **Example:** Product FX from goods pay; freight FX from cargo pay.
- **Who:** Treasury / Cashier / Finance · AP Clerk
- **Need in product:** Payment FX per allocation — not one guessed blend (**V1**, **SH8**, **SH10**).
- **Cover?:** Must
- **Watch out:** Keep payment rates.
### IN11 — Non-capitalizable shipment fees
- **What’s happening:** Tips, penalties, non-recoverable VAT — not unit cost.
- **Example:** Dock tip 2,000 BDT.
- **Who:** Treasury / Cashier / Finance
- **Need in product:** Expense / shipment profit; units keep prior landed cost → money **SH9**.
- **Cover?:** Must
- **Watch out:** Do not hide fines in unit cost.
### IN12 — Investor on inbound (hook)
- **What’s happening:** Batch may carry investor capital + profit share — not interest.
- **Example:** See investor **INV1** / money **SH3**; close **INV7–INV8** / **SH4**.
- **Who:** Investor · Legal / Finance Approver · Treasury / Cashier / Finance
- **Need in product:** Link capital to this shipment ID only.
- **Cover?:** Must
- **Watch out:** Full playbook → investor catalog. Not sales; not delivery-trip billing.

### 3.3 Carton weight register

### BX1 — Register each carton
- **What’s happening:** Shipment arrives as numbered cartons.
- **Example:** Cartons 1–24 on one inbound.
- **Who:** Receiver
- **Need in product:** One row per carton with clear ID.
- **Cover?:** Must
- **Watch out:** No lump-only when register is used.
### BX2 — Shipping weight (cargo side)
- **What’s happening:** Weight on bill / packing list / AWB.
- **Example:** Carton 7 shipping 18.5 kg.
- **Who:** Receiver · Shipping Coordinator · Cargo Company
- **Need in product:** Shipping weight per carton; sum = box shipping total.
- **Cover?:** Must
- **Watch out:** Source documented.
### BX3 — Received weight (warehouse scale)
- **What’s happening:** Weigh cartons on the floor.
- **Example:** Carton 7 received 18.2 kg.
- **Who:** Receiver
- **Need in product:** Received weight per carton; sum = box received total.
- **Cover?:** Must
- **Watch out:** Scale truth.
### BX4 — Shipping vs received
- **What’s happening:** Compare totals; explain gaps.
- **Example:** Shipping 480 kg; received 475 kg → 5 kg to investigate.
- **Who:** Receiver · Shipping Coordinator · Cargo Company
- **Need in product:** Net difference + reason before sign-off.
- **Cover?:** Must
- **Watch out:** Large gap blocks trusted freight/kg.
### BX5 — Boxes vs invoice cargo weight
- **What’s happening:** Header invoice cargo kg must agree with box story.
- **Example:** Freight invoice 480 kg; shipping 480; received 475.
- **Who:** Receiver · Treasury / Cashier / Finance · Cargo Company
- **Need in product:** Reconcile before lock freight in landed cost (**CA1**, **IN10**).
- **Cover?:** Must
- **Watch out:** Freight allocates on invoice/shipping side; receive explains shrink.
### BX6 — Update invoice cargo from receive
- **What’s happening:** Policy may replace estimated cargo kg with received total.
- **Example:** Est. 500 kg → received 497 kg; header corrected.
- **Who:** Receiver · Approver / Manager · Treasury / Cashier / Finance
- **Need in product:** Who changed header + when; restamp if freight share shifts.
- **Cover?:** Should
- **Watch out:** Only when policy allows.

### 3.4 Batch and expiry codes

### BC1 — Create batch file
- **What’s happening:** One batch list per inbound (optional if no expiry goods).
- **Example:** Cosmetics; supplier 2,000-row sheet.
- **Who:** Receiver · Procurement / Buyer
- **Need in product:** Shipment ref + paste version date.
- **Cover?:** Should
- **Watch out:** Required for regulated / expiry SKUs → Must in those tenants.
### BC2 — Paste or enter rows
- **What’s happening:** Bulk import: barcode, SKU, batch, MFG, EXP.
- **Example:** Paste 500 rows from vendor Excel.
- **Who:** Receiver
- **Need in product:** Row count; fix bad dates before match.
- **Cover?:** Should
- **Watch out:** Bad dates break expiry logic.
### BC3 — Match lines to shipment SKUs
- **What’s happening:** Tie batch rows to shipment lines by barcode/product code.
- **Example:** Serum line matches 48 rows; 2 unmatched.
- **Who:** Receiver
- **Need in product:** Unmatched → zero (or explained) before post on regulated SKUs.
- **Cover?:** Must
- **Watch out:** No silent unmatched.
### BC4 — Expiry warning
- **What’s happening:** Near-expiry rows need attention (policy window).
- **Example:** Expiry in 8 months on 36-month norm.
- **Who:** Procurement / Buyer · Receiver · Approver / Manager
- **Need in product:** Manager sign-off before main sellable post.
- **Cover?:** Must
- **Watch out:** Short dates = buying issue, not door fix.
### BC5 — Mark batch rows arrived
- **What’s happening:** Confirm which batch lines physically showed up.
- **Example:** 200 on file; 195 arrived; 5 missing → ties **IN3**.
- **Who:** Receiver
- **Need in product:** Arrived flag; missing feeds short/damage.
- **Cover?:** Must
- **Watch out:** Truth matches land split.
### BC6 — Post stock with batch on lots
- **What’s happening:** Batch/expiry flows onto warehouse lots.
- **Example:** Lot LOT2025-A, expiry 2028-03.
- **Who:** Receiver · Warehouse / Inventory Manager
- **Need in product:** Same batch on lot as supplier sheet; FEFO/FIFO (**WH6**).
- **Cover?:** Must
- **Watch out:** When batch file is used.
### BC7 — Review batch on old shipments
- **What’s happening:** History for recall / audit.
- **Example:** Complaint on LOT2025-A → find shipments/lots.
- **Who:** Warehouse / Inventory Manager · Approver / Manager
- **Need in product:** Searchable history; archive not delete (**IN13**).
- **Cover?:** Should
- **Watch out:** Do not purge batch for convenience.

### 3.5 Archive

### IN13 — Retire old shipment from active lists
- **What’s happening:** Hide historical batch from daily ops; stock may remain.
- **Example:** Archive after close + ops done.
- **Who:** Warehouse / Inventory Manager · Approver / Manager
- **Need in product:** Archive marker + who/when.
- **Cover?:** Should
- **Watch out:** Stock still findable.
### IN14 — Purge historical batch
- **What’s happening:** Permanent removal of archived paperwork — rare.
- **Example:** Supervisor purge after legal hold clear.
- **Who:** Approver / Manager · Admin
- **Need in product:** Purge approval; invoices keep snapshots.
- **Cover?:** Out
- **Watch out:** Default keep history; purge only with written policy.

### 3.6 Demand and buy (catalog / pre-order)

### DEM1 — Customer confirms quantity
- **What’s happening:** Locks what we owe the customer.
- **Example:** Customer confirms 50 after final offer.
- **Who:** Sales / Channel Manager · Customer
- **Need in product:** Confirmed qty; need = confirmed until deliveries reduce open.
- **Cover?:** Must
- **Watch out:** No buy plan before confirm.
### DEM2 — Split need across vendors
- **What’s happening:** Who supplies the confirmed need.
- **Example:** Need 50 → X 30, Y 20.
- **Who:** Procurement / Buyer
- **Need in product:** Vendor placements; save before leave.
- **Cover?:** Must
- **Watch out:** Partial save must not lose work.
### DEM3 — Under-ordered
- **What’s happening:** Placements < confirmed need.
- **Example:** Need 50; placed 40.
- **Who:** Procurement / Buyer · Sales / Channel Manager
- **Need in product:** Backorder flag + honest coverage.
- **Cover?:** Must
- **Watch out:** Do not pretend 50 covered.
### DEM4 — Multiple inbounds fill one need
- **What’s happening:** Several shipments build stock for later trips.
- **Example:** Ship A 30 + Ship B 20 → 50 in stock.
- **Who:** Receiver · Warehouse / Inventory Manager · Procurement / Buyer
- **Need in product:** Stock available for pick; lot → shipment for margin.
- **Cover?:** Must
- **Watch out:** Traceability at pick.

### 3.7 Delivery trip (catalog / pre-order outbound)

### DP1 — Start a delivery trip
- **What’s happening:** Trip for part of open need.
- **Example:** Confirmed 50; trip 1 ships 15.
- **Who:** Fulfillment · Sales / Channel Manager
- **Need in product:** Trip #, date, qty ≤ open.
- **Cover?:** Must
- **Watch out:** Partial qty OK.
### DP2 — Pick warehouse lots
- **What’s happening:** Assign bins/lots until dispatch.
- **Example:** Pick 15 FIFO from aisle A.
- **Who:** Fulfillment · Warehouse / Inventory Manager
- **Need in product:** Pick list; short pick is exception.
- **Cover?:** Must
- **Watch out:** No silent qty change.
### DP3 — Plan take / condition / reject
- **What’s happening:** Plan how qty may split at door.
- **Example:** 10 take, 3 condition, 2 likely reject.
- **Who:** Fulfillment
- **Need in product:** Optional planned columns before dispatch.
- **Cover?:** Should
- **Watch out:** Plan ≠ door truth.
### DP4 — Dispatch — stock leaves
- **What’s happening:** Physical exit; warehouse qty drops.
- **Example:** 15 out; delivery note for driver.
- **Who:** Fulfillment · Warehouse / Inventory Manager
- **Need in product:** Dispatch time; note ≠ tax invoice.
- **Cover?:** Must
- **Watch out:** Stock down when goods leave.
### DP5 — Door truth: accept / condition / reject
- **What’s happening:** What customer keeps overrides plan.
- **Example:** Accept 10; reject 2 → returns with grade.
- **Who:** Fulfillment · Customer · Sales / Channel Manager
- **Need in product:** Per trip/line outcome; bill accepted only (money AR).
- **Cover?:** Must
- **Watch out:** Rejects are not revenue.
### DP6 — Return on same trip
- **What’s happening:** Goods back on this visit.
- **Example:** 2 reject → returns shelf, damaged grade.
- **Who:** Fulfillment · Warehouse / Inventory Manager
- **Need in product:** Return qty; restock or write-off (money **S5**, **S13**).
- **Cover?:** Must
- **Watch out:** Grade before resale.
### DP7 — Short pick
- **What’s happening:** Could not pick full trip qty.
- **Example:** Planned 15; picked 12.
- **Who:** Fulfillment · Warehouse / Inventory Manager · Approver / Manager
- **Need in product:** Reason + approval; adjust trip or backorder.
- **Cover?:** Must
- **Watch out:** Exception path.
### DP8 — Trip completed or cancelled
- **What’s happening:** Outcomes fixed; no more column edits.
- **Example:** Trip delivered / cancelled.
- **Who:** Fulfillment · Approver / Manager
- **Need in product:** Status; cancelled must not leave stock “in van”.
- **Cover?:** Must
- **Watch out:** Books match physical.
### DP9 — Open qty on order header
- **What’s happening:** Order live until nothing left to deliver.
- **Example:** After trip 1, open 35 of 50 — partially fulfilled.
- **Who:** Sales / Channel Manager · Fulfillment
- **Need in product:** Open qty drives next trip.
- **Cover?:** Must
- **Watch out:** One trip close ≠ whole order done.

### 3.8 Warehouse (ongoing)

### WH1 — Location hierarchy
- **What’s happening:** Warehouse → zone → shelf → bin; returns separate.
- **Example:** Every lot on a leaf bin.
- **Who:** Warehouse / Inventory Manager
- **Need in product:** Location master; returns ≠ main sellable by default.
- **Cover?:** Must
- **Watch out:** No orphan lots.
### WH2 — Move between bins
- **What’s happening:** Same SKU, new location — not a sale.
- **Example:** 20 units wholesale aisle → retail front.
- **Who:** Warehouse / Inventory Manager
- **Need in product:** Move ref; no revenue (money **S14**).
- **Cover?:** Must
- **Watch out:** Not a sale.
### WH3 — Hold, grade, unsellable
- **What’s happening:** QC hold or downgrade.
- **Example:** 5 units water damage → unsellable.
- **Who:** Warehouse / Inventory Manager · Approver / Manager
- **Need in product:** Grade change; write-off if discarded (**S13**).
- **Cover?:** Must
- **Watch out:** Unsellable not sold.
### WH4 — Shrink / count variance
- **What’s happening:** Count ≠ system.
- **Example:** System 100; count 97.
- **Who:** Warehouse / Inventory Manager · Approver / Manager
- **Need in product:** Adjustment with approval.
- **Cover?:** Must
- **Watch out:** Approval required.
### WH5 — Cycle count
- **What’s happening:** Periodic full or partial count.
- **Example:** Zone count sheet.
- **Who:** Warehouse / Inventory Manager · Approver / Manager
- **Need in product:** Variances post only after approval.
- **Cover?:** Should
- **Watch out:** Schedule + trail.
### WH6 — Batch / expiry on lots
- **What’s happening:** Lots carry batch/expiry from batch file.
- **Example:** Batch ABX, expiry 2027-06; pick oldest first.
- **Who:** Warehouse / Inventory Manager · Fulfillment
- **Need in product:** FEFO/FIFO; quarantine short-dated (**BC4**).
- **Cover?:** Must
- **Watch out:** When expiry SKUs used.

---

## 4. Quick-ref

| ID | One-line | Who (short) | Cover? |
| :--- | :--- | :--- | :--- |
| IN1 | Open inbound | Buyer, Vendor | Must |
| IN2 | In transit | Shipping, Cargo | Must |
| IN3 | Land split | Receiver, Approver | Must |
| IN4 | Post sellable | Receiver, Warehouse | Must |
| IN5 | Vendor credit | Receiver, AP, Vendor | Must |
| IN6 | After-receive shelf | Warehouse | Must |
| IN7 | Cancel inbound | Buyer, Vendor | Must |
| IN8 | Close for audit | Receiver, Finance | Must |
| IN9 | Import cost buckets | → money R6/CA/SH | Must |
| IN10 | Restamp unit cost | → money SH8 | Must |
| IN11 | Non-cap fees | → money SH9 | Must |
| IN12 | Investor on inbound | → investor catalog | Must |
| BX1–BX5 | Carton weights | Receiver, Cargo | Must |
| BX6 | Header weight from receive | Receiver, Finance | Should |
| BC1–BC2 | Batch file create/paste | Receiver | Should |
| BC3–BC6 | Match / warn / arrived / post | Receiver, Warehouse | Must |
| BC7 | Historical batch search | Warehouse | Should |
| IN13 | Archive shipment | Warehouse | Should |
| IN14 | Purge history | Admin | Out |
| DEM1–DEM4 | Confirm / buy / multi-inbound | Sales, Buyer | Must |
| DP1–DP2 / DP4–DP9 | Trip pick / door / open qty | Fulfillment | Must |
| DP3 | Plan door columns | Fulfillment | Should |
| WH1–WH4 / WH6 | Locations / moves / grade / batch | Warehouse | Must |
| WH5 | Cycle count | Warehouse | Should |

---

## 5. Remember

1. Receive = sellable in the warehouse.
2. Land splits must tie to ordered before post.
3. Landed cost = capitalized import stack; shared split with a written basis (money).
4. One trip, one door story; many trips per order is normal.
5. Dispatch before customer bill; door outcome beats plan.
6. Dropship ≠ delivery trips (shop catalog).
7. Shelf damage after receive = warehouse, not a new inbound.
8. Box shipping vs received — explain the gap.
9. Batch file before post on expiry SKUs.
10. Investor on a batch → investor catalog; money P&L → money catalog.

---

## 6. Glossary

| Term | Meaning |
| :--- | :--- |
| **Inbound shipment** | Vendor batch we import and receive |
| **Land split** | Ordered → sellable / missing / damaged / discount |
| **Post to stock** | Create warehouse inventory from sellable |
| **Landed cost** | Unit cost with capitalized import charges |
| **Demand / need** | Customer-confirmed qty still to source/deliver |
| **Open quantity** | Confirmed − delivered − cancelled |
| **Delivery trip** | One outbound run: pick, dispatch, door |
| **Delivery note** | Proof goods left — not the tax invoice |
| **Take / condition / reject** | Door outcomes |
| **Short pick** | Could not pick planned trip qty |
| **Carton register** | Per-carton shipping + received weight |
| **Invoice cargo weight** | Chargeable kg on freight invoice |
| **Batch code file** | Barcodes, batch IDs, expiry for one shipment |

Money terms (shipment profit, non-shelf fee) → [money-flow-guide.md](money-flow-guide.md).  
Investor terms (capital, gate, profit share) → [investor-shipment-guide.md](investor-shipment-guide.md).
