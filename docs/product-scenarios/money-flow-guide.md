# Money flow

Product-decision catalog for **bills, cash, channels, COD clearing, and batch profit**.  
**Pairs with:** [roles.md](roles.md) · [investor-shipment-guide.md](investor-shipment-guide.md) (capital + profit share) · [shipment-guide.md](shipment-guide.md) · [courier-dispatch-guide.md](courier-dispatch-guide.md) · [decision board](money-flow-pnl-product-review.md).

> We are the **supplier/fulfiller to dropshippers** — not a dropshipper without stock. Dropshippers sell using **our stock**. Our revenue is the **supply invoice**, not end-customer COD.

---

## 1. Plain words + one running idea

> **We buy → store/ship → sell three ways → collect → pay everyone.**

| Channel | Meaning | Example |
| :--- | :--- | :--- |
| **Wholesale** | Bulk to businesses, often credit | Shop orders 500 units; pays in 30 days |
| **Retail** | Walk-in / till; cash, card, MFS | Customer buys 2 units |
| **Dropship supply** | Dropshipper sells our stock; we fulfill; Curia may collect COD; we settle net | End customer 1,000; our invoice 700; Curia fee 50; remit 250 to dropshipper |

Base currency **BDT**; GBP/USD common. Investor capital + profit share lives in the **investor catalog** — short hooks only here (SH3 / SH4).

---

## 2. Locked rules

1. Every money move: who, direction, currency + amount, rate, BDT, date, method, reference, open item, channel.
2. Multi-currency: original + BDT + rate; FX gain/loss on settle and month-end.
3. Partial pays normal; keep open items clean. Deposits/credits are **liabilities**, not revenue.
4. No cross-currency netting without documented FX + approval.
5. Segregation of duties: requester ≠ approver ≠ payer; dual approve vendor bank changes.
6. Dropshipper stock is **our** inventory. Our revenue = supply invoice. End-customer cash = clearing until settle. Track per order: end price, supply invoice, fees, net to/from dropshipper.
7. Landed (shelf) cost = price + freight + customs + insurance we capitalize; split shared bills with a written basis. Non-shelf fees hit shipment profit, not unit cost. Prefer oldest stock; average only if policy says so.
8. Tag shipment on buy/cost lines; on sales when stock link is known. Shipment profit ≠ investor return; also use channel, order, and month views — do not add them as separate piles of profit.
9. **Investor model:** capital + profit share (investor catalog). Not interest. Pay-out only after sold + cash ready.
10. If a money case is not listed here (or pointed to another catalog), we have not decided to handle it.

Who names: [roles.md](roles.md) only.

---

## 3. Scenarios we may cover

### 3.1 Treasury (our wallet / bank)
### D1 — Deposit / withdraw own wallet
- **What’s happening:** Move money in/out of our own account.
- **Example:** Deposit 50,000; withdraw 10,000.
- **Who:** Treasury / Cashier / Finance · Bank
- **Need in product:** Cash movement with no revenue/expense.
- **Cover?:** Must
- **Watch out:** Not a sale or cost.
### D2 — FX convert + bank charge
- **What’s happening:** Convert currency; bank fee separate.
- **Example:** 120,000 BDT → 1,000 USD @120; fee 500.
- **Who:** Treasury / Cashier / Finance · Bank
- **Need in product:** FX + fee as separate lines.
- **Cover?:** Must
- **Watch out:** Never bury fee inside the rate.
### S1 — Cash position by channel
- **What’s happening:** Day-end tally by channel vs counted cash.
- **Example:** Retail 20k cash + 35k card; count 19,800 → 200 short.
- **Who:** Treasury / Cashier / Finance · Sales / Channel Manager
- **Need in product:** Channel cash reconcile; COD from Curia is clearing.
- **Cover?:** Must
- **Watch out:** Dropship COD ≠ our revenue.
### R1 — Bank loan drawdown / repay
- **What’s happening:** Borrow from bank; repay principal + interest.
- **Example:** Draw 2M @9%; interest ~15k; principal 100k.
- **Who:** Treasury / Cashier / Finance · Lender
- **Need in product:** Loan liability; interest ≠ principal.
- **Cover?:** Must
- **Watch out:** Not our shipment investor model.
### R2 — Gateway settle + fee + chargeback
- **What’s happening:** Gateway takes fee, settles net; chargeback reopens debt.
- **Example:** 100k sales; 2.5% fee; later 5k chargeback.
- **Who:** Treasury / Cashier / Finance · Payment Gateway / MFS · Customer
- **Need in product:** Gross sale; fee expense; chargeback reopens receivable.
- **Cover?:** Must
- **Watch out:** Fee and chargeback are separate.
### R3 — MFS settlement
- **What’s happening:** bKash/Nagad settle next day with fee.
- **Example:** 3,000 pay; settle 2,955 (fee 45).
- **Who:** Treasury / Cashier / Finance · Payment Gateway / MFS
- **Need in product:** Sale gross; fee separate; bank credit.
- **Cover?:** Must
- **Watch out:** Same pattern as gateway.
### R4 — Petty cash top-up
- **What’s happening:** Custodian float; refill after receipts.
- **Example:** Float 5k; spent 3,200; 50 variance.
- **Who:** Petty Cash Custodian · Treasury / Cashier / Finance
- **Need in product:** Float + receipts + small variance.
- **Cover?:** Must
- **Watch out:** Receipts or expense.

### 3.2 Vendors (payables)

