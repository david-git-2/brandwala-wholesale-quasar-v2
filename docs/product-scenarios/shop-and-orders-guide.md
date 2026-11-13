# Shop & orders

Product-decision catalog for **three storefront types**, orders, and fulfill paths.  
**Pairs with:** [roles.md](roles.md) · [shipment-guide.md](shipment-guide.md) (catalog delivery trips **DP***) · [money-flow-guide.md](money-flow-guide.md) (dropship settle **T1**, **S6**, **CU***) · [courier-dispatch-guide.md](courier-dispatch-guide.md) · [decision board](money-flow-pnl-product-review.md).

> We are the **supplier**. Dropshipper = our customer; end customer = theirs. Our dropship revenue = **supply invoice**, not end-customer COD (money catalog).

---

## 1. Plain words + one running idea

We can run **more than one shop**. Each shop has **one storefront type**:

| Storefront | Who shops | Price | Fulfill |
| :--- | :--- | :--- | :--- |
| **Fixed price** | Customer | List price | Stock checkout → pick/ship (no catalog trips) |
| **Vendor catalog** | Customer | Negotiate → confirm qty | Buy → receive → **delivery trips** → bill per trip |
| **Dropship** | Dropshipper | Wholesale; reseller sets end price (min floor) | Call → pick → ship → COD remittance → pay reseller profit |

Fixed / catalog → **shop customers**. Dropship → **resellers** selling to **end customers**.

---

## 2. Locked rules

1. Storefront type is set when the shop is created — it picks the playbook.
2. Catalog confirmed qty locks buy + deliver — no silent cut.
3. Fixed-price sells stock-backed goods — not the trip/negotiate path.
4. Dropship minimum sell protects pricing floor.
5. Shown site qty may be padded commercially — never show zero when sellable stock exists.
6. Dropship: call end customer before pick when status is confirmed (policy).
7. At dropship ship: **supply invoice to dropshipper** + courier charges we owe — packing slip ≠ B2B invoice.
8. End-customer COD face amount → money clearing until remittance (**CU2**, **S6**).
9. Gifts: our stock (may charge dropshipper) or reseller-provided (no warehouse pick).
10. Cancel with reason on dropship; delete only dead cancelled rows — never purge live money history.

Who names: [roles.md](roles.md). Documents: shop order, packing/delivery slip, supply invoice (dropship), delivery trip note (catalog only), remittance batch.

---

## 3. Scenarios we may cover

### 3.1 Shop setup
### ADM1 — Open a new shop
- **What’s happening:** New sales channel with one storefront type.
- **Example:** “Reseller BD” dropship shop.
- **Who:** Sales / Channel Manager · Approver / Manager
- **Need in product:** Shop name, type, currency, display rules.
- **Cover?:** Must
- **Watch out:** Type drives the whole playbook.
### ADM2 — Customer groups and access
- **What’s happening:** Who enters which shop at which price tier.
- **Example:** Group Gold → Shop A at tier 2.
- **Who:** Sales / Channel Manager · Customer · Dropshipper
- **Need in product:** Group ↔ shop ↔ price tier.
- **Cover?:** Must
- **Watch out:** Access and price tied.
### ADM3 — Listings and prices
- **What’s happening:** Which SKUs appear; dropship minimum sell.
- **Example:** 200 SKUs fixed-price; dropship min sell 1,500.
- **Who:** Sales / Channel Manager
- **Need in product:** Listings + min sell on dropship.
- **Cover?:** Must
- **Watch out:** Min sell enforced.
### ADM4 — Categories and delivery rules
- **What’s happening:** Browse tree; shipping zones/charges.
- **Example:** Category tree + shipping policy.
- **Who:** Sales / Channel Manager
- **Need in product:** Categories + shipping per shop.
- **Cover?:** Should
- **Watch out:** Per-shop policy.
### ADM5 — Reseller-provided stock (gifts)
- **What’s happening:** Dropshipper promo stock at us — not main lots.
- **Example:** 50 gift sachets for Shop X.
- **Who:** Dropship desk · Warehouse / Inventory Manager · Dropshipper
- **Need in product:** Qty from reseller; not mixed with purchased COGS.
- **Cover?:** Should
- **Watch out:** Not our inventory cost.
### ADM6 — Auto-gift rules
- **What’s happening:** System adds gift lines once when order → processing.
- **Example:** Sample bag if reseller stock available.
- **Who:** Dropship desk · Dropshipper
- **Need in product:** Rule list; skip when stock short.
- **Cover?:** Should
- **Watch out:** Once per order.
### ADM7 — Couriers and pickup points
- **What’s happening:** Master data for dropship delivery partners.
- **Example:** Courier names, fee templates, pickups.
- **Who:** Shipping Coordinator · Dropship desk · Curia
- **Need in product:** Courier + fee + pickup masters.
- **Cover?:** Must
- **Watch out:** Needed before DS5/DS7.

### 3.2 Fixed price shop

