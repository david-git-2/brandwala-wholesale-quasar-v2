# Courier dispatch

Product-decision catalog for **last-mile Bangladesh dropship** (Steadfast / Pathao / RedX), tracking, and COD risk before dispatch.  
**Pairs with:** [roles.md](roles.md) · [shop-and-orders-guide.md](shop-and-orders-guide.md) (**DS3–DS9**) · [money-flow-guide.md](money-flow-guide.md) (**CU***, **S6**, **T1**, **R9**) · [decision board](money-flow-pnl-product-review.md).

> **Scope:** Dropship reseller orders only. Fixed-price and catalog shops do not use this playbook. Inbound import cargo ≠ this last-mile story ([shipment-guide.md](shipment-guide.md)).

---

## 1. Plain words + one running idea

> **We picked → hand parcel to courier → courier delivers / may collect COD → remits net cash → we settle the dropshipper.**

Three brands, **one playbook** — only provider name and fee table change.

| Step | Meaning | Points to |
| :--- | :--- | :--- |
| Pre-dispatch check | End customer real? COD history OK? | CD1–CD4 |
| Send to courier | Consignment: recipient, COD, weight | CD5–CD8 |
| Internal ship | Supply invoice + courier AP on our books | CD10–CD11 · shop **DS5** · money **T1** |
| Tracking | In transit → delivered / returned | CD12–CD15 |
| Remittance | Net COD in; clear AR + dropshipper profit | CD16 · money **CU2**, **R9** |

| Term | Meaning |
| :--- | :--- |
| **Send to courier** | Parcel enters courier network; tracking exists |
| **Internal ship** | B2B supply invoice to dropshipper + courier charge we owe — money step |

Default order: pick complete → send to courier → internal ship when finance rules allow (override only with written policy).

---

## 2. Locked rules

1. Recipient verified first — shop **DS3** call gate before pick; no high-value COD dispatch without approval if unverified.
2. COD face on the order = what **end customer** pays — not our B2B invoice to the dropshipper.
3. One **active** consignment per order — supersede old before new (**CD19**).
4. Tracking status ≠ money posted. Courier “delivered” does not replace finance settle (money **CU2**, shop **DS7**).
5. Return / failed delivery → restock or write-off; settle path money **CU4**, **S10**.
6. Inside vs outside Dhaka drives delivery-charge estimate — district must be honest.
7. Provider API credentials are tenant secrets; staff only pick brand.
8. Keep raw API/webhook payloads for disputes — do not edit timeline to fit a story.
9. Fee tables live in courier master — dispatch uses **estimates**; remittance uses **actual** (money).
10. Who names: [roles.md](roles.md) only.

---

## 3. Scenarios we may cover

### 3.1 Before dispatch
### CD1 — Check COD delivery history (phone)
- **What’s happening:** See past dropship COD success for this phone before pick/dispatch.
- **Example:** 8 past: 6 delivered, 2 returned → 75%; below 50% needs approval.
- **Who:** Dropship desk · Approver / Manager · End customer
- **Need in product:** Risk band + block/approve trail.
- **Cover?:** Must
- **Watch out:** Unknown history ≠ green (see CD2).
### CD2 — New phone (no history)
- **What’s happening:** First order to this number.
- **Example:** New number in Rangpur — treat as unknown.
- **Who:** Dropship desk · Approver / Manager · End customer
- **Need in product:** Flag no history; optional COD cap.
- **Cover?:** Must
- **Watch out:** Not auto-good.
### CD3 — Address and zone ready
- **What’s happening:** Name, phone, address, district/thana filled; zone drives fee.
- **Example:** District Dhaka → inside-Dhaka charge band.
- **Who:** Dropship desk · End customer
- **Need in product:** Same fields courier API will use.
- **Cover?:** Must
- **Watch out:** Fix typos before send.
### CD4 — Pick complete, ready for handover
- **What’s happening:** Lines picked; parcel weight known.
- **Example:** 1.2 kg; COD 2,500; delivery charge 80.
- **Who:** Fulfillment · Warehouse / Inventory Manager · Dropship desk
- **Need in product:** Weight band; gifts excluded from COD face (shop **DS4**).
- **Cover?:** Must
- **Watch out:** No dispatch on incomplete pick.