### V1 — Split-FX vendor payment
- **What’s happening:** Pay one bill in parts at different rates.
- **Example:** 100 GBP: 60@166 + 40@169 = 16,720 BDT.
- **Who:** AP Clerk · Treasury / Cashier / Finance · Vendor
- **Need in product:** Each payment keeps its own rate.
- **Cover?:** Must
- **Watch out:** Do not fake one average rate only.
### V2 — Vendor refund different rate
- **What’s happening:** Refund when FX moved.
- **Example:** Refund 40 GBP @170 vs paid @169 → FX gain.
- **Who:** AP Clerk · Treasury / Cashier / Finance · Vendor
- **Need in product:** Link refund; post FX.
- **Cover?:** Must
- **Watch out:** FX on refund is real P&L.
### V3 — Vendor prepay
- **What’s happening:** Pay before bill.
- **Example:** Prepay 500 USD; bill 800; 300 remains.
- **Who:** AP Clerk · Treasury / Cashier / Finance · Vendor
- **Need in product:** Advance open item until bill.
- **Cover?:** Must
- **Watch out:** Advance ≠ expense.
### V4 — Purchase return / credit
- **What’s happening:** Return or discount reduces payable.
- **Example:** Bill 1,000 USD; credit 200.
- **Who:** Receiver · AP Clerk · Vendor
- **Need in product:** Credit note + inventory adjust.
- **Cover?:** Must
- **Watch out:** Stock must match credit.
### V5 — Pay USD bill in BDT
- **What’s happening:** Settle foreign payable in BDT.
- **Example:** 100 USD payable @122 vs pay @125 → FX loss 300.
- **Who:** Treasury / Cashier / Finance · Vendor
- **Need in product:** Settle + FX difference.
- **Cover?:** Must
- **Watch out:** Record FX, not silent mix.
### S2 — Payment run + freight to landed cost
- **What’s happening:** Batch-pay vendors; put freight into shelf cost by channel.
- **Example:** Pay 500k bills; freight 5k split wholesale/dropship.
- **Who:** AP Clerk · Treasury / Cashier / Finance · Approver / Manager
- **Need in product:** Payment run + landed-cost allocation.
- **Cover?:** Must
- **Watch out:** Freight channel split documented.
### R5 — Vendor consignment
- **What’s happening:** Vendor owns stock; we pay when sold.
- **Example:** 50 units in; sell 30; pay for 30.
- **Who:** Warehouse / Inventory Manager · AP Clerk · Vendor
- **Need in product:** Consignment memo; payable on sale.
- **Cover?:** Should
- **Watch out:** Not our inventory until sold.
### R6 — Import purchase (duty + import VAT)
- **What’s happening:** FOB + freight + customs + import VAT.
- **Example:** FOB 5k USD; freight 500; customs 80k; VAT 120k.
- **Who:** AP Clerk · Cargo Company · Customs Authority · Tax Authority · Vendor
- **Need in product:** Duty → landed cost; import VAT = input tax.
- **Cover?:** Must
- **Watch out:** Do not lump VAT into shelf cost.

### 3.3 Customers (receivables)

### C1 — Owe customer multi-currency
- **What’s happening:** Customer credit/deposit in more than one currency.
- **Example:** Owe 2,000 BDT and 100 USD separately.
- **Who:** Credit Controller · Treasury / Cashier / Finance · Customer
- **Need in product:** Deposit liability per currency.
- **Cover?:** Must
- **Watch out:** Never net currencies.
### C2 — Deposit + partials vs many bills
- **What’s happening:** Allocate receipts FIFO across invoices.
- **Example:** 60k due; 35k received → 25k open on last invoice.
- **Who:** Credit Controller · Treasury / Cashier / Finance · Customer
- **Need in product:** Allocation + open items; cheque clears when bank confirms.
- **Cover?:** Must
- **Watch out:** Unallocated cash sits as deposit.
### C3 — Overpay + refund
- **What’s happening:** Excess becomes deposit then refund.
- **Example:** Invoice 10k; pay 12k; refund 2k.
- **Who:** Credit Controller · Treasury / Cashier / Finance · Customer
- **Need in product:** Excess = liability, not revenue.
- **Cover?:** Must
- **Watch out:** Refund from deposit.
### C4 — Bad debt write-off
- **What’s happening:** Give up on collecting.
- **Example:** 5k write-off with manager approval.
- **Who:** Credit Controller · Approver / Manager · Customer
- **Need in product:** Write-off expense + close receivable.
- **Cover?:** Must
- **Watch out:** Approval required.
### C5 — Card chargeback
- **What’s happening:** Bank reverses a card payment.
- **Example:** 10k sale reversed; fee possible.
- **Who:** Treasury / Cashier / Finance · Payment Gateway / MFS · Customer
- **Need in product:** Reverse receipt; reopen receivable.
- **Cover?:** Must
- **Watch out:** Link to original sale.
### C6 — BDT invoice paid in USD
- **What’s happening:** Foreign pay on local bill → over/under.
- **Example:** 100k BDT invoice; 1,000 USD@125 = 125k → 25k over.
- **Who:** Treasury / Cashier / Finance · Customer
- **Need in product:** Compare BDT invoice to FX receipt.
- **Cover?:** Must
- **Watch out:** Overpay ≠ auto revenue.
### S3 — Wholesale discount + credit limit
- **What’s happening:** Trade discount; block over credit limit.
- **Example:** 47,500 after 5%; limit 40k → breach.
- **Who:** Sales / Channel Manager · Credit Controller · Approver / Manager · Customer
- **Need in product:** Discount invoice + limit check + override trail.
- **Cover?:** Must
- **Watch out:** No silent over-limit.
### S4 — Retail daily reconcile
- **What’s happening:** Till cash/card vs expected.
- **Example:** Expected 20k cash; count 19.8k → 200 short.
- **Who:** Sales / Channel Manager · Treasury / Cashier / Finance
- **Need in product:** Daily summary + short/over.
- **Cover?:** Must
- **Watch out:** Channel on the day.
### S5 — Sales return by channel
- **What’s happening:** Return; refund or credit; restock.
- **Example:** Retail refund 2k; wholesale credit 5k.
- **Who:** Sales / Channel Manager · Warehouse / Inventory Manager · Customer
- **Need in product:** Return + restock + channel.
- **Cover?:** Must
- **Watch out:** Damaged ≠ clean restock without grade.
### S6 — Dropship advance + COD settle
- **What’s happening:** Advance + Curia COD; supply invoice; remit net to dropshipper.
- **Example:** End 25k; advance 5k; COD 20k; Curia fee 1k remits 19k; supply 18k; net to dropshipper 6k.
- **Who:** Dropship desk · Treasury / Cashier / Finance · Curia · Dropshipper
- **Need in product:** Per-order clearing; supply invoice = our revenue.
- **Cover?:** Must
- **Watch out:** Do not book 25k end price as our revenue.
### R7 — Credit limit breach hold
- **What’s happening:** New order while already at limit.
- **Example:** At 40k limit; new 15k; director override.
- **Who:** Credit Controller · Approver / Manager · Customer
- **Need in product:** Hold + written exception.
- **Cover?:** Must
- **Watch out:** No ship without approval.

