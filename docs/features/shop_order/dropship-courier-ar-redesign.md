# Dropship courier paper — AR (net remittance) redesign

**Status:** option **B** — **ship slice built** (`20261123250000_*`): mark-shipped creates **draft** customer AR (+ payout note) and **draft** courier AR (COD − rate − delivery via lines + header discount). **Remittance** (issue drafts, auto customer AR, retire AP retention) still open — spec.md **SO-CA1**. Parent: [spec.md](spec.md) US-5.

## Decision

| | |
| :--- | :--- |
| **Customer paper** | **AR** tenant → dropshipper (B2B cost) — keep. Plus a **note** on the bill: amount the dropshipper **will get after all payment** (expected profit / payout after remittance clears this AR) |
| **Courier paper** | **AR** tenant → courier (courier owes tenant) — replace today’s courier **AP** |
| **Courier AR amount** | **Option B:** expected **net remittance**. Bill **lines** show COD with fees deducted: **COD − rate − delivery** (not a separate fee AP) |
| **At ship** | Create both ARs as **draft** (not issued) |
| **On remittance** | Papers must be **issued** before / as remittance runs; pay in against **courier AR**; **auto allocate** to **customer AR**; remainder → dropshipper **cashbook** (profit). No second AR for profit |
| **Out** | AP “we owe courier fees”; separate cash-out to courier for those fees on the COD path; **issuing** bills at mark-shipped |

## Why

Cash reality: courier collects COD from the end customer, keeps fees, remits **net** to the tenant. Courier is a **debtor** (holds / owes remittance), not a **creditor** for fees. Dropshipper should see on **their** AR what they still owe (B2B) **and** what they should receive after the chain settles.

## Target at ship (two bills only — **draft**)

**Mark as shipped** creates (or upserts) both papers in **`draft`** — not `issued`. Status advances to `shipped`. Issuing is a **later** step (before remittance; exact trigger TBD with SO-CA1 — e.g. remittance prep).

**Mark as delivered** (settlement desk) **only** sets order status `shipped` → `delivered` — courier POD / parcel outcome. It does **not** save settlement, issue or finalize AR papers, or run remittance. Settlement **Save** and finance steps stay on their own actions ([spec.md](spec.md) US-5, gap **SO-DL5**).

```text
Ship (draft bills)
  ├─ Customer AR  — draft; B2B total
  │                 note: expected amount they get after all payment (profit)
  └─ Courier AR   — draft; lines: COD − rate − delivery → net due from courier
```

| Bill | Party | Header / note | At ship |
| :--- | :--- | :--- | :--- |
| Customer invoice | Dropshipper | Lines = B2B. **Note** = amount dropshipper gets **after all payment** | **`draft` AR** |
| Courier receivable | Courier | **Lines** = COD, − rate (COD fee), − delivery → **net** | **`draft` AR** |
| End-customer COD face | Recipient | Full COD on order / packing slip | **No** bill |
| Dropshipper profit | — | Same figure as customer AR **note**; posted to cashbook after remittance | Cashbook only |

**Prepaid / COD = 0:** skip courier AR (or do not create); customer AR draft only if still due; note may be zero / N/A.

## Customer AR — note (expected payout)

On the **tenant → dropshipper** AR paper:

| Field | Meaning |
| :--- | :--- |
| Bill total / due | B2B (what dropshipper owes tenant) — unchanged |
| **Note** | Plain text (or structured note): **amount they will get after all payment** — expected remittance leftover after this AR is cleared (dropshipper profit). Informative at ship; cashbook is still the money pot after remittance |

Does **not** create a second AR for profit. Note is visibility only until remittance + cashbook.

## Courier AR — lines (COD − rate − delivery)

Courier paper **must** show deductions as lines (or equivalent signed lines), not only a single net total:

| Line | Sign | Source (order fields) |
| :--- | :--- | :--- |
| COD | + | End-customer collect / `cod_collect_amount` (or resell + recipient charges that form COD face) |
| Rate | − | COD fee / rate (`cod_charge_amount` or shop “rate” label) |
| Delivery | − | `delivery_charge_amount` |
| **Net (bill total)** | | COD − rate − delivery |

Fees live **on this AR as negative lines**, not as a separate AP. Net = what courier should remit to tenant.

## Remittance (auto mechanism)

```text
Courier remits bank (net)
  ├─ Receipt / pay-in closes (or reduces) Courier AR
  ├─ Auto allocate to Customer AR (clear B2B due)
  └─ Surplus → dropshipper cashbook → payout later
       (should match customer AR note when fees/COD unchanged)
```

Rules:

- Remittance requires **customer AR** (and courier AR) **issued** — ship only left them **draft**; issue before remittance pay-in.
- Alloc order: **customer AR first** (full B2B due after notes); leftover = profit.
- Shortfall: customer AR stays due; courier AR vs bank variance → notes / ops follow-up.
- **No** `settle_dropship_courier_ap_via_cod_retention` in the target model — that was AP retention.

## Vs as-built (code today)

| | As-built | Target (this doc) |
| :--- | :--- | :--- |
| At ship | Customer AR + **courier AP** (**issued**) | Customer AR (**+ payout note**) + **courier AR** (COD − rate − delivery) — both **`draft`** |
| Courier role | Creditor (fees) | Debtor (net after fee lines) |
| Fees | Separate AP | Negative lines on courier AR |
| Remittance | Alloc customer AR + settle AP via retention | Papers **issued** then close courier AR + **auto** customer AR |

Ship RPC name may stay `ship_dropship_order_and_issue_merchant_bill` until renamed; at ship it must **create draft** courier **AR** (not issued AP).

## Worked example (option B)

| Face | Amount |
| :--- | ---: |
| COD | 2,200 |
| Rate (COD fee) | −50 |
| Delivery | −30 |
| **Courier AR net** | **2,120** |
| Customer AR (B2B) | 1,500 |
| **Customer AR note (get after all payment)** | **620** |

| Step | Result |
| :--- | :--- |
| Ship | **Draft** customer AR 1,500 + note “get 620 after payment”; **draft** courier AR lines COD 2,200 − rate 50 − delivery 30 = **2,120** |
| Deliver | Status → `delivered` only (no bill/settlement side effects) |
| Before remit | Issue drafts when product requires (remittance needs issued) |
| Remit 2,120 | Courier AR paid; auto alloc 1,500 → customer AR paid; **+620** cashbook (matches note) |
| Later | Payout 620 — cashbook only |

## Implementation notes (when building)

- At ship: create both ARs as **`draft`** (not issued).
- Customer AR: persist **note** (or channel_meta) with expected “get after all payment” at ship; refresh if settlement fees change before remittance if product requires.
- Courier AR: create AR with **three logical lines** (COD +, rate −, delivery −); net = bill total.
- Replace / stop `upsert_dropship_courier_ap_bill` at ship.
- Issue path before remittance (deliver or remittance prep — pick in SO-CA1 build).
- Update remittance + preview RPCs; remove AP retention settle.
- Settlement desk + platform docs: “courier AP” → “courier AR (COD − rate − delivery)”; ship = draft.

## Spec story

### US-5b: Courier AR (net) + auto customer AR on remittance

- [ ] Ship creates **draft** customer AR (**note: amount after all payment**) + **draft** courier AR (lines **COD − rate − delivery**); **not** courier AP; **not** issued at ship.
- [ ] Remittance pay-in (on **issued** papers) closes courier AR and **auto** allocates to customer AR; remainder → cashbook.
- [ ] Prepaid / zero COD: no courier AR.
- [ ] Docs + UI copy match; AP retention path retired for new ships.
