# Investor & shipment capital

Product-decision catalog for **investor capital and shipment profit share**.  
**Pairs with:** [roles.md](roles.md) · [money-flow-guide.md](money-flow-guide.md) (bills/COD/batch profit) · [shipment-guide.md](shipment-guide.md) (goods) · [decision board](money-flow-pnl-product-review.md).

> **Locked model:** Investors put in **capital**. They get an agreed **share of that shipment’s profit**. This is **not** a loan. We do **not** pay interest. Capital is not shelf cost. Profit share is a pay-out of profit.

---

## 1. Plain words + one running example

> Investors and the business fund a shipment → we buy and sell → when everything is sold and cash is ready, we share profit → investors may withdraw profit, withdraw capital, or reinvest.

**Running example — Shipment SHP-INV-001**

| Who | Capital | Funding % | Profit % |
| :--- | ---: | ---: | ---: |
| Investor A | 200,000 | 20% | 20% |
| Investor B | 500,000 | 50% | 50% |
| Business (us) | 300,000 | 30% | 30% |
| **Total** | **1,000,000** | 100% | 100% |

After all goods sold: sales **1,500,000** − cost **1,000,000** = profit **500,000** → A **100,000** · B **250,000** · Business **150,000**.

Default: profit % matches capital % unless the agreement says otherwise. Profit shares must total **100%**.

---

## 2. Locked rules

1. Capital in is funding, not sales.
2. Capital is not a shipment / shelf cost.
3. Profit share is a split of profit, not cost of goods.
4. Investor % + business % = **100%**.
5. No interest on investor capital (bank loan = different story in money catalog).
6. **Gate** before any pay-out or capital return: full shipment **sold** and **cash ready**.
7. Until the gate opens: statements OK; no withdraw profit, withdraw capital, or reinvest pay-out.
8. After the gate: withdraw profit, withdraw capital, and/or reinvest (combine allowed; record each line).
9. Loss → profit share pay-out **zero** unless the agreement shares losses.
10. Every movement: who, shipment ID, amounts, %, date, cash method, cash-ready flag.

Who names: use [roles.md](roles.md) only — no second cast here.

---

## 3. Scenarios we may cover

### INV1 — Open investor capital on a shipment
- **What’s happening:** Set the funding mix before or as we buy the batch.
- **Example:** SHP-INV-001 needs 1,000,000. A 200k · B 500k · Business 300k. Profit 20% / 50% / 30%.
- **Who:** Investor · Tenant · Legal / Finance Approver · Treasury / Cashier / Finance
- **Need in product:** Capture capital + profit % per party on a shipment; reject totals ≠ 100%.
- **Cover?:** Must
- **Watch out:** Do not sell under an investor deal with missing % or missing capital receipt.

### INV2 — Capital arrives in parts
- **What’s happening:** Investor promises a full amount but pays in installments.
- **Example:** A pays 100k day 1, 100k day 10 toward 200k.
- **Who:** Investor · Treasury / Cashier / Finance
- **Need in product:** Receipts + outstanding capital; funding status per investor.
- **Cover?:** Should
- **Watch out:** Do not treat as fully funded (or pay full %) until agreed capital is in unless contract allows.

### INV3 — Business is also a funder
- **What’s happening:** We put capital in and keep a profit share — not only operate.
- **Example:** Business 300k / 30% on SHP-INV-001.
- **Who:** Tenant · Treasury / Cashier / Finance
- **Need in product:** Business capital and profit % as first-class lines on the shipment.
- **Cover?:** Must
- **Watch out:** Do not hide business capital as if investors funded 100%.

### INV4 — More than two investors
- **What’s happening:** Three or more investors plus business; shares still total 100%.
- **Example:** A 15% · B 25% · C 30% · business 30%.
- **Who:** Investor · Tenant · Treasury / Cashier / Finance
- **Need in product:** N investor lines; sum check = 100%.
- **Cover?:** Should
- **Watch out:** Reject totals over 100%.

### INV5 — Part sold — no pay-out yet
- **What’s happening:** Some stock sold; paper profit may exist; **gate closed**.
- **Example:** Half sold; A’s paper share 50k. No withdrawal.
- **Who:** Investor · Treasury / Cashier / Finance
- **Need in product:** Progress / estimate view with “not ready for pay-out.”
- **Cover?:** Must
- **Watch out:** Do not pay or return capital from a half-sold batch.

### INV6 — Sold out, cash not ready
- **What’s happening:** All units sold; profit known; receivables/COD still open.
- **Example:** Profit 500k on paper; receivable 200k. Gate still closed.
- **Who:** Treasury / Cashier / Finance · Credit Controller
- **Need in product:** Sold-out ≠ cash-ready; both flags required.
- **Cover?:** Must
- **Watch out:** Sold-out alone must not unlock pay-out.

