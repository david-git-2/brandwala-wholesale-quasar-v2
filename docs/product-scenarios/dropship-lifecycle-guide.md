# Dropship lifecycle

Product-decision catalog for the **full COD dropship order life**: supplier → dropshipper → end customer → Curia remittance → payout, plus failed delivery and post-delivery returns.  
**Pairs with:** [roles.md](roles.md) · [shop-and-orders-guide.md](shop-and-orders-guide.md) (**DS***) · [courier-dispatch-guide.md](courier-dispatch-guide.md) (**CD***) · [money-flow-guide.md](money-flow-guide.md) (**CU***, **T1**, **S6**, **S10**) · [decision board](money-flow-pnl-product-review.md).

> **We are the supplier (tenant).** Dropshipper = our customer. End customer = dropshipper’s buyer. Curia = last-mile + COD. Our revenue = **supply invoice**, not end-customer COD face.

---

## 1. Plain words + one running example

**Order ORD-8842** — dropshipper **Karim Reseller**, end customer **Rina**, 1× serum SKU.

| Field | Amount (BDT) | Who cares |
| :--- | ---: | :--- |
| End customer COD face | 25,000 | Dropshipper’s resale; Curia collects |
| Our supply invoice (at ship) | 18,000 | **Our revenue** (AR to Karim) |
| Curia forward + COD fee (est.) | 1,000 | Courier AP; deducted from remittance |
| Karim’s gross margin on paper | 7,000 | 25,000 − 18,000 (before courier) |
| Net to Karim after remittance | 6,000 | 25,000 − 18,000 − 1,000 Curia fee |

### Path A — Happy path (DL1–DL7)

| Step | What happens | Example numbers |
| :--- | :--- | :--- |
| DL1 | Karim orders; enters Rina, phone, Dhaka address, sell 25k | Min sell met; order **confirmed** |
| DL2 | Desk calls Rina; she confirms | **processing** |
| DL3 | Pick 1 unit; no gift | COGS on our stock only |
| DL4 | Steadfast consignment SF-991; ship issues invoice | AR Karim **18,000**; courier AP **~1,000** |
| DL5 | Curia delivered; COD **25,000** collected | Settlement sheet matches |
| DL6 | Curia remits **24,000** net | Clear AR **18,000** → wallet **+6,000** |
| DL7 | Finance pays Karim **6,000** | Payout; not a new invoice |

### Path B — Not received / refused (DL10–DL14)

Same order through **DL4** (invoice **18,000** issued). Rina unreachable twice (**DL10**). Third attempt: refused (**DL11**). Parcel back (**DL13**); sellable restock.

| Money | BDT | Note |
| :--- | ---: | :--- |
| COD remittance | 0 | Never delivered |
| Credit supply invoice | −18,000 | Full credit note on issued AR |
| Return fee (Curia) | 120 | Charged to **Karim** by default |
| Karim wallet profit | 0 | No remittance → no profit |

Optional **DL15**: Karim fixes phone; **new** consignment supersedes SF-991; Path A can run again on attempt 2.

### Path C — Delivered, then return (DL20–DL23)

Path A through **DL6** (wallet **6,000**, not yet paid out). Day 5: Rina returns sealed box (**DL20**). Inspection sellable (**DL21** N/A).

| Money | BDT | Note |
| :--- | ---: | :--- |
| Credit note on supply | −18,000 | Reverses our sale |
| Wallet adjustment | −6,000 | **DL22** — hold/reduce before payout |
| Restock | 1 unit | Main stock |

If **DL7** already paid **6,000** to Karim (**DL23**): same credit **18,000**; clawback **6,000** from wallet or next remittance offset.

Money detail → [money-flow-guide.md](money-flow-guide.md). Consignment detail → [courier-dispatch-guide.md](courier-dispatch-guide.md). Shop setup steps → [shop-and-orders-guide.md](shop-and-orders-guide.md) §3.4.

---

## 2. Locked rules