### 3.2 Send to courier

### CD5 — Choose provider
- **What’s happening:** Staff pick Steadfast / Pathao / RedX; fees from master.
- **Example:** Steadfast; COD fee 1%; forward 120 outside Dhaka.
- **Who:** Dropship desk · Shipping Coordinator · Curia
- **Need in product:** Provider on consignment; one brand per parcel.
- **Cover?:** Must
- **Watch out:** Do not mix providers on one parcel.
### CD6 — Send to courier (create consignment)
- **What’s happening:** Register parcel; get consignment id + tracking.
- **Example:** Tracking SF-8844221; status submitted_to_courier.
- **Who:** Dropship desk · Fulfillment · Curia
- **Need in product:** Timestamp, who, COD/delivery snapshotted on consignment.
- **Cover?:** Must
- **Watch out:** Consignment exists before claim dispatched.
### CD7 — Manual consignment (no API)
- **What’s happening:** Staff paste AWB from courier portal.
- **Example:** Booked on Steadfast site; paste tracking.
- **Who:** Dropship desk · Curia
- **Need in product:** Same fields as API; mark manual if policy requires.
- **Cover?:** Should
- **Watch out:** Same truth model as CD6.
### CD8 — Pickup from merchant location
- **What’s happening:** Courier collects from our pickup / hub on file.
- **Example:** Pickup phone + address sent to provider.
- **Who:** Dropship desk · Shipping Coordinator · Curia
- **Need in product:** Pickup fields match shop settings.
- **Cover?:** Must
- **Watch out:** Wrong pickup = lost parcel.

### 3.3 Internal ship (business, not courier)

Money bodies → [money-flow-guide.md](money-flow-guide.md). Shop ship → **DS5**.
### CD10 — Issue supply invoice and courier AP
- **What’s happening:** Bill dropshipper; record courier charge we expect.
- **Example:** B2B 1,800; courier AP 120 (shop **DS5**, money **T1**).
- **Who:** Treasury / Cashier / Finance · Dropship desk · Dropshipper · Curia
- **Need in product:** Internal ship ≠ CD6 button.
- **Cover?:** Must
- **Watch out:** Order may show shipped while courier still in transit.
### CD11 — Dispatch before vs after internal ship
- **What’s happening:** Tenant policy chooses order of CD6 vs CD10.
- **Example:** A: dispatch then ship same day. B: ship first for credit control.
- **Who:** Approver / Manager · Dropship desk · Treasury / Cashier / Finance
- **Need in product:** One written policy; train one way.
- **Cover?:** Should
- **Watch out:** No silent staff improvisation.

### 3.4 Tracking and delivery

### CD12 — In transit / out for delivery
- **What’s happening:** Courier scans; timeline updates.
- **Example:** Out for delivery 11am; COD not collected yet.
- **Who:** Dropship desk · Curia · Dropshipper
- **Need in product:** Timeline event only.
- **Cover?:** Must
- **Watch out:** Do not mark finance delivered yet.
### CD13 — Delivered (courier)
- **What’s happening:** Courier confirms COD collected or prepaid delivered.
- **Example:** Delivered 3pm; gross COD 2,500.
- **Who:** Dropship desk · Curia · Treasury / Cashier / Finance
- **Need in product:** Consignment delivered → finance settle path (money **CU2**, shop **DS6**).
- **Cover?:** Must
- **Watch out:** Tracking ≠ remittance posted.
### CD14 — Returned / refused
- **What’s happening:** End customer refused or unreachable.
- **Example:** Return after 2 attempts; return fee per table.
- **Who:** Dropship desk · Warehouse / Inventory Manager · Curia · Dropshipper · End customer
- **Need in product:** Returned status; restock/damage (shop **DS9**); phone stats worsen for CD1.
- **Cover?:** Must
- **Watch out:** Fees + stock path.
### CD15 — Tracking mismatch dispute
- **What’s happening:** Courier says delivered; customer denies.
- **Example:** Ticket with consignment id + timeline + raw events.
- **Who:** Dropship desk · Approver / Manager · Curia · End customer · Dropshipper
- **Need in product:** Dispute ref; freeze reseller payout until resolved.
- **Cover?:** Should
- **Watch out:** Keep raw payloads.
### CD16 — Batch remittance from courier
- **What’s happening:** Lump sum for many parcels; reconcile per order.
- **Example:** 20 orders; gross 200k; fees 10k; net 190k → money **R9**, **CU2**.
- **Who:** Treasury / Cashier / Finance · Dropship desk · Curia
- **Need in product:** Each order net ties to consignment COD + fees.
- **Cover?:** Must
- **Watch out:** Detail in money catalog — order by order.