### 3.4 Cargo

### CA1 — Freight invoice
- **What’s happening:** Cargo bills freight for a batch.
- **Example:** 15k freight for 100 units → prefer landed cost.
- **Who:** Shipping Coordinator · AP Clerk · Cargo Company
- **Need in product:** Freight into landed cost when capitalizing.
- **Cover?:** Must
- **Watch out:** Not always pure expense.
### CA2 — Cargo prepay
- **What’s happening:** Pay cargo before invoices.
- **Example:** Prepay 20k; invoice 12k; 8k credit left.
- **Who:** Treasury / Cashier / Finance · Cargo Company
- **Need in product:** Advance then allocate.
- **Cover?:** Must
- **Watch out:** Remaining is credit.
### CA3 — Cargo pays customs + recharge
- **What’s happening:** Cargo advances duty; adds fee.
- **Example:** Customs 8k + fee 500 = 8.5k recharge.
- **Who:** AP Clerk · Cargo Company · Customs Authority
- **Need in product:** Duty → cost; fee separate.
- **Cover?:** Must
- **Watch out:** Do not lump both.
### CA4 — Cargo damage claim
- **What’s happening:** Claim for damaged goods.
- **Example:** 3 units / 6k; cargo credits 6k.
- **Who:** Warehouse / Inventory Manager · Shipping Coordinator · Cargo Company
- **Need in product:** Claim + inventory write-off.
- **Cover?:** Must
- **Watch out:** Link to shipment.
### CA5 — Cargo insurance premium
- **What’s happening:** Insurance via cargo.
- **Example:** Premium 2k with freight.
- **Who:** Shipping Coordinator · Cargo Company · Insurance Company
- **Need in product:** Expense or landed cost per policy.
- **Cover?:** Must
- **Watch out:** Policy says capitalize or not.
### CA6 — Cargo statement reconcile
- **What’s happening:** Their statement vs ours.
- **Example:** They show 10 shipments; we show 9.
- **Who:** AP Clerk · Shipping Coordinator · Cargo Company
- **Need in product:** Reconcile before pay.
- **Cover?:** Must
- **Watch out:** Do not pay unresolved lines.
### R8 — Insurance claim received
- **What’s happening:** Insurer pays for loss.
- **Example:** Claim 5k received.
- **Who:** Treasury / Cashier / Finance · Insurance Company · Cargo Company
- **Need in product:** Claim income or offset write-off.
- **Cover?:** Should
- **Watch out:** Link shipment.

### 3.5 Curia (last-mile + COD)

### CU1 — Curia delivery fee
- **What’s happening:** Curia bills delivery for dropship fulfill.
- **Example:** Fee invoice 5k.
- **Who:** Dropship desk · AP Clerk · Curia
- **Need in product:** Delivery expense/payable; optional deduct from dropshipper.
- **Cover?:** Must
- **Watch out:** No downstream after we pay fee.
### CU2 — COD remittance
- **What’s happening:** Curia remits COD net of fee; we settle dropshipper.
- **Example:** COD 30k; fee 1.5k; remit 28.5k; supply 20k; net to dropshipper 8.5k.
- **Who:** Dropship desk · Treasury / Cashier / Finance · Curia · Dropshipper
- **Need in product:** Clearing receivable → cash; apply supply invoice.
- **Cover?:** Must
- **Watch out:** Gross COD ≠ our revenue.
### CU3 — COD short/over
- **What’s happening:** Remit ≠ expected COD.
- **Example:** Expect 28.5k; get 28k → 500 short.
- **Who:** Dropship desk · Treasury / Cashier / Finance · Curia
- **Need in product:** Variance + reason; adjust dropshipper payable.
- **Cover?:** Must
- **Watch out:** Approval if accept short.
### CU4 — COD failed / return
- **What’s happening:** Refuse delivery; return goods; reverse settle.
- **Example:** Order returned; Curia return fee 100.
- **Who:** Fulfillment · Dropship desk · Warehouse / Inventory Manager · Curia · Dropshipper
- **Need in product:** Reverse COD; restock; credit dropshipper; reverse supply if cancelled.
- **Cover?:** Must
- **Watch out:** Fee per agreement.
### CU5 — Curia prepay
- **What’s happening:** Advance Curia for deliveries.
- **Example:** Prepay 5k; invoices 3k; 2k credit.
- **Who:** Treasury / Cashier / Finance · Curia
- **Need in product:** Advance allocate.
- **Cover?:** Should
- **Watch out:** Same as cargo advance.
### CU6 — Dropship advance + COD (full)
- **What’s happening:** Same money story as S6 with full numbers.
- **Example:** See S6 example (25k / 5k / 20k / fee 1k / supply 18k / net 6k).
- **Who:** Dropship desk · Treasury / Cashier / Finance · Curia · Dropshipper
- **Need in product:** One order: advance + COD + supply + net.
- **Cover?:** Must
- **Watch out:** Twin of S6 — keep one product path.
### R9 — COD batch reconcile
- **What’s happening:** Lump remittance; match order by order.
- **Example:** 20 orders remitted; 2 still pending — reconcile completed only.
- **Who:** Dropship desk · Treasury / Cashier / Finance · Curia
- **Need in product:** Per-order match: COD, fee, supply, remittance.
- **Cover?:** Must
- **Watch out:** Do not clear pending into settled.

### 3.6 Investors and lenders