1. **Supplier** = tenant; **dropshipper** = customer profile on shop; **end customer** = recipient on order (not our AR party).
2. **Supply invoice** = our revenue; **COD face** = clearing only until remittance (**T1**, **CU2**).
3. **Tracking ≠ money.** Courier “delivered” does not replace finance settle.
4. **One active consignment** per order; redispatch supersedes old (**CD19**).
5. **Failed delivery / return-to-warehouse** → restock or write-off; reverse supply settle; **return fee → dropshipper** unless tenant waives (**CU4**, **S10**).
6. **Delivered return** = after-sales RMA — do not reuse failed-delivery cancel as the only path.
7. **Remittance** clears dropshipper AR first; remainder = profit liability in cashbook (**DS7**, **DS8**).
8. Never purge live financial history on cancel or return.
9. Phone COD history feeds next-order risk (**CD1**).
10. Who names: [roles.md](roles.md) only.

---

## 3. Scenarios we may cover

### 3.1 Happy path

### DL1 — Dropshipper order with end-customer details
- **What’s happening:** Dropshipper checks out at wholesale; must supply recipient name, phone, address, end price (≥ minimum sell).
- **Example:** ORD-8842: Karim → Rina, Mirpur; wholesale **18,000**; sell **25,000**; **confirmed** pending call.
- **Who:** Dropshipper · End customer · Dropship desk
- **Need in product:** Mandatory recipient fields; order tied to dropshipper customer profile.
- **Cover?:** Must
- **Watch out:** End customer is not our invoice party. → shop **DS1**

### DL2 — Recipient verification call
- **What’s happening:** Staff call end customer before pick when policy requires.
- **Example:** ORD-8842: Rina confirms → **processing**. Alt: no answer → attempt **2**; still **confirmed**. Alt: cancel → “wrong number” → **DL33**.
- **Who:** Dropship desk · End customer · Dropshipper
- **Need in product:** Call outcomes; block processing until verified when gated.
- **Cover?:** Must
- **Watch out:** Fraud / waste control. → **DS3**, **DL33**

### DL3 — Pick and gifts
- **What’s happening:** Warehouse pick at processing; optional gifts (our stock or dropshipper stock).
- **Example:** ORD-8842: 1 pick serum. Alt order: 3 picks + gift sachet **200** on Karim’s bill; COD face still **25,000** (gift not on end receipt).
- **Who:** Fulfillment · Warehouse / Inventory Manager · Dropship desk · Dropshipper
- **Need in product:** Picks on order lines; gift source and charge rules.
- **Cover?:** Must
- **Watch out:** Reseller-provided gifts ≠ our COGS. → **DS4**

### DL4 — Send to Curia and internal ship
- **What’s happening:** Consignment created; internal ship issues supply invoice to dropshipper and courier AP.
- **Example:** ORD-8842: SF-991; issued AR Karim **18,000**; courier AP **1,000** (forward 120 + COD fee); packing slip shows Rina **25,000** COD only.
- **Who:** Dropship desk · Fulfillment · Treasury / Cashier / Finance · Curia · Dropshipper
- **Need in product:** Consignment + ship/issue in one coherent timeline.
- **Cover?:** Must
- **Watch out:** Send to courier ≠ internal ship. → **CD6**, **CD10**, **DS5**, **T1**

### DL5 — Delivered and COD collected
- **What’s happening:** Curia marks delivered (`shipped` → `delivered`) when the parcel is delivered — **status only**, not remittance. COD collected (or prepaid delivered) is a separate fact. Finance settlement sheet **Save** may adjust actual vs planned COD/delivery **before** courier pay in / remittance.
- **Example:** ORD-8842: planned COD **25,000**; Curia collected **24,000** → debit note **1,000** on clearing; supply invoice **18,000** unchanged.
- **Who:** Dropship desk · Curia · Treasury / Cashier / Finance · Dropshipper
- **Need in product:** Delivered path → remittance-ready; debit/credit notes if issued wrong.
- **Cover?:** Must
- **Watch out:** Tracking event only until remittance posted. → **CD13**, **DS6**