### INV7 — Sold out + cash ready — gate opens
- **What’s happening:** Batch sold; cash available; finance marks cash ready.
- **Example:** SHP-INV-001 sold out; enough cash for A’s and B’s choices.
- **Who:** Treasury / Cashier / Finance · Approver / Manager
- **Need in product:** Explicit sold-out + cash-ready + approval to open gate.
- **Cover?:** Must
- **Watch out:** Do not open the gate on a guess.

### INV8 — Lock profit split
- **What’s happening:** Gate open; lock final profit and each party’s share.
- **Example:** 500k → A 100k · B 250k · Business 150k.
- **Who:** Treasury / Cashier / Finance · Investor · Tenant
- **Need in product:** Locked profit + locked % before withdraw / reinvest choices.
- **Cover?:** Must
- **Watch out:** Do not change % after lock without written amendment.

### INV9 — Shipment makes a loss
- **What’s happening:** Sales below cost; profit negative or zero.
- **Example:** Cost 1M; sales 900k; loss 100k. Profit share pay-out = 0.
- **Who:** Treasury / Cashier / Finance · Investor · Tenant
- **Need in product:** Zero profit pay-out on loss; capital rules follow agreement.
- **Cover?:** Must
- **Watch out:** Do not pay a “profit share” on a loss.

### INV10 — Withdraw profit only
- **What’s happening:** After gate, investor takes profit cash; capital stays.
- **Example:** A withdraws 100k profit; capital 200k remains.
- **Who:** Investor · Treasury / Cashier / Finance · Approver / Manager
- **Need in product:** Profit pay-out separate from capital return.
- **Cover?:** Must
- **Watch out:** Paying profit is not returning capital.

### INV11 — Withdraw capital only
- **What’s happening:** After gate, investor takes some or all capital back.
- **Example:** B returns capital 500k; profit handled separately.
- **Who:** Investor · Treasury / Cashier / Finance · Approver / Manager
- **Need in product:** Capital return after gate; not booked as purchase cost or negative sales.
- **Cover?:** Must
- **Watch out:** No capital return before the gate.

### INV12 — Reinvest profit
- **What’s happening:** Profit becomes new capital on a clear destination shipment (or written top-up).
- **Example:** A’s 100k profit → capital on SHP-INV-002.
- **Who:** Investor · Treasury / Cashier / Finance · Legal / Finance Approver
- **Need in product:** Profit-to-capital with source + destination shipment IDs.
- **Cover?:** Must
- **Watch out:** Do not leave profit floating with no home.

### INV13 — Take some profit, reinvest the rest
- **What’s happening:** Split one profit share into cash + reinvest.
- **Example:** B 250k → withdraw 100k; reinvest 150k to SHP-INV-002.
- **Who:** Investor · Treasury / Cashier / Finance
- **Need in product:** Multiple lines that sum to full profit share.
- **Cover?:** Must
- **Watch out:** Lines must add to the full profit share.

### INV14 — Take profit and capital together
- **What’s happening:** Full exit from this shipment after the gate.
- **Example:** A takes 100k profit + 200k capital = 300k cash out.
- **Who:** Investor · Treasury / Cashier / Finance · Approver / Manager
- **Need in product:** Combined exit; both balances to zero on this shipment.
- **Cover?:** Must
- **Watch out:** Cash ready must cover the full exit.

### INV15 — Roll capital to a new shipment
- **What’s happening:** After close, capital moves to a new shipment without cash out.
- **Example:** B’s 500k rolls SHP-INV-001 → SHP-INV-002; new % on new deal.
- **Who:** Investor · Treasury / Cashier / Finance · Legal / Finance Approver
- **Need in product:** Capital transfer between shipment IDs; old shipment closed first.
- **Cover?:** Must
- **Watch out:** New shipment needs its own funding table and %.

### INV16 — Early request before gate
- **What’s happening:** Investor wants profit or capital while stock remains or cash is not ready.
- **Example:** A asks for 50k “advance” with 40% unsold. Default: no.
- **Who:** Investor · Admin · Treasury / Cashier / Finance
- **Need in product:** Block early pay-out; optional logged decline / rare board exception.
- **Cover?:** Must (block early)
- **Watch out:** Early pay-outs break the model and use other parties’ cash.

### INV17 — Investor statement (one shipment)
- **What’s happening:** One clear view of capital, profit, and movements per investor per shipment.
- **Example:** A on SHP-INV-001 after gate: capital in 200k · profit 100k · out 0 / 0.
- **Who:** Investor · Treasury / Cashier / Finance
- **Need in product:** Per-shipment investor statement matching the ledger.
- **Cover?:** Must
- **Watch out:** No silent statement edits.

### INV18 — Same investor on two shipments
- **What’s happening:** One investor funds two shipments; each has its own gate.
- **Example:** B on SHP-INV-001 and SHP-INV-002 — separate closes.
- **Who:** Investor · Treasury / Cashier / Finance
- **Need in product:** Separate capital/profit lines and gates per shipment.
- **Cover?:** Must
- **Watch out:** No cross-shipment netting without written approval (money catalog).

