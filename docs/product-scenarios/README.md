# Product scenarios (decision catalogs)

**What this folder is:** Scenario catalogs for **product decisions** — what cases we need, who acts, and what we cover (Must / Should / Out).  
**What this is not:** Staff day-to-day SOP. That lives in the app at `/operating-manual`.

**Audience:** Tenant Admin / owners and developers.

## Read order

1. This README  
2. [roles.md](roles.md) — system roles (Who names)  
3. Domain catalogs (any order; investor before money SH3/SH4 if you care about capital)  
4. [Decision board](money-flow-pnl-product-review.md) — what we build  

**How work flows:** Fix catalogs first → refresh the decision board → then a separate product build plan.

## Catalogs

| Catalog | Job | File |
| :--- | :--- | :--- |
| Roles | Who exists in the system | [roles.md](roles.md) |
| Money | Bills, cash, channels, batch profit (short investor pointers) | [money-flow-guide.md](money-flow-guide.md) |
| Investor | Capital, profit share, withdraw / reinvest (sold + cash ready) | [investor-shipment-guide.md](investor-shipment-guide.md) |
| Shipment | Goods in, warehouse, trips | [shipment-guide.md](shipment-guide.md) |
| Shop & orders | Shop types and orders | [shop-and-orders-guide.md](shop-and-orders-guide.md) |
| Courier | Last-mile Bangladesh, COD risk | [courier-dispatch-guide.md](courier-dispatch-guide.md) |
| Decision board | Must / Should / Defer / Out + backlog | [money-flow-pnl-product-review.md](money-flow-pnl-product-review.md) |

**Locked investor rule:** capital in + share of shipment profit — not a loan with interest. Pay-out only when the shipment is fully sold and cash is ready.

**Pointers (do not duplicate):** money SH3/SH4/SH11–SH14 → investor INV*; shipment IN12 → investor; shop DS7 / courier CD16 → money CU*/S6/T1.

---

## Shared template (every domain catalog)

Use this shape. Do not invent a new structure per file.

```text
# Title
Product-decision catalog for <domain> (≤ 3 lines)
Pairs with: roles.md + other catalogs by name

## 1. Plain words + one running example
## 2. Locked rules (≤ 10) — no full cast (see roles.md)
## 3. Scenarios we may cover
### ID — Short name
- What’s happening: 1–2 sentences
- Example: numbers
- Who: role names from roles.md
- Need in product: what capability this implies (1 line)
- Cover?: Must / Should / Out
- Watch out: ≤ 2 lines
## 4. Quick-ref (ID | one-line | Who | Cover?)
## 5. Remember (≤ 10)
## 6. Glossary (terms used only)
```

**Decision board** (product review file only): purpose → locked rules → one table (`ID | Case | Example | Who | Cover? | Catalog`) → open questions → Must backlog (`done when…`).

**Cover? labels**

| Label | Meaning |
| :--- | :--- |
| **Must** | Product must handle this |
| **Should** | Want soon |
| **Defer** | Known case; not building yet (board only) |
| **Out** | We choose not to build it (say why) |