### DL6 — Curia remittance, clear AR, profit wallet
- **What’s happening:** Net COD pay-in; clear dropshipper supply invoice; remainder credits dropshipper profit balance.
- **Example:** ORD-8842 Path A: pay-in **24,000**; allocate **18,000** AR Karim; **6,000** to Karim profit wallet (25k − 18k − 1k fee).
- **Who:** Dropship desk · Treasury / Cashier / Finance · Curia · Dropshipper
- **Need in product:** Order-by-order remittance allocate; preview before post.
- **Cover?:** Must
- **Watch out:** Gross COD ≠ our revenue. → **CU2**, **DS7**, **S6**, **R9**

### DL7 — Pay dropshipper profit
- **What’s happening:** Cash out profit we held — not a second sales invoice.
- **Example:** ORD-8842: `dispense_middleman_payout` **6,000** BDT to Karim MFS; wallet **0**; remittance history kept.
- **Who:** Treasury / Cashier / Finance · Approver / Manager · Dropshipper
- **Need in product:** Payout from cashbook + statement.
- **Cover?:** Must
- **Watch out:** Payout is liability discharge, not new revenue. → **DS8**

### 3.2 Not received / failed delivery

### DL10 — End customer unreachable (in transit)
- **What’s happening:** Courier attempts delivery; phone off or not home; parcel still in network.
- **Example:** ORD-8842: attempt 1 (phone off), attempt 2 (not home); SF-991 still in transit; COD 25k not collected; AR 18k already issued — finance waits.
- **Who:** Dropship desk · Curia · End customer · Dropshipper
- **Need in product:** Timeline events; optional retry policy; no fake “delivered.”
- **Cover?:** Must
- **Watch out:** Issued supply invoice may already exist — money still waits on outcome.

### DL11 — Refused or “not received” after attempts → returned
- **What’s happening:** End customer refuses parcel or cannot be reached per courier rules; parcel returns to hub/warehouse.
- **Example:** ORD-8842 attempt 3: Rina refuses; status **returned**; Curia return fee **120 BDT** (forward 120 already on AP from ship).
- **Who:** Dropship desk · Warehouse / Inventory Manager · Curia · Dropshipper · End customer
- **Need in product:** Consignment returned status; trigger receive + money reverse path.
- **Cover?:** Must
- **Watch out:** Worsen phone COD score for **CD1**. → **CD14**, **CU4**

### DL12 — Wrong or fake address → return
- **What’s happening:** Address undeliverable; courier returns parcel.
- **Example:** Order ORD-7701: thana “Mirpur-99” invalid; return day 2; COD **0**; same money path as DL11 (credit 18k supply + fee to Karim).
- **Who:** Dropship desk · Curia · Dropshipper · End customer
- **Need in product:** Same return path as DL11; address quality at order entry.
- **Cover?:** Must
- **Watch out:** Fix data before **DL15** redispatch.

### DL13 — Parcel back: inspect, restock or write-off
- **What’s happening:** Warehouse receives return; grade condition.
- **Example:** ORD-8842 serum: box sealed → **sellable** restock qty +1. Contrast ORD-7701 crushed box → **damaged** grade, no main-shelf restock.
- **Who:** Warehouse / Inventory Manager · Fulfillment · Dropship desk
- **Need in product:** Return inbound movement; inspection outcome on case/order.
- **Cover?:** Must
- **Watch out:** Open packaging may downgrade sellability.

### DL14 — Money on failed delivery
- **What’s happening:** No COD remittance; credit/reverse supply invoice path; charge return + forward fees to dropshipper (default); no profit payout.
- **Example:** ORD-8842 Path B: credit note **−18,000** on Karim AR; debit Karim **120** return fee; tenant cash **0** in; courier AP settled from retention; Karim wallet stays **0** (never remitted).
- **Who:** Dropship desk · Treasury / Cashier / Finance · Dropshipper · Curia
- **Need in product:** Reverse settle distinct from remittance; fee bearer = dropshipper unless waived.
- **Cover?:** Must
- **Watch out:** Do not leave orphan wallet profit. → **CU4**, **S10**