Shipment capital + profit share → **[investor-shipment-guide.md](investor-shipment-guide.md)**. Hooks: **SH3**, **SH4**. Bank loans: **R1**. Interest-style “investor” → **Out** (I2 / SH2).
### I1 — Equity contribution / distribution
- **What’s happening:** Ownership capital into the business (not shipment-linked).
- **Example:** Contribute 1M; distribute 100k.
- **Who:** Admin · Treasury / Cashier / Finance · Investor
- **Need in product:** Equity ≠ loan; shipment returns use investor catalog.
- **Cover?:** Should
- **Watch out:** Shipment deals use investor catalog.
### I2 — Loan with interest (not shipment investor)
- **What’s happening:** Someone lends; we repay with interest.
- **Example:** 100k USD @5% → repay 105k.
- **Who:** Treasury / Cashier / Finance · Lender
- **Need in product:** Principal + interest separate.
- **Cover?:** Out
- **Watch out:** Our shipment investors use capital + profit share — not this.
### I3 — Partial return with FX
- **What’s happening:** Repay investor/lender funding when FX moved.
- **Example:** Funded @120; repay @125 → FX loss.
- **Who:** Treasury / Cashier / Finance · Investor
- **Need in product:** FX on settlement; update balance.
- **Cover?:** Should
- **Watch out:** Shipment pay-outs still need investor gate.
### S7 — Investor reporting by channel
- **What’s happening:** Show float use across channels (not one shipment).
- **Example:** 500k float on dropship; report supply revenue not COD GMV.
- **Who:** Sales / Channel Manager · Treasury / Cashier / Finance · Investor
- **Need in product:** Channel on investor float statement.
- **Cover?:** Should
- **Watch out:** See also SH15; no fake shipment id.
### R10 — Director loan
- **What’s happening:** ~~Director lends company money.~~ Not our model.
- **Example:** —
- **Who:** —
- **Need in product:** —
- **Cover?:** Out
- **Watch out:** Use **Investor** capital + profit share (investor catalog), not director loans.

### R11 — Dividend + WHT
- **What’s happening:** ~~Board dividend to shareholders.~~ Not our model.
- **Example:** —
- **Who:** —
- **Need in product:** —
- **Cover?:** Out
- **Watch out:** Investor pay-outs are profit share / capital return after the gate — not dividends.

### 3.7 Staff / payroll

### S1p — Monthly payroll
- **What’s happening:** Gross − deductions = net.
- **Example:** Salary 50k; deduct 5k; net 45k.
- **Who:** Payroll / HR · Treasury / Cashier / Finance · Staff
- **Need in product:** Gross, deductions, net separate.
- **Cover?:** Must
- **Watch out:** Deductions ≠ net.
### S2p — Staff advance recovery
- **What’s happening:** Recover advance from salary.
- **Example:** Advance 10k from 50k → net 40k.
- **Who:** Payroll / HR · Treasury / Cashier / Finance · Staff
- **Need in product:** Advance asset → recovery.
- **Cover?:** Must
- **Watch out:** Clear advance balance.
### S3p — Multi-currency payroll
- **What’s happening:** Pay staff in more than one currency.
- **Example:** BDT 50k + USD 500@122.
- **Who:** Payroll / HR · Treasury / Cashier / Finance · Staff
- **Need in product:** FX at payment date.
- **Cover?:** Should
- **Watch out:** Subledger by currency.
### S8 — Channel commission
- **What’s happening:** Commission % by channel via payroll.
- **Example:** 2% wholesale 8k + retail 4k; dropship on supply revenue.
- **Who:** Sales / Channel Manager · Payroll / HR · Staff
- **Need in product:** Commission expense + channel.
- **Cover?:** Must
- **Watch out:** Dropship commission ≠ end-customer GMV.
### R12 — Payroll tax withhold
- **What’s happening:** Withhold income tax; remit.
- **Example:** Withhold 3k; pay net; remit 3k.
- **Who:** Payroll / HR · Tax / Compliance · Staff · Tax Authority
- **Need in product:** Payroll tax payable + remit.
- **Cover?:** Must
- **Watch out:** Remit on time.

### 3.8 Purchase-to-pay (internal)

### P1 — Requisition → PO
- **What’s happening:** Ask → approve → buyer raises PO.
- **Example:** 10 laptops; manager yes; PO issued.
- **Who:** Requisitioner · Approver / Manager · Procurement / Buyer
- **Need in product:** Requester ≠ approver.
- **Cover?:** Must
- **Watch out:** Audit trail.
### P2 — Three-way match
- **What’s happening:** PO ↔ receipt ↔ invoice.
- **Example:** PO 100; receive 98; invoice 100 → hold 2.
- **Who:** Receiver · AP Clerk · Vendor
- **Need in product:** Match variance before full pay.
- **Cover?:** Must
- **Watch out:** Pay for received, not only billed.
### P3 — Price variance
- **What’s happening:** Invoice > PO price.
- **Example:** PO 10; invoice 11 → approve +1.
- **Who:** AP Clerk · Approver / Manager · Vendor
- **Need in product:** Variance approval.
- **Cover?:** Must
- **Watch out:** No silent overbill.
### P4 — Payment run SoD
- **What’s happening:** AP prepare; manager approve; treasury pay.
- **Example:** 5 payments; three people.
- **Who:** AP Clerk · Approver / Manager · Treasury / Cashier / Finance
- **Need in product:** Three-way SoD on payment run.
- **Cover?:** Must
- **Watch out:** No one person all three.
### P5 — Purchase return receiving
- **What’s happening:** Defects returned; vendor credits.
- **Example:** 5 units returned + credit note.
- **Who:** Receiver · Warehouse / Inventory Manager · AP Clerk · Vendor
- **Need in product:** Return + stock + credit.
- **Cover?:** Must
- **Watch out:** Stock matches credit.
### P6 — Expense reimbursement
- **What’s happening:** Staff pays; company reimburses.
- **Example:** Travel 2k; approved; paid.
- **Who:** Staff · Approver / Manager · AP Clerk
- **Need in product:** Claim + receipt + approval.
- **Cover?:** Must
- **Watch out:** No pay without receipt policy.
### P8 — Vendor bank detail change
- **What’s happening:** Vendor changes bank — fraud risk.
- **Example:** Email “new bank”; dual approve + callback.
- **Who:** AP Clerk · Approver / Manager · Vendor
- **Need in product:** Dual approval + change log.
- **Cover?:** Must
- **Watch out:** Highest fraud risk.
### P9 — Prepaid expense
- **What’s happening:** Pay ahead; expense monthly.
- **Example:** Rent 30k / 3 months → 10k/month.
- **Who:** AP Clerk · Treasury / Cashier / Finance · Landlord
- **Need in product:** Prepaid asset → monthly expense.
- **Cover?:** Should
- **Watch out:** Do not expense all day one.
### P10 — PO cancel
- **What’s happening:** Cancel before delivery; reject late bills.
- **Example:** Cancel laptop PO.
- **Who:** Procurement / Buyer · Approver / Manager
- **Need in product:** PO cancelled status.
- **Cover?:** Must
- **Watch out:** Reject bill on cancelled PO.
### R13 — Utility bills
- **What’s happening:** Power, water, internet.
- **Example:** Electricity 8k; internet 2k.
- **Who:** AP Clerk · Utility Providers
- **Need in product:** Monthly expense.
- **Cover?:** Must
- **Watch out:** Provider if on credit.
### R14 — Professional fees
- **What’s happening:** Auditor / legal / consultant.
- **Example:** Audit 100k; legal 50k.
- **Who:** AP Clerk · Auditor / Legal / Consultant
- **Need in product:** Fee expense on invoice.
- **Cover?:** Should
- **Watch out:** Capitalize only if setup policy.

