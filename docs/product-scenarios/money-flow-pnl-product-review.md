# Decision board — what we build

**Purpose:** One place for board / owners and developers to lock **Must / Should / Defer / Out**.  
**Not:** Full scenario stories (those live in the catalogs).  
**Read first:** [README.md](README.md) → [roles.md](roles.md) → catalogs → this board.  
**After lock:** Separate product build plan from the Must backlog only.

**Labels**

| Label | Meaning |
| :--- | :--- |
| **Must** | Product must handle this |
| **Should** | Want soon |
| **Defer** | Known case; not building yet |
| **Out** | We choose not to build it (say why) |

Full Cover? per scenario stays in each catalog’s quick-ref. This board is the **priority slice** for the next build plan.

---

## Locked rules

1. **Hybrid profit:** batch + channel + order + month — do not add views as double profit.
2. Investor model: **capital in + profit share** — not a loan with interest.
3. Capital ≠ shelf cost; profit share ≠ COGS.
4. Investor pay-out only after shipment **fully sold** and **cash ready**.
5. Dropship revenue = **supply invoice**, not end-customer COD.
6. Stories first in the right catalog; then refresh this board; then build.

Running example (investor catalog **SHP-INV-001**): funding 1,000,000 → sales 1,500,000 → profit 500,000 → A 100k / B 250k / business 150k.

---

## Board table

| ID | Case | Example | Who | Cover? | Catalog |
| :--- | :--- | :--- | :--- | :--- | :--- |
| SH1 | Batch profit + product-line costs | Sales 800k − shelf 600k − direct 20k = 180k | Finance, Warehouse, Sales | Must | Money |
| SH5 | Part of batch sold | Half sold; unsold cost stays stock | Finance, Warehouse | Must | Money |
| SH6 | Same SKU, two shipments — cost rule | Oldest stock 10×4,000 (or written average) | Warehouse, Finance | Must | Money |
| SH7 | Split shared freight/customs | Freight 60k by value → A 48k / B 12k | AP, Finance, Cargo | Must | Money |
| SH8 | Late cost bill after sales | +15k shelf; catch-up sold share | AP, Finance | Must | Money |
| SH9 | Non-shelf fee | Port fine 5k hits profit, not unit cost | Finance | Must | Money |
| SH10 | Multi-currency on one batch | GBP goods + USD freight + BDT local | AP, Finance | Should | Money |
| SH2 / I2 | Loan + interest as investor deal | Lender 700k @ interest | Lender | **Out** | Money — use capital + profit share |
| INV1 / SH3 | Open capital + profit % | SHP-INV-001 20/50/30 | Investor, Tenant, Legal, Finance | Must | Investor (+ money hook) |
| INV3 | Business also funds | Business 300k / 30% | Tenant, Finance | Must | Investor |
| INV5–INV7 | Gate: sold + cash ready | Part sold / cash pending / gate opens | Investor, Finance, Approver | Must | Investor |
| INV8 | Lock profit split | 500k → 100/250/150 | Finance, Investor, Business | Must | Investor |
| INV9 / SH13 | Loss → no profit pay-out | Loss 100k → share 0 | Finance, Investor | Must | Investor |
| INV10–INV15 | Withdraw / reinvest / roll / exit | Profit out, capital out, reinvest, mix | Investor, Finance, Approver | Must | Investor |
| INV16 / SH14 | Early request before gate | Default block | Investor, Admin, Finance | Must | Investor |
| INV17–INV18 | Statement + multi-shipment | One statement; separate gates | Investor, Finance | Must | Investor |
| INV4 | Many investors | Shares = 100% with business | Investor, Business | Should | Investor |
| INV2 | Capital in parts | 100k then 100k | Investor, Finance | Should | Investor |
| INV19 / SH12 | Investor pool | Pool 2M; draw to SHP ids | Investor, Finance | Should | Investor |
| INV20–INV21 | Dispute / transfer | Hold pay-out; approved party change | Investor, Legal, Admin | Should | Investor |
| S7 / SH15 | Float not one shipment | 500k float; channel views | Investor, Sales, Finance | Should | Money |
| H1 | Retail sale, no batch on ticket | Cost follows stock in back office | Sales, Warehouse, Finance | Must | Money |
| H2 | Dropship order from two batches | 6+4 units; one order settle | Fulfillment, Dropship desk | Must | Money |
| H3 | Return after batch profit shown | Credit + restock; refresh SHP P&L | Sales, Warehouse, Finance | Should | Money |
| H4 | One batch, three channels | 800k revenue; three channel columns | Sales, Finance | Should | Money |
| S17 | Channel profit | Wholesale / retail / dropship period | Sales, Admin, Finance | Must | Money |
| S21 | Soft vs hard month close | Soft warn; hard block | Finance, Approver | Must | Money |
| S22 | Goods in transit at month-end | Not on shelf yet | Finance, Shipping | Must | Money |
| S16 | FX revaluation | Open FX at month-end | Finance | Should | Money |
| R19 | Cheque bounce / failed transfer | Reopen invoice | Finance, Bank, Customer | Should | Money |
| R20 | Accrue expected bill | Accrue freight 60k | AP, Finance | Should | Money |
| S23 | Reports catalogue | Honest report map | Admin, Finance | Must | Money |
| T1 / S6 / CU* | Dropship settle + COD | Supply invoice; clearing; remittance | Dropship desk, Curia, Finance | Must | Money (protect) |
| IN9–IN11 | Import costs / restamp / non-cap | Point to SH7–SH9 | AP, Receiver, Finance | Must | Shipment |
| IN12 | Investor on inbound (hook) | Link capital to shipment ID | Investor, Legal, Finance | Must | Shipment → Investor |
| IN3–IN4 | Land split + post stock | Outcomes sum; sellable = inventory | Receiver, Warehouse | Must | Shipment |
| DEM* / DP* | Catalog buy + trips | Confirm → buy → door → bill | Sales, Buyer, Fulfillment | Must | Shipment + Shop |
| ADM1 / FP* / VC* | Three shop playbooks | Type picks path; no mix | Sales, Customer | Must | Shop |
| DS3–DS9 | Dropship order life | Call → ship → remittance → payout | Dropship desk, Curia | Must | Shop |
| CD1–CD6 / CD13–CD16 / CD19 | Courier + remittance | Phone risk; consign; track ≠ money | Dropship desk, Curia, Finance | Must | Courier |
| — | Full balance sheet / statutory pack in app | — | Admin, Finance | **Defer** | — |
| — | Hard dual-approve every pay beyond permissions | — | Admin, Finance | **Defer** | Money P4 stays in catalog |
| — | Thrift (or other model) inside this money board | — | — | **Out** | Different sales model |
| R10 / R11 | Director loan / shareholder dividend | — | — | **Out** | Capital parties are **Investor** only |