### DL15 — Redispatch after return
- **What’s happening:** Dropshipper wants second attempt; new consignment; old superseded.
- **Example:** ORD-8842: SF-991 superseded; new phone; SF-992; second forward fee **120** (policy: Karim pays again); if delivered, Path A remittance on **one** active consignment only.
- **Who:** Dropship desk · Approver / Manager · Curia · Dropshipper
- **Need in product:** Link attempts; supersede prior consignment.
- **Cover?:** Must
- **Watch out:** Second forward fee policy clear. → **CD19**

### DL16 — Cancel after ship, before Curia pickup
- **What’s happening:** Order cancelled while parcel still at warehouse or before network pickup.
- **Example:** ORD-5510: Rina cancels on call **after** AR **22,000** issued but **before** SF pickup — void SF draft; credit **−22,000**; restock pick; cancel reason on order for Karim.
- **Who:** Dropship desk · Curia · Dropshipper · End customer · Treasury / Cashier / Finance
- **Need in product:** Void courier booking + reverse issued bills if needed.
- **Cover?:** Must
- **Watch out:** No orphan live consignment. → **CD18**, **DS9**

### 3.3 Post-delivery return

### DL20 — Change-of-mind within return window
- **What’s happening:** End customer returns after successful delivery; dropshipper initiates or approves; policy window applies.
- **Example:** ORD-8842 Path C: delivered day 0; RMA day 5; policy **7 days**; sealed serum; case links order + invoice **18,000**.
- **Who:** Dropship desk · Dropshipper · End customer · Support · Warehouse / Inventory Manager
- **Need in product:** After-sales case linked to shop order + supply invoice.
- **Cover?:** Must
- **Watch out:** Not the same workflow as DL11 (parcel never delivered).

### DL21 — DOA / defective / wrong item
- **What’s happening:** Product fault or wrong SKU shipped; faster path; may waive restocking.
- **Example:** ORD-6602: wrong shade shipped; DOA policy — credit **full 12,000** supply; restocking fee **waived**; received unit **scrap** (leaker).
- **Who:** Support · Warehouse / Inventory Manager · Sales manager · Dropshipper
- **Need in product:** Policy program snapshot on case (DOA / warranty).
- **Cover?:** Must
- **Watch out:** Inspection before credit finalize.

### DL22 — Return after remittance, before payout
- **What’s happening:** COD already cleared; profit in wallet unpaid; return approved.
- **Example:** ORD-8842 Path C: credit **−18,000**; wallet **6,000 → 0**; payout blocked; restock +1 serum sellable.
- **Who:** Treasury / Cashier / Finance · Dropship desk · Dropshipper · Support
- **Need in product:** Credit note + wallet adjust; block payout until case closed.
- **Cover?:** Must
- **Watch out:** AR may already be zero — wallet is the clawback surface.

### DL23 — Return after payout
- **What’s happening:** Dropshipper already received profit cash; return approved later.
- **Example:** ORD-8842 if **DL7** paid first: credit **−18,000**; recovery **−6,000** from Karim (wallet debit or offset ORD-8843 remittance); payout row not deleted.
- **Who:** Treasury / Cashier / Finance · Credit Controller · Dropshipper · Support
- **Need in product:** Negative wallet / recovery trail; do not delete payout history.
- **Cover?:** Must
- **Watch out:** May need approver for write-off of unrecoverable clawback.

### DL24 — Outside return window → reject RMA
- **What’s happening:** Request past policy; staff reject with reason.
- **Example:** ORD-8842 if RMA day 30 with **7-day** policy — case **rejected**; Karim keeps **6,000** wallet; no credit note.
- **Who:** Support · Sales manager · Dropshipper
- **Need in product:** Policy dates on case; reject reason visible to dropshipper.
- **Cover?:** Should
- **Watch out:** Exceptions need approver, not silent override.

### DL25 — Delivered dispute (customer denies receipt)
- **What’s happening:** Curia says delivered; end customer denies; dropshipper disputes payout.
- **Example:** ORD-8842: Curia POD “delivered”; Rina denies; remittance **24,000** posted but payout **6,000 frozen**; dispute ticket **DSP-8842** + SF-991 webhook JSON.
- **Who:** Dropship desk · Approver / Manager · Curia · Dropshipper · End customer
- **Need in product:** Dispute flag; payout hold until resolved.
- **Cover?:** Should
- **Watch out:** → **CD15**