### 3.9 Dropship supply / fulfillment

### T1 — Full dropship supply (classic)
- **What’s happening:** We fulfill dropshipper sale; Curia COD; settle net.
- **Example:** End 1,000; supply 700; COGS 500; Curia fee 50; remit 250; our GP 200 (150 if we bear fee).
- **Who:** Dropship desk · Fulfillment · Curia · Dropshipper · End customer
- **Need in product:** One order: supply revenue, COD clearing, net remittance.
- **Cover?:** Must
- **Watch out:** Earn on supply invoice only.
### T2 — Dropshipper credit / COD timing
- **What’s happening:** We fund stock before COD remits.
- **Example:** Stock payable 500 due now; COD 950 in 7 days.
- **Who:** Dropship desk · Treasury / Cashier / Finance · Dropshipper · Vendor
- **Need in product:** Separate parties — no auto-net.
- **Cover?:** Must
- **Watch out:** Vendor ≠ Curia ≠ dropshipper.
### S9 — Bulk cargo + Curia last-mile
- **What’s happening:** Cargo bulk leg; Curia last-mile + COD.
- **Example:** Cargo 15k; Curia 1k; COD 30k; supply 25k; net to dropshipper 4k.
- **Who:** Shipping Coordinator · Dropship desk · Cargo Company · Curia · Dropshipper
- **Need in product:** Fulfillment costs + COD settle.
- **Cover?:** Must
- **Watch out:** Landed/fulfill costs per policy.
### S10 — Dropship return to us
- **What’s happening:** Goods return to our stock; credit dropshipper; reverse sale.
- **Example:** Supply was 7k; restock cost 5k; Curia return fee 100.
- **Who:** Fulfillment · Warehouse / Inventory Manager · Dropship desk · Dropshipper · Curia
- **Need in product:** Restock if sellable; reverse supply; no vendor credit unless returned to vendor.
- **Cover?:** Must
- **Watch out:** Grade damaged goods.

### 3.10 Inventory, COGS, channel

### S11 — Receive with landed cost
- **What’s happening:** Shelf cost = price + freight + duty + insurance capitalized.
- **Example:** 100×50 + freight 5k + customs 2k → 120/unit.
- **Who:** Receiver · Warehouse / Inventory Manager · AP Clerk
- **Need in product:** Per-unit landed on shipment; shared split SH7.
- **Cover?:** Must
- **Watch out:** Non-shelf fees out (SH9).
### S12 — COGS by channel
- **What’s happening:** Cost leaves stock with the sale, by channel.
- **Example:** 40 wholesale; unit 120 → COGS 4,800.
- **Who:** Sales / Channel Manager · Treasury / Cashier / Finance
- **Need in product:** COGS journal + channel.
- **Cover?:** Must
- **Watch out:** Report negative margin honestly.
### S13 — Stock write-off
- **What’s happening:** Damage/theft/shrink.
- **Example:** 3 × 120 = 360 write-off.
- **Who:** Warehouse / Inventory Manager · Approver / Manager
- **Need in product:** Count + approval + adjust.
- **Cover?:** Must
- **Watch out:** Approval required.
### S14 — Inter-channel stock transfer
- **What’s happening:** Move stock warehouse/channel — not a sale.
- **Example:** 20 units wholesale → retail.
- **Who:** Warehouse / Inventory Manager
- **Need in product:** Transfer only; no revenue.
- **Cover?:** Must
- **Watch out:** No fake sale.
### S15 — Consignment stock
- **What’s happening:** Vendor stock on our shelf; pay when sold.
- **Example:** 50 in; sell 20; pay 20.
- **Who:** Warehouse / Inventory Manager · AP Clerk · Vendor
- **Need in product:** Memo until sold.
- **Cover?:** Should
- **Watch out:** Twin of R5.

### 3.11 Period-end, tax, supporting