---

## Open questions

Write the answer into the named catalog when decided.

1. **Oldest stock or average?** Same SKU in two batches (SH6) — which cost?
2. **Pools OK?** One pool → many batches, or one draw = one batch only? (INV19)
3. **Net across batches?** Allowed without special approval? (Suggest: **no**)
4. **Freight split default?** Value, weight, or quantity? (SH7)
5. **Two-batch dropship order?** Split only cost by batch, or also revenue? (H2)
6. **Retail till?** Back-office stock link enough, or every line show a batch? (H1)
7. **Balance sheet in the app?** Confirm Defer / Out / Must.
8. **Hard dual approve on pays?** Soft permissions enough, or build? (P4)

---

## Must backlog (`done when…`)

Catalogs already have the stories. These rows mean the **app** behaves right.

| # | Build | Done when… |
| :--- | :--- | :--- |
| M1 | Batch profit + non-shelf (SH1, SH9) | Fines cut batch profit; do **not** raise unit shelf cost |
| M2 | Part-sold batch (SH5) | Unsold stays stock; only sold cost hits profit |
| M3 | Split freight/customs (SH7) | User picks value / weight / quantity; lines get shares |
| M4 | Late cost after sales (SH8) | Open stock updates; sold units get catch-up |
| M5 | Cost on sale (SH6, H1) | Oldest stock (or written average); till without batch still gets cost |
| M6 | Channel profit (S17, H4) | Period channel scorecard — not double-counted with batch |
| M7 | Dropship order, two batches (H2) | One order settle; cost follows both batches |
| M8 | Investor capital + gate (INV1, INV7–INV8, SH3/SH4) | Capital + % locked; pay-out only after sold + cash ready |
| M9 | Withdraw / reinvest (INV10–INV15) | Profit out, capital out, reinvest, roll, or mix — recorded |
| M10 | Loss + early block (INV9, INV16) | No profit share on loss (unless contract); block before gate |
| M11 | Investor statement / multi-shipment (INV17–INV18) | Per-shipment balances; separate gates |
| M12 | Month soft / hard close (S21) | Soft warns; hard blocks unless unlocked |
| M13 | Goods in transit (S22) | Open / in transit — not fake shelf stock |
| M14 | Dropship settle + COD (T1, S6, CU*, DS*, CD*) | Order-by-order clearing; no regression |
| M15 | Reports catalogue honest (S23) | Live reports match catalogue; no double-profit views |

**Should next (after Must):** INV2, INV4, INV19/SH12, SH10, SH15/S7, H3, S16, R19, R20, INV20–INV21.

**Out (do not build as investor normal):** SH2 / I2 interest loan as our investor product.

---

## Meeting steps (~30–45 min)

1. Confirm hybrid + locked rules.  
2. Walk the board table — lock Cover? on each row.  
3. Answer open questions (or owner + date).  
4. Rank M1–M15 for the next build plan.  
5. Confirm Defer / Out rows.

New cases: add to the right catalog first → refresh this board → then build.