### FP1 — Browse and cart
- **What’s happening:** Customer sees list prices; adds to cart.
- **Example:** 2 SKUs; total 3,500 BDT.
- **Who:** Customer · Sales / Channel Manager
- **Need in product:** Cart → shop order at checkout.
- **Cover?:** Must
- **Watch out:** Published price only.
### FP2 — Checkout
- **What’s happening:** Pay or charge account per shop rules.
- **Example:** Paid MFS 3,500 (money **R3**, **S4**).
- **Who:** Customer · Treasury / Cashier / Finance · Payment Gateway / MFS
- **Need in product:** Order confirmed + payment method.
- **Cover?:** Must
- **Watch out:** Channel on the sale.
### FP3 — Fulfill from warehouse
- **What’s happening:** Pick/pack/ship — **no** catalog delivery-trip doc.
- **Example:** Pick 2; invoice if not paid at checkout.
- **Who:** Fulfillment · Warehouse / Inventory Manager · Customer
- **Need in product:** Stock down; revenue per cash/credit policy.
- **Cover?:** Must
- **Watch out:** Never use **DP*** trips here.
### FP4 — Customer-visible vs staff-only
- **What’s happening:** Staff order customer may or may not see on portal.
- **Example:** Staff-only backfill flag.
- **Who:** Sales / Channel Manager · Customer
- **Need in product:** Visibility flag + creator.
- **Cover?:** Should
- **Watch out:** Portal honesty.

### 3.3 Vendor catalog shop

### VC1 — Submit for quote
- **What’s happening:** Customer asks staff to price the cart.
- **Example:** Submitted Friday; waiting for price.
- **Who:** Customer · Sales / Channel Manager
- **Need in product:** Submitted timestamp; no confirmed qty yet.
- **Cover?:** Must
- **Watch out:** Not payable yet.
### VC2 — Negotiation loop
- **What’s happening:** Offer → counter → final → confirm.
- **Example:** 48k → 45k → final 46k → confirmed.
- **Who:** Sales / Channel Manager · Customer
- **Need in product:** Each round; confirmed qty+price lock buying.
- **Cover?:** Must
- **Watch out:** Confirm locks need.
### VC3 — Start buying
- **What’s happening:** Confirmed need → demand desk / vendor placements.
- **Example:** Line confirmed 50 → need 50 (shipment **DEM***).
- **Who:** Sales / Channel Manager · Procurement / Buyer · Customer
- **Need in product:** Confirmed per line; open qty until trips.
- **Cover?:** Must
- **Watch out:** Hand off to shipment catalog.
### VC4 — Costing workbook for vendors
- **What’s happening:** Export sheet to talk to overseas vendors.
- **Example:** Same product IDs as internal costing.
- **Who:** Procurement / Buyer · Sales / Channel Manager
- **Need in product:** Versioned workbook to vendor.
- **Cover?:** Should
- **Watch out:** IDs must match.
### VC5 — Staff manual catalog order
- **What’s happening:** Phone/email or history backfill in back office.
- **Example:** A: new → VC2 loop. B: old delivered with frozen prices; maybe portal-hidden.
- **Who:** Sales / Channel Manager · Customer
- **Need in product:** Order date; staff-only / manual prices when backfill.
- **Cover?:** Should
- **Watch out:** Do not fake self-serve history.
### VC6 — Delivery and billing over time
- **What’s happening:** Many trips; bill accepted lines per trip.
- **Example:** Confirmed 50; trip 1 bills 12 accepted; 35 open (shipment **DP***; money **C2**).
- **Who:** Fulfillment · Sales / Channel Manager · Customer · Treasury / Cashier / Finance
- **Need in product:** Trip invoices + open qty.
- **Cover?:** Must
- **Watch out:** One trip ≠ whole order done.

### 3.4 Dropship shop