### S16 — FX revaluation
- **What’s happening:** Month-end revalue open FX.
- **Example:** Payable 1,000 USD 120→122 → 2k FX loss.
- **Who:** Treasury / Cashier / Finance
- **Need in product:** Reval journal.
- **Cover?:** Must
- **Watch out:** Open balances only.
### S17 — Channel profit
- **What’s happening:** Period profit by wholesale / retail / dropship supply.
- **Example:** Wholesale 80k; dropship supply 90k; retail 50k.
- **Who:** Sales / Channel Manager · Admin · Treasury / Cashier / Finance
- **Need in product:** Channel scorecard beside shipment profit.
- **Cover?:** Must
- **Watch out:** Dropship uses supply revenue not COD GMV.
### S18 — VAT sales/purchases
- **What’s happening:** Output − input = net VAT.
- **Example:** Output 1.5k; input 3k → credit 1.5k.
- **Who:** Tax / Compliance · Tax Authority
- **Need in product:** VAT ledger + return.
- **Cover?:** Must
- **Watch out:** Do not mix into shelf cost.
### S19 — Opening balances
- **What’s happening:** Migrate opening money/stock.
- **Example:** AR 60k; AP 20k; wallet 50k; stock 100k.
- **Who:** Treasury / Cashier / Finance
- **Need in product:** Opening journals; reconcile old system.
- **Cover?:** Must
- **Watch out:** One-time clean cut.
### S20 — Bad debt provision by channel
- **What’s happening:** Reserve % of receivables.
- **Example:** Wholesale 2%; retail 1%; dropshipper 2%.
- **Who:** Credit Controller · Treasury / Cashier / Finance
- **Need in product:** Provision + aging by channel.
- **Cover?:** Should
- **Watch out:** Policy % written.
### R15 — WHT on vendor pay
- **What’s happening:** Withhold %; remit to tax.
- **Example:** Pay 50k; WHT 1k; net 49k.
- **Who:** AP Clerk · Tax / Compliance · Vendor · Tax Authority
- **Need in product:** WHT payable + remit.
- **Cover?:** Must
- **Watch out:** Vendor sees net correctly.
### R16 — Licenses / regulatory fees
- **What’s happening:** Trade license, permits.
- **Example:** License 5k; permit 3k.
- **Who:** Tax / Compliance · Regulator
- **Need in product:** Compliance expense or prepaid.
- **Cover?:** Should
- **Watch out:** Multi-year → prepaid.
### R17 — Intercompany transfer
- **What’s happening:** Move funds to related entity.
- **Example:** Transfer 200k as loan/advance.
- **Who:** Treasury / Cashier / Finance · Intercompany / Related entity
- **Need in product:** IC receivable; not expense.
- **Cover?:** Should
- **Watch out:** Related-party register.
### R18 — Year-end audit adjustment
- **What’s happening:** Auditor adjustment after review.
- **Example:** Missed accrual 10k posted.
- **Who:** Treasury / Cashier / Finance · Auditor / Legal / Consultant
- **Need in product:** Adjustment journal + trail.
- **Cover?:** Should
- **Watch out:** Finalise after post.
### S21 — Month soft vs hard close
- **What’s happening:** Soft = warn; hard = block late posts.
- **Example:** March soft 3 Apr; hard 10 Apr.
- **Who:** Treasury / Cashier / Finance · Approver / Manager
- **Need in product:** Close status + late-post unlock.
- **Cover?:** Must
- **Watch out:** No silent posts into closed month.
### S22 — Goods in transit at month-end
- **What’s happening:** Shipment not on shelf yet; still show money picture.
- **Example:** SHP-002 cost 200k + freight accrual 20k; not received.
- **Who:** Treasury / Cashier / Finance · Shipping Coordinator
- **Need in product:** In-transit / accrual; not on-shelf stock.
- **Cover?:** Must
- **Watch out:** See shipment receive rules.
### R19 — Cheque bounce / failed transfer
- **What’s happening:** Receipt reversed; debt reopens.
- **Example:** 50k cheque bounces; reopen invoice.
- **Who:** Treasury / Cashier / Finance · Bank · Customer
- **Need in product:** Reverse receipt; reopen open item; fee separate.
- **Cover?:** Must
- **Watch out:** Invoice not left paid.
### R20 — Accrue expected bill
- **What’s happening:** Know freight/customs coming; paper not in.
- **Example:** Accrue freight 60k on SHP-001; clear when bill posts.
- **Who:** AP Clerk · Treasury / Cashier / Finance · Cargo Company · Vendor
- **Need in product:** Accrual with shipment link.
- **Cover?:** Must
- **Watch out:** Clear accrual when real bill arrives.

### 3.12 Shipment P&L (money view)

