# System roles

**What this is:** The one list of **who exists** in the product for scenario catalogs.  
**How to use it:** Scenario **Who:** lines must use these names. Do not invent a second cast in each catalog.

**Surfaces (where they show up):**
- **App** — tenant Admin / Staff (`/:slug/app/…`)
- **Shop** — customer / dropship storefront
- **Investor portal** — read-only investor view
- **Platform** — superadmin (rare in these scenarios)
- **External** — no login; we still track them for money/goods

---

## 1. Our business

The **Tenant** is the business. Each tenant has only two membership roles:

| Role | What they do | Surfaces |
|---|---|---|
| **Tenant** | The business entity — owns stock, books, and ops; may also fund a shipment (capital share) | — (entity, not a login) |
| **Admin** | Full control of the tenant: settings, approvals, investor rules, reports, product Must/Should | App |
| **Staff** | Day-to-day work inside the tenant (buy, receive, sell, pay, fulfill). Job hats below are Staff (or Admin), not extra login roles | App |

No other tenant membership roles (no separate board, director, or viewer role).

---

## 2. Money parties (often a running account)

| Role | What they do | Surfaces |
|---|---|---|
| **Vendor** | Sells us goods | App |
| **Customer** | Buys from us (wholesale / retail); dropshipper is a type of customer | App, Shop |
| **Dropshipper** | Sells using our stock; we fulfill and may clear end-customer cash | App, Shop |
| **End customer** | Dropshipper’s buyer (COD/online). Track per order, not as a full party page | Shop / courier |
| **Investor** | Puts **capital** into a shipment (or pool); gets **profit share** — not a loan with interest | App, Investor portal |
| **Cargo Company** | Freight, customs handling, insurance booking | App |
| **Curia** | Last-mile delivery + COD for dropship orders we fulfill | App |
| **Lender** | Bank / finance company loan (not our shipment investor model) | App |

Payroll payees are **Staff** (section 1). No shareholder / director party — capital returns use **Investor**.

---

## 3. Supporting parties (usually no trade “open item” book)

| Role | What they do | Surfaces |
|---|---|---|
| **Bank** | Accounts, FX, bank charges, term loans | App |
| **Payment Gateway / MFS** | Card / bKash / Nagad style collection | App, Shop |
| **Tax Authority** | VAT, income tax, withholding | App |
| **Customs Authority** | Import duty | App |
| **Insurance Company** | Cargo insurance / claims | App |
| **Landlord** | Rent | App |
| **Utility Providers** | Power, water, internet | App |
| **Auditor / Legal / Consultant** | Professional fees | App |
| **Intercompany / Related entity** | Group company transfers | App |
| **Petty Cash Custodian** | Holds small cash float (a Staff hat) | App |
| **Regulator** | Licenses / permits | App |

---

## 4. Staff job hats (not separate login roles)

Split work so one person does not request + approve + pay alone.  
**Who:** lines may use these names — they are **Admin** or **Staff** wearing a hat, not extra membership roles.

| Hat | What they do | Surfaces |
|---|---|---|
| **Requisitioner** | Asks to buy something | App |
| **Procurement / Buyer** | Chooses vendor, raises PO | App |
| **Approver / Manager** | Approves requests, POs, payments, write-offs (often **Admin**) | App |
| **Receiver** | Confirms goods arrived; counts | App |
| **Warehouse / Inventory Manager** | Bins, moves, damage, counts | App |
| **AP Clerk** | Matches PO ↔ receipt ↔ bill; prepares pay | App |
| **Treasury / Cashier / Finance** | Sends money; wallets; FX; investor pay-outs; cash-ready | App |
| **Payroll / HR** | Salary, deductions, advances | App |
| **Credit Controller** | Credit limits, refunds | App |
| **Shipping Coordinator** | Books cargo / Curia; tracks shipments | App |
| **Sales / Channel Manager** | Wholesale / retail / dropship results | App |
| **Tax / Compliance** | VAT and tax returns | App |
| **Legal / Finance Approver** | Investor agreements (capital + profit share) | App |
| **Fulfillment** | Pick, pack, dispatch, door outcome (catalog trips) | App |
| **Dropship desk** | Dropship order settle + COD matching | App |

---

## 5. Golden rules

1. Tenant membership = **Admin** or **Staff** only.  
2. **Request ≠ Approve ≠ Pay** for money out.  
3. **Receive ≠ alone approve cost changes ≠ alone pay vendor.**  
4. **Agree investor terms ≠ alone pay investor profit/capital.**  
5. Catalog **Who:** lines must match a name in this file.