### INV19 — Investor pool funds several shipments
- **What’s happening:** Pool money; drawdowns to named shipments; pay-out still per shipment gate.
- **Example:** Pool 2M; draw 1M to SHP-INV-001.
- **Who:** Investor · Treasury / Cashier / Finance · Legal / Finance Approver
- **Need in product:** Pool balance + drawdown → shipment; gate still per shipment unless written otherwise.
- **Cover?:** Should
- **Watch out:** Pool cash is still not sales.

### INV20 — Dispute on profit number
- **What’s happening:** Investor disagrees with locked or proposed profit.
- **Example:** B disputes delivery fees in the cost base (see money catalog SH1 / SH9).
- **Who:** Investor · Treasury / Cashier / Finance · Approver / Manager
- **Need in product:** Hold pay-out until resolved; audit notes.
- **Cover?:** Should
- **Watch out:** Do not pay under protest without a written holdback.

### INV21 — Transfer of investor rights
- **What’s happening:** Capital/profit rights move to another party.
- **Example:** A → A2 after gate, before pay-out.
- **Who:** Investor · Legal / Finance Approver · Treasury / Cashier / Finance · Admin
- **Need in product:** Approved party change; balances move; gate still applies.
- **Cover?:** Should
- **Watch out:** No transfer without approval / KYC.

### Out of this catalog (do not build as investor normal)
- Interest / loan-style investor returns → **Out** (use Lender in money catalog if needed).
- Pay-out before sold + cash ready as a normal path → **Out** (INV16 blocks).

---

## 4. Quick-ref

| ID | One-line | Who | Cover? |
| :--- | :--- | :--- | :--- |
| INV1 | Open capital + profit % on shipment | Investor, Tenant, Legal, Finance | Must |
| INV2 | Capital in parts | Investor, Finance | Should |
| INV3 | Business also funds | Tenant, Finance | Must |
| INV4 | Many investors | Investor, Tenant, Finance | Should |
| INV5 | Part sold — no pay-out | Investor, Finance | Must |
| INV6 | Sold out, cash pending | Finance, Credit Controller | Must |
| INV7 | Gate opens (sold + cash ready) | Finance, Approver | Must |
| INV8 | Lock profit split | Finance, Investor, Business | Must |
| INV9 | Loss → no profit pay-out | Finance, Investor, Business | Must |
| INV10 | Withdraw profit | Investor, Finance, Approver | Must |
| INV11 | Withdraw capital | Investor, Finance, Approver | Must |
| INV12 | Reinvest profit | Investor, Finance, Legal | Must |
| INV13 | Split profit (cash + reinvest) | Investor, Finance | Must |
| INV14 | Full exit (profit + capital) | Investor, Finance, Approver | Must |
| INV15 | Roll capital to new shipment | Investor, Finance, Legal | Must |
| INV16 | Early request — block | Investor, Admin, Finance | Must |
| INV17 | Investor statement | Investor, Finance | Must |
| INV18 | Two shipments, one investor | Investor, Finance | Must |
| INV19 | Pool + drawdowns | Investor, Finance, Legal | Should |
| INV20 | Profit dispute hold | Investor, Finance, Approver | Should |
| INV21 | Transfer rights | Investor, Legal, Finance, Board | Should |

---

## 5. Remember

1. Capital in ≠ sales.
2. Capital ≠ shelf cost; profit share ≠ shelf cost.
3. No interest on this investor model.
4. Gate: full shipment sold **and** cash ready.
5. After gate: withdraw profit, withdraw capital, and/or reinvest — record each choice.
6. Loss → no profit share unless contract shares loss.
7. % must add to 100% (investors + business).
8. One shipment, one close — no silent cross-shipment netting.
9. Who names only from [roles.md](roles.md).
10. Cover? feeds the [decision board](money-flow-pnl-product-review.md).

---

## 6. Glossary

| Term | Meaning |
| :--- | :--- |
| **Capital** | Money investor or business puts in to fund the shipment |
| **Profit share** | Agreed % of shipment profit owed to that party |
| **Shipment profit** | Sales − COGS from that shipment − direct shipment costs (money catalog) |
| **Gate / cash ready** | Full batch sold and money available to pay investors |
| **Withdraw profit** | Pay profit share in cash |
| **Withdraw capital** | Return some or all capital |
| **Reinvest profit** | Turn profit into new capital instead of cash |
| **Roll capital** | Move capital closed shipment → new shipment (no cash out) |
| **Investor statement** | Capital, profit, pay-outs for one shipment |
| **Pool** | Investor money that can fund more than one shipment |

---

## Worked close — SHP-INV-001

**Locked profit:** 500,000 (A 100k · B 250k · Business 150k)

| Party | Example choice | Cash out | Next |
| :--- | :--- | ---: | :--- |
| A | Withdraw all profit; leave capital | 100,000 | Capital 200k still with us |
| B | Withdraw 100k profit; reinvest 150k; roll 500k capital → SHP-INV-002 | 100,000 | New capital on 002: 650k |
| Business | Keep 150k profit in company | — | Our capital per next deal |

B’s reinvest/roll need SHP-INV-002 opened with a new funding table and %.