Batch profit lives here. **Investor capital / withdraw / reinvest** → investor catalog. Twin goods cases → shipment catalog.
### SH1 — Shipment profit + product-line costs
- **What’s happening:** One inbound batch as a profit centre; shared costs split.
- **Example:** SHP-001: products 500k + shared 100k shelf = 600k; delivery 20k; sales 800k → profit 180k.
- **Who:** Treasury / Cashier / Finance · Warehouse / Inventory Manager · Sales / Channel Manager
- **Need in product:** Batch sales − sold cost − direct costs; product lines + split basis.
- **Cover?:** Must
- **Watch out:** Only sold units hit profit; supply invoice for dropship revenue.
### SH2 — Loan funds a shipment (interest)
- **What’s happening:** Optional lender story — not our usual investor.
- **Example:** Lender 700k @6%/60d interest 7k.
- **Who:** Treasury / Cashier / Finance · Lender
- **Need in product:** Loan + interest linked to shipment if needed.
- **Cover?:** Out
- **Watch out:** Normal investors = capital + profit share (investor catalog).
### SH3 — Investor capital + profit share (hook)
- **What’s happening:** Money hook only — full playbook in investor catalog.
- **Example:** See SHP-INV-001 in investor catalog (INV1 / INV8).
- **Who:** Investor · Tenant · Treasury / Cashier / Finance
- **Need in product:** Link capital to shipment; no interest; capital ≠ shelf cost.
- **Cover?:** Must
- **Watch out:** Detail: INV1–INV9. No pay-out before gate.
### SH4 — Shipment close + investor share (hook)
- **What’s happening:** Close report: batch profit and profit share side by side.
- **Example:** See investor catalog INV7–INV15 + worked close.
- **Who:** Treasury / Cashier / Finance · Investor · Admin
- **Need in product:** Close + cash-ready; then withdraw/reinvest choices.
- **Cover?:** Must
- **Watch out:** Detail: investor catalog. Do not mix with channel total as double profit.
### SH5 — Part of batch sold
- **What’s happening:** Profit uses sold cost only; rest stays stock.
- **Example:** Half sold; profit to date 90k; 300k cost still on shelf.
- **Who:** Treasury / Cashier / Finance · Warehouse / Inventory Manager
- **Need in product:** Open qty/cost; no full close.
- **Cover?:** Must
- **Watch out:** Do not expense unsold stock.
### SH6 — Same SKU, two shipments
- **What’s happening:** Sale picks cost by oldest stock or written average.
- **Example:** SHP-001 @4,000; SHP-002 @4,500; sell 10 → 40k if oldest.
- **Who:** Warehouse / Inventory Manager · Treasury / Cashier / Finance
- **Need in product:** One cost policy; link sale to stock that left.
- **Cover?:** Must
- **Watch out:** No silent mix of policies.
### SH7 — Split shared freight/customs
- **What’s happening:** One bill; split onto SKU lines.
- **Example:** Freight 60k by value: A 48k / B 12k.
- **Who:** AP Clerk · Treasury / Cashier / Finance · Cargo Company
- **Need in product:** Documented basis (value/weight/qty).
- **Cover?:** Must
- **Watch out:** Twin shipment IN9.
### SH8 — Late cost bill after sales
- **What’s happening:** Late freight; restamp open stock; catch-up sold.
- **Example:** Late +15k shelf; catch-up sold share.
- **Who:** AP Clerk · Treasury / Cashier / Finance
- **Need in product:** Late bill on shipment; catch-up per policy.
- **Cover?:** Must
- **Watch out:** Twin shipment IN10.
### SH9 — Non-shelf shipment fee
- **What’s happening:** Fine/penalty hits profit, not unit cost.
- **Example:** Port fine 5k; shelf stays 600k.
- **Who:** Treasury / Cashier / Finance
- **Need in product:** Flag non-shelf on shipment P&L.
- **Cover?:** Must
- **Watch out:** Twin shipment IN11.
### SH10 — Multi-currency on one shipment
- **What’s happening:** Each bill keeps currency + rate; roll to BDT.
- **Example:** Goods 5k GBP; freight 200 USD; local 10k BDT.
- **Who:** AP Clerk · Treasury / Cashier / Finance · Vendor · Cargo Company
- **Need in product:** No silent currency mix on one payable.
- **Cover?:** Must
- **Watch out:** Rule 2 + rule 4.
### SH11 — Several investors on one shipment
- **What’s happening:** Pointer — multi-investor funding.
- **Example:** See investor **INV4** (and INV1).
- **Who:** Investor · Tenant · Treasury / Cashier / Finance
- **Need in product:** N lines; % = 100%.
- **Cover?:** Must
- **Watch out:** Body in investor catalog — do not duplicate.
### SH12 — Investor pool → many shipments
- **What’s happening:** Pointer — pool drawdowns.
- **Example:** See investor **INV19**.
- **Who:** Investor · Treasury / Cashier / Finance
- **Need in product:** Pool + drawdown → shipment; gate per shipment.
- **Cover?:** Should
- **Watch out:** Body in investor catalog.
### SH13 — Profit share on a loss
- **What’s happening:** Pointer — loss → no profit pay-out.
- **Example:** See investor **INV9**.
- **Who:** Investor · Treasury / Cashier / Finance
- **Need in product:** Zero profit distribution unless contract shares loss.
- **Cover?:** Must
- **Watch out:** Body in investor catalog.
### SH14 — Early investor pay-back
- **What’s happening:** Pointer — block before gate.
- **Example:** See investor **INV16**.
- **Who:** Investor · Admin · Treasury / Cashier / Finance
- **Need in product:** Block early; rare board exception only.
- **Cover?:** Must
- **Watch out:** Body in investor catalog.
### SH15 — Working capital not one shipment
- **What’s happening:** Float for ops / channels — not a forced SHP id.
- **Example:** 500k float; report via S7 channel views.
- **Who:** Investor · Treasury / Cashier / Finance · Sales / Channel Manager
- **Need in product:** Funding without fake shipment; channel/month reports.
- **Cover?:** Should
- **Watch out:** Do not invent a shipment to park float.

### 3.13 Profit layers

| Layer | Question | Scenarios |
| :--- | :--- | :--- |
| Month / business | How did we do this period? | S16, S17, S21, S22 |
| Channel | Wholesale / retail / dropship? | S17 |
| Shipment / batch | How did this import do? | SH1–SH10 |
| Order | How did this dropship order settle? | S6, T1, H2 |
| Product / shelf | What did this SKU cost / left? | S11, SH5–SH6 |
| Line | One bill / sale / fee | — |
### H1 — Retail sale, no batch on ticket
- **What’s happening:** Till has no shipment box; cost still follows stock.
- **Example:** Sale 5k; stock from SHP-001 cost 3k.
- **Who:** Sales / Channel Manager · Warehouse / Inventory Manager · Treasury / Cashier / Finance
- **Need in product:** Cost from stock move; back-office batch link.
- **Cover?:** Must
- **Watch out:** Cost ≠ zero because till omitted batch.
### H2 — Dropship order from two batches
- **What’s happening:** One order; picks from two shipments.
- **Example:** 10 units: 6 from SHP-001 + 4 from SHP-002; one order settle.
- **Who:** Fulfillment · Dropship desk · Warehouse / Inventory Manager
- **Need in product:** One order settle; cost split by pick.
- **Cover?:** Must
- **Watch out:** Do not break COD to force one SHP id.
### H3 — Return after shipment profit shown
- **What’s happening:** Return adjusts stock, revenue, batch profit.
- **Example:** Return revenue 20k / cost 15k; refresh SHP-001.
- **Who:** Sales / Channel Manager · Warehouse / Inventory Manager · Treasury / Cashier / Finance
- **Need in product:** Credit + restock + refresh shipment P&L.
- **Cover?:** Must
- **Watch out:** Do not freeze old report if material.
### H4 — One shipment, three channels
- **What’s happening:** One batch feeds wholesale + retail + dropship.
- **Example:** SH1 mix 800k revenue; one COGS 600k; three channel columns.
- **Who:** Sales / Channel Manager · Treasury / Cashier / Finance
- **Need in product:** Batch total and channel columns reconcile.
- **Cover?:** Must
- **Watch out:** Do not add channel + shipment as double profit.

### 3.14 Reports catalogue (S23)