### 3.5 Failures and redispatch

### CD17 — API failure at dispatch
- **What’s happening:** Courier rejects: bad address, duplicate, COD over limit.
- **Example:** Pathao error invalid thana.
- **Who:** Dropship desk · Curia · Approver / Manager
- **Need in product:** Error on consignment; fix CD3 and retry CD6 or switch provider with approval.
- **Cover?:** Must
- **Watch out:** Do not fake success.
### CD18 — Cancel consignment before pickup
- **What’s happening:** Order cancelled while still at warehouse.
- **Example:** Recipient cancelled on call (shop **DS3**).
- **Who:** Dropship desk · Curia · Dropshipper · End customer
- **Need in product:** Void with courier if created; cancel order with reason.
- **Cover?:** Must
- **Watch out:** No orphan live consignment.
### CD19 — Redispatch after return
- **What’s happening:** Second attempt; new consignment.
- **Example:** First return; new attempt with corrected phone.
- **Who:** Dropship desk · Approver / Manager · Curia · Dropshipper
- **Need in product:** New row; old superseded — never two active IDs.
- **Cover?:** Must
- **Watch out:** One live consignment.

### 3.6 Provider notes

| Provider | Staff remember |
| :--- | :--- |
| **Steadfast** | Common outside Dhaka; tracking uses consignment/AWB |
| **Pathao** | Strong urban; check district/thana formatting |
| **RedX** | Tiered return policy — read return fee on master row |

Fee numbers live in **courier master** — this catalog does not fix rates.

---

## 4. Quick-ref

| ID | One-line | Who (short) | Cover? |
| :--- | :--- | :--- | :--- |
| CD1–CD2 | Phone COD history / unknown | Dropship desk, Approver | Must |
| CD3–CD4 | Address/zone + pick ready | Dropship desk, Fulfillment | Must |
| CD5–CD6 / CD8 | Provider + consign + pickup | Dropship desk, Curia | Must |
| CD7 | Manual AWB | Dropship desk | Should |
| CD10 | Internal ship (money) | Finance → money/shop | Must |
| CD11 | Order of dispatch vs ship | Approver | Should |
| CD12–CD14 | Track / deliver / return | Dropship desk, Curia | Must |
| CD15 | Dispute | Dropship desk, Approver | Should |
| CD16 | Remittance batch | Finance → money | Must |
| CD17–CD19 | API fail / cancel / redispatch | Dropship desk, Curia | Must |

---

## 5. Remember

1. Three couriers, one playbook — same steps, different fee row.
2. Send to courier ≠ internal ship.
3. Tracking ≠ money — remittance still rules cash (money catalog).
4. Phone history guides risk — unknown is not green.
5. One live consignment per order.
6. COD face = end customer; B2B invoice = dropshipper (money **T1**).
7. Returns worsen next **CD1** score.
8. Shop lifecycle **DS3–DS8**; money **CU2** / **T1**.

---

## 6. Glossary

| Term | Meaning |
| :--- | :--- |
| **Consignment** | Courier booking for one parcel |
| **Tracking / AWB** | Public tracking number |
| **COD face** | Amount end customer pays on delivery |
| **Forward / return charge** | Fee for success vs return |
| **Remittance** | Courier pays us net COD after fees |
| **Delivery success ratio** | Delivered ÷ (delivered + returned) for a phone |
| **Normalized status** | Our common labels mapped from each provider |
| **Superseded consignment** | Old booking replaced by redispatch |
| **Internal ship** | Supply invoice + courier AP — not the van |

COD / remittance detail → [money-flow-guide.md](money-flow-guide.md).  
Dropship order life → [shop-and-orders-guide.md](shop-and-orders-guide.md).