Money bodies for COD / supply invoice / remittance → [money-flow-guide.md](money-flow-guide.md) (**T1**, **S6**, **CU2**, **CU4**, **S10**). Courier risk → courier catalog.
### DS1 — Reseller checkout
- **What’s happening:** Dropshipper buys wholesale; must give end-customer details.
- **Example:** End price 25k; our supply 18k at ship.
- **Who:** Dropshipper · End customer · Dropship desk
- **Need in product:** Recipient mandatory; confirmed pending call.
- **Cover?:** Must
- **Watch out:** End customer ≠ our AR party.
### DS2 — Staff manual dropship order
- **What’s happening:** Same flow typed by staff.
- **Example:** Staff creates for reseller.
- **Who:** Dropship desk · Dropshipper
- **Need in product:** Creator + same call→pick→ship rules.
- **Cover?:** Should
- **Watch out:** Same gates as DS1.
### DS3 — Recipient confirmation call
- **What’s happening:** Verify end customer before pick.
- **Example:** No answer → log; stay confirmed. Cancel → reason for reseller.
- **Who:** Dropship desk · End customer · Dropshipper
- **Need in product:** Call outcome; no pick without verify when policy requires.
- **Cover?:** Must
- **Watch out:** Fraud/waste control.
### DS4 — Processing: pick and gifts
- **What’s happening:** Warehouse pick; optional gifts / auto-gifts.
- **Example:** 3 picks + gift from our stock charged 200 to dropshipper.
- **Who:** Fulfillment · Warehouse / Inventory Manager · Dropship desk · Dropshipper
- **Need in product:** Gift source; gifts excluded from COD face total.
- **Cover?:** Must
- **Watch out:** Reseller stock ≠ our COGS.
### DS5 — Ship
- **What’s happening:** Goods leave; supply invoice to dropshipper; courier fee obligation.
- **Example:** AR dropshipper 18k; courier AP 1k → money **T1**.
- **Who:** Fulfillment · Dropship desk · Treasury / Cashier / Finance · Curia · Dropshipper
- **Need in product:** Ship date; B2B invoice ≠ end-customer price.
- **Cover?:** Must
- **Watch out:** Packing slip is not the supply invoice.
### DS6 — Deliver and settlement
- **What’s happening:** Mark delivered; adjust COD/delivery vs issued if reality differs.
- **Example:** COD planned 25k; actual 24k — notes, not silent rewrite.
- **Who:** Dropship desk · Curia · Dropshipper · Treasury / Cashier / Finance
- **Need in product:** Settlement sheet before pay-in; debit/credit if issued wrong.
- **Cover?:** Must
- **Watch out:** No silent rewrite of issued invoice.
### DS7 — Courier remittance
- **What’s happening:** Courier remits net COD; clear dropshipper AR; remainder = their profit.
- **Example:** Gross 25k; fee 1k; remit 24k → clear 18k AR → 6k owed → money **CU2**, **S6**.
- **Who:** Dropship desk · Treasury / Cashier / Finance · Curia · Dropshipper
- **Need in product:** Order-by-order clearing.
- **Cover?:** Must
- **Watch out:** Detail in money catalog — not duplicated here.
### DS8 — Pay dropshipper their profit
- **What’s happening:** Cash out profit we held — not a second sales invoice.
- **Example:** Pay reseller 6k after remittance.
- **Who:** Treasury / Cashier / Finance · Approver / Manager · Dropshipper
- **Need in product:** Payout approval + statement.
- **Cover?:** Must
- **Watch out:** Not new revenue.
### DS9 — Cancel and delete
- **What’s happening:** Cancel with reason; delete only cancelled ghosts.
- **Example:** End customer refused; restock if picked (money **CU4**, **S10**).
- **Who:** Dropship desk · Warehouse / Inventory Manager · Dropshipper · End customer
- **Need in product:** Cancel reason; restock movement.
- **Cover?:** Must
- **Watch out:** Never purge live financial history.

---

## 4. Quick-ref

| ID | One-line | Who (short) | Cover? |
| :--- | :--- | :--- | :--- |
| ADM1 | New shop + type | Sales, Approver | Must |
| ADM2–ADM3 | Groups / listings / min sell | Sales | Must |
| ADM4 | Categories / shipping | Sales | Should |
| ADM5–ADM6 | Reseller gifts / auto-gift | Dropship desk | Should |
| ADM7 | Couriers / pickups | Shipping, Dropship desk | Must |
| FP1–FP3 | Fixed browse → fulfill | Customer, Fulfillment | Must |
| FP4 | Staff-only visibility | Sales | Should |
| VC1–VC3 | Quote → confirm → buy | Sales, Buyer | Must |
| VC4–VC5 | Costing sheet / manual order | Buyer, Sales | Should |
| VC6 | Partial trip billing | Fulfillment, Finance | Must |
| DS1 / DS3–DS9 | Dropship path + money hooks | Dropship desk, Curia | Must |
| DS2 | Staff manual dropship | Dropship desk | Should |

---

## 5. Remember

1. Three shop types — three playbooks; never mix catalog trips into fixed or dropship.
2. Dropshipper is the customer on our supply invoice; end customer is not.
3. Dropship revenue = supply invoice, not end-customer GMV (money **T1**).
4. Call gate before pick on dropship when policy says so.
5. Ship issues B2B bill; remittance moves cash; payout sends their profit.
6. Catalog = negotiate → buy → trip → door → bill; partial is normal.
7. Fixed price = list → checkout → pick.
8. COD / remittance detail → money catalog; trips → shipment catalog.

---

## 6. Glossary

| Term | Meaning |
| :--- | :--- |
| **Fixed price shop** | List price from our stock |
| **Vendor catalog shop** | Negotiate, then buy and trip-deliver |
| **Dropship shop** | Reseller wholesale; we ship to end customer |
| **Dropshipper** | Reseller — our B2B customer |
| **End customer** | Parcel recipient; may pay COD |
| **Supply invoice** | Our bill to dropshipper at ship |
| **Minimum sell** | Floor on reseller end price |
| **Confirmed quantity** | Locked catalog commit — drives buying |
| **Open quantity** | Still to deliver on a catalog line |
| **Remittance** | Courier sends net COD after fees |
| **Dropshipper profit balance** | What we owe reseller after supply cleared from COD |
| **Reseller stock** | Their promo inventory with us — not purchased COGS |

COD clearing / supply settle → [money-flow-guide.md](money-flow-guide.md).  
Catalog trips → [shipment-guide.md](shipment-guide.md).