| Report | Question | Who |
| :--- | :--- | :--- |
| Wallet / bank position | Cash by account? | Treasury, owners |
| Cash by channel (daily) | Counted vs expected? | Shop, finance |
| Open payables | What do we owe? | AP, finance |
| Open receivables | Who owes us? | Credit control, finance |
| Shipment profit | How did this batch do? | Finance, owners, investors |
| Investor statement | Capital / profit / pay-outs? | Finance, investors — detail in investor catalog |
| Channel profit | Channel scorecard? | Sales, board |
| Dropship order settlement | Per-order settle? | Dropship desk, finance |
| COD / Curia clearing | Unmatched COD? | Dropship desk, finance |
| Month snapshot | Period money picture? | Finance, board |
| FX revaluation list | Open FX to re-rate? | Finance |
| Month close checklist | Soft/hard close done? | Finance |
| VAT / tax workings | Output vs input? | Tax, finance |
| Payroll register | Net pay / deductions? | HR, finance |
| Audit adjustments log | What changed after review? | Finance, auditor |

**Cover?:** Must (catalogue exists as product reporting map).  
**Watch out:** Shipment + channel are two views of the same sales — not two piles of profit.

---

## 4. Quick-ref

| ID | One-line | Who (short) | Cover? |
| :--- | :--- | :--- | :--- |
| D1 | Own wallet move | Finance, Bank | Must |
| D2 | FX + bank fee | Finance, Bank | Must |
| S1 | Cash by channel | Finance, Sales | Must |
| R1 | Bank loan | Finance, Lender | Must |
| R2 | Gateway + chargeback | Finance, Gateway | Must |
| R3 | MFS settle | Finance, MFS | Must |
| R4 | Petty cash | Custodian, Finance | Must |
| V1–V5 | Vendor pays / FX / return | AP, Vendor | Must |
| S2 | Payment run + landed freight | AP, Finance | Must |
| R5 | Consignment | Warehouse, Vendor | Should |
| R6 | Import + duty + VAT | AP, Cargo, Customs | Must |
| C1–C6 | Customer AR / FX / chargeback | Credit, Finance | Must |
| S3–S5 | Wholesale / retail / return | Sales, Credit | Must |
| S6 / CU6 | Dropship settle | Dropship desk, Curia | Must |
| R7 | Credit limit breach | Credit, Approver | Must |
| CA1–CA6 | Cargo freight / claim | Shipping, Cargo | Must |
| R8 | Insurance claim | Finance, Insurance | Should |
| CU1–CU4 / R9 | Curia fee / COD | Dropship desk, Curia | Must |
| CU5 | Curia prepay | Finance, Curia | Should |
| I1 | Equity | Admin, Investor | Should |
| I2 | Interest loan as “investor” | Lender | Out |
| I3 | Partial return FX | Finance, Investor | Should |
| S7 | Investor by channel | Sales, Investor | Should |
| R10–R11 | Director loan / dividend | — | Out |
| S1p–S2p / S8 / R12 | Payroll | HR, Finance | Must |
| S3p | Multi-currency payroll | HR, Finance | Should |
| P1–P5 / P8 / P10 | P2P + SoD | Internal | Must |
| P6 / P9 | Reimburse / prepaid | Staff, AP | Must / Should |
| R13–R14 | Utilities / fees | AP | Must / Should |
| T1–T2 / S9–S10 | Dropship supply | Dropship desk | Must |
| S11–S14 | Stock / COGS / transfer | Warehouse, Finance | Must |
| S15 | Consignment stock | Warehouse, Vendor | Should |
| S16–S19 / S21–S22 | Close / FX / VAT / migrate | Finance | Must |
| S20 | Bad debt provision | Credit | Should |
| R15 | Vendor WHT | AP, Tax | Must |
| R16–R18 | License / IC / audit | Finance | Should |
| R19–R20 | Bounce / accrual | Finance | Must |
| SH1 | Shipment profit | Finance | Must |
| SH2 | Shipment loan interest | Lender | Out |
| SH3–SH4 | Investor hooks | → investor catalog | Must |
| SH5–SH10 | Batch cost edges | Finance, Warehouse | Must |
| SH11–SH14 | Investor edges | → investor catalog | Must / Should |
| SH15 | Non-shipment float | Investor, Finance | Should |
| H1–H4 | Layers edges | Sales, Finance | Must |
| S23 | Reports catalogue | Admin, Finance | Must |

---

## 5. Remember

1. Original currency + BDT + rate — always.
2. Deposits are liabilities; partial pays keep open items clean.
3. Three-way match; requester ≠ approver ≠ payer; dual-approve bank changes.
4. Dropship: supply invoice = our revenue; end-customer COD = clearing.
5. Landed cost = price + freight + customs + insurance capitalized; non-shelf fees stay out.
6. Cost follows stock (oldest first unless average policy).
7. Shipment profit ≠ investor return; investor detail → investor catalog.
8. Channel / shipment / order / month are layers — do not add as double profit.
9. Who names only from roles.md.
10. Missing case → not decided; use the decision board for Must / Should / Out.

---

## 6. Glossary

| Term | Meaning |
| :--- | :--- |
| **Subledger** | Running account for one party |
| **Open item** | Invoice/bill not fully paid |
| **Advance / deposit** | Paid early (asset) or customer overpay (liability) |
| **Clearing** | Money in transit (e.g. COD with Curia) |
| **Landed / shelf cost** | Price + freight + duty + insurance capitalized |
| **COGS** | Inventory cost that leaves on sale |
| **FX gain/loss** | BDT change from rate moves |
| **Three-way match** | PO ↔ receipt ↔ invoice |
| **COD** | Cash on delivery via Curia |
| **Dropship supply invoice** | Our invoice to the dropshipper = our revenue |
| **Dropshipper payable** | Net we owe after supply invoice + fees on held cash |
| **Shipment / batch** | One inbound load we cost (and often P&L) |
| **Shipment profit** | Batch sales − sold cost − direct batch costs |
| **Channel profit** | Period scorecard by wholesale / retail / dropship |
| **Profit layers** | Month → channel → shipment → order → product → line |
| **Non-shelf fee** | Hits shipment profit, not unit cost |
| **Soft / hard close** | Warn vs block posts into a closed month |
| **Accrual** | Book expected bill before paper arrives |

Investor terms (capital, gate, reinvest, pool) → [investor-shipment-guide.md](investor-shipment-guide.md).