### 3.4 Other cases

### DL30 — COD short or over on remittance
- **What’s happening:** Curia remits ≠ expected net COD.
- **Example:** ORD-8842 batch: expect **24,000** net; bank **23,500** → **500** short; Karim wallet **+5,500** not **+6,000** unless tenant absorbs (approver).
- **Who:** Dropship desk · Treasury / Cashier / Finance · Curia
- **Need in product:** Variance line + approval if absorb short.
- **Cover?:** Must
- **Watch out:** → **CU3**

### DL31 — Lost or damaged in Curia custody
- **What’s happening:** Parcel lost in network or destroyed; no return goods.
- **Example:** ORD-3300: lost in hub; supply **15,000** credited to dropshipper; stock write-off **1 unit @ 9,000** COGS; Curia claim **8,000** pending — no restock (**DL13** N/A).
- **Who:** Dropship desk · Approver / Manager · Curia · Treasury / Cashier / Finance · Dropshipper
- **Need in product:** Loss case; insurance/claim ref optional; stock write-off.
- **Cover?:** Should
- **Watch out:** No restock if goods never came back.

### DL32 — Advance + COD on same order
- **What’s happening:** Dropshipper prepaid part; balance on COD; one settle story.
- **Example:** ORD-9001: Karim advance **5,000** at order; COD face **20,000**; fee **1,000**; net remit **19,000**; supply **18,000**; wallet **+1,000** (19k − 18k; advance separate).
- **Who:** Dropship desk · Treasury / Cashier / Finance · Curia · Dropshipper
- **Need in product:** Advance + remittance on one order.
- **Cover?:** Must
- **Watch out:** Pointer only — full example **S6**, **CU6**.

### DL33 — Cancel before pick or on verification call
- **What’s happening:** Order never enters processing; or cancelled when recipient refuses on call.
- **Example:** ORD-8842 alt on **DL2**: cancel “customer changed mind” while still **confirmed** — no pick, no AR; Karim sees reason on shop order.
- **Who:** Dropship desk · Dropshipper · End customer
- **Need in product:** Cancel reason; no ship/issue if never processed.
- **Cover?:** Must
- **Watch out:** → **DS3**, **DS9**

### DL34 — Hold payout until return window closes
- **What’s happening:** Tenant policy delays dropshipper profit payout after remittance.
- **Example:** ORD-8842 Path A + policy: remittance day 0 wallet **6,000**; payout button disabled until day **8** (7-day return window).
- **Who:** Approver / Manager · Treasury / Cashier / Finance · Dropshipper
- **Need in product:** Payout gate date per policy program.
- **Cover?:** Should
- **Watch out:** Wallet balance visible; payout action blocked until date.

### DL35 — Prepaid end customer (no COD)
- **What’s happening:** End customer paid dropshipper online; parcel is not COD.
- **Example:** Hypothetical: sell **0** COD; courier charge **120** prepaid by Karim — no **CU2** row; not in v1 COD playbook.
- **Who:** Dropship desk · Curia · Dropshipper
- **Need in product:** — 
- **Cover?:** Out
- **Watch out:** v1 playbook is COD-first; prepaid needs separate settle design.

### DL36 — End customer pays dropshipper directly (no Curia COD)
- **What’s happening:** We fulfill but never touch end-customer cash.
- **Example:** Karim sells **25,000** bKash to Rina; we ship and invoice Karim **18,000** on **30-day credit** — no Curia remittance path.
- **Who:** Dropshipper · Treasury / Cashier / Finance
- **Need in product:** —
- **Cover?:** Out
- **Watch out:** Breaks remittance clearing model — not default BW dropship.

---

## 4. Quick-ref

| ID | One-line | Example (BDT unless noted) | Who (short) | Cover? |
| :--- | :--- | :--- | :--- | :--- |
| DL1 | Order + recipient | COD 25k / supply plan 18k (ORD-8842) | Dropshipper, Dropship desk | Must |
| DL2 | Verify call | Rina confirms → processing | Dropship desk, End customer | Must |
| DL3 | Pick / gifts | 1 pick; gift +200 to Karim optional | Fulfillment, Dropship desk | Must |
| DL4 | Curia + internal ship | AR 18k + AP ~1k; SF-991 | Dropship desk, Finance, Curia | Must |
| DL5 | Delivered + COD | COD 25k collected | Dropship desk, Curia, Finance | Must |
| DL6 | Remittance → wallet | Net 24k in; wallet +6k | Finance, Dropship desk, Curia | Must |
| DL7 | Profit payout | Pay Karim 6k | Finance, Dropshipper | Must |
| DL10 | Unreachable in transit | 2 attempts; no remit | Dropship desk, Curia | Must |
| DL11 | Refused → returned | 3rd attempt refuse; fee 120 | Dropship desk, Warehouse, Curia | Must |
| DL12 | Bad address return | ORD-7701; COD 0 | Dropship desk, Curia | Must |
| DL13 | Inspect / restock | Sealed +1 sellable vs damaged scrap | Warehouse, Fulfillment | Must |
| DL14 | Failed-delivery money | Credit −18k; fee 120 Karim | Finance, Dropship desk, Dropshipper | Must |
| DL15 | Redispatch | SF-992 replaces SF-991 | Dropship desk, Curia | Must |
| DL16 | Cancel before pickup | Credit −22k ORD-5510 | Dropship desk, Curia, Finance | Must |
| DL20 | Post-delivery return | RMA day 5; window 7d | Support, Dropshipper | Must |
| DL21 | DOA / wrong item | Credit 12k; scrap unit | Support, Warehouse | Must |
| DL22 | Return before payout | Wallet −6k; credit −18k | Finance, Dropship desk | Must |
| DL23 | Return after payout | Clawback 6k after paid | Finance, Credit Controller | Must |
| DL24 | Reject late RMA | Day 30 vs 7d policy | Support | Should |
| DL25 | Delivered dispute | Freeze 6k payout | Dropship desk, Approver | Should |
| DL30 | COD short/over | Expect 24k; get 23.5k | Finance, Dropship desk | Must |
| DL31 | Lost in Curia | Write-off 9k COGS; credit 15k | Dropship desk, Approver | Should |
| DL32 | Advance + COD | Adv 5k + COD 20k; supply 18k | Finance, Dropship desk | Must |
| DL33 | Early cancel | No invoice; cancel reason | Dropship desk, Dropshipper | Must |
| DL34 | Delayed payout policy | Payout day 8 | Finance, Approver | Should |
| DL35 | Prepaid end customer | COD 0 | — | Out |
| DL36 | No Curia COD | MFS to Karim only | — | Out |

---

## 5. Remember

1. Three parties: supplier (us), dropshipper (customer), end customer (recipient).
2. Happy path: call → pick → Curia → ship/issue → deliver → remittance → payout (**DL1–DL7**).
3. Failed delivery: return goods → restock → reverse supply + return fee on dropshipper (**DL10–DL16**).
4. Delivered return: after-sales RMA — separate from failed delivery (**DL20–DL23**).
5. Tracking ≠ money until remittance or reverse settle posts.
6. One live consignment; redispatch supersedes.
7. Never purge financial history.
8. Money math lives in money catalog; consignment in courier catalog.

---

## 6. Glossary

| Term | Meaning |
| :--- | :--- |
| **Supply invoice** | Our B2B bill to dropshipper at ship (our revenue) |
| **COD face** | Amount end customer pays on delivery (clearing only) |
| **Remittance** | Curia pays us net COD after fees |
| **Profit wallet** | Dropshipper balance after AR cleared from remittance |
| **Failed delivery** | Parcel never successfully delivered; returned in network |
| **Post-delivery return** | Delivered first; goods come back under RMA |
| **Internal ship** | Issue supply invoice + courier AP — finance step |
| **Return fee** | Curia charge on failed delivery — dropshipper pays by default |
| **Clawback** | Recover paid profit after late return |
| **Superseded consignment** | Old booking replaced on redispatch |

Shop steps **DS*** · Courier **CD*** · Money **CU***, **T1**, **S10** → linked catalogs above.