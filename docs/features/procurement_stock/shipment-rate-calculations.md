# Shipment rate and product cost in BDT

**Who this is for:** staff who run shipments, junior devs wiring costing, anyone asking “how do we get a product price in Taka?”

**One job:** the **target** calculation — how bills become **unit cost in BDT** on every SKU. This file is calculation truth; shipping code may lag ([PS13](00-gaps.md) in spec).

Product context: [procurement_stock/spec.md](spec.md) US-1.

---

## In plain words

- Bills may be **foreign** (e.g. GBP) or **BDT**.
- Each product line gets **unit landed cost in BDT** = goods + freight + customs + handling + finance + other (capitalizable only).
- Convert money **per bill / per pay** to BDT. Then **pool by bucket**. Then **spread** each pool with a **different rule** (price, kg, qty, or value).
- **Material FX** = one **shipment-wide** weighted rate from **material** pays only. **Not** per section. **Not** the all-bucket average FX (that is for reports only).

---

## Golden rules

1. Weighted FX: \(\sum \text{BDT} / \sum \text{foreign}\). Never \((168+166)/2\).
2. Never stamp SKUs with the **all-foreign average** rate.
3. Never mix GBP + BDT in one “foreign” sum; build **BDT pools**.
4. Never put **all** buckets into one pile ÷ kg for everything.
5. **No section material rate** — one shipment material rate only.
6. Only **`is_capitalizable`** bill amounts enter landed pools.
7. Run the **algorithm in order** (§6). Customs and finance need totals from an earlier pass.

---

## Name map

| Name | Meaning | Use on SKU? |
| :--- | :--- | :--- |
| **All-foreign average rate** | BDT on all foreign AP ÷ foreign paid | **No** — reporting |
| **Shipment material rate** | Material BDT pool ÷ material foreign paid | **Yes** — goods FX |
| **Freight BDT per kg** | Freight BDT pool ÷ **kg basis** (§5) | **Yes** |
| **Cargo rate (GBP/kg)** | Foreign freight only ÷ kg | Display / legacy only — **do not** stack with freight BDT pool |

---

## 1 — All-foreign average rate (reporting only)

\[
\text{average} = \frac{\sum \text{BDT paid on foreign bills}}{\sum \text{foreign paid}}
\]

Include paid foreign AP in any bucket. Exclude BDT bills, voided pays, unpaid.

Example shipment 53: **167.251749** (includes handling foreign; **not** used on products).

---

## 2 — Bucket pools (BDT)

For each bucket, **pool_bdt** = sum of capitalizable amounts in BDT.

| Source | BDT amount |
| :--- | :--- |
| **Paid** | Books allocation from settlement/pay (allocation × `books_rate` when needed) |
| **Unpaid / partial pay** | Use **issued bill open amount** in bill currency; multiply by rate on the bill or last pay. BDT bills: open amount |
| **Credit note / void** | Subtract from pool |

| Bucket | Pool |
| :--- | :--- |
| material | All material AP (capitalizable) → BDT |
| freight | Each freight bill → BDT; **add** BDT freight as-is |
| customs, handling, finance, other | Same rule |

**Freight:** never add GBP and BDT into one FX denominator. Example pool: 977.50 GBP @ 166 + 1,000 BDT = **163,265 BDT**.

**Customs proxy:** internal **CIF in BDT**, not the legal customs declaration formula.

---

## 3 — Shipment constants

Compute **once** per stamp (when pays or bills change, recompute all).

| Constant | Formula |
| :--- | :--- |
| **Shipment material rate** | material pool BDT ÷ material pool foreign |
| **Freight BDT per kg** | freight pool BDT ÷ **kg basis** |
| **Kg basis** | \(\sum (\text{unit kg} × \text{qty})\) on all lines; if **0**, use header `total_weight_kg` / `received_weight` |
| **Total qty** | \(\sum \text{line qty}\) |
| **Total goods BDT** | \(\sum \text{line goods BDT}\) after goods + surplus (per line) |
| **Total CIF** | \(\sum (\text{unit goods}+\text{unit freight}+\cdots) × \text{qty}\) on all lines |

---

## 4 — Per-line unit cost (target)

**Purchase price currency**

| Line price in | Unit goods BDT (before surplus) |
| :--- | :--- |
| Purchase / foreign (e.g. GBP) | `purchase_price × shipment material rate` |
| BDT already | `purchase_price` (rate 1) |

### Material surplus (carriage / AP > line list)

Line list goods BDT = sum of `(purchase_price × material rate × qty)` OR BDT prices.

\[
\text{material surplus BDT} = \text{material pool BDT} - \text{line list goods BDT}
\]

| Surplus | Action |
| :--- | :--- |
| **> 0** | Spread to lines: each line gets \((\text{line goods BDT} / \text{total line goods BDT}) × \text{surplus}\). Add to line as extra goods BDT (÷ qty for unit). |
| **≤ 0** | No surplus share (do not invent negative goods). |

### Freight

1. Lines with **unit kg > 0:** unit freight BDT = unit kg × freight BDT per kg.
2. Lines with **unit kg = 0:** after step 1, assign **remaining** freight BDT (if any) by **qty share** of zero-weight lines only.

### Other buckets (per unit)

| Bucket | Per unit |
| :--- | :--- |
| **customs** | \((\text{unit CIF} / \text{total CIF}) × \text{customs pool}\) |
| **handling** | handling pool ÷ total qty |
| **other** | other pool ÷ total qty (capitalizable only) |
| **finance** | \((\text{unit line goods BDT incl. surplus} / \text{total goods BDT}) × \text{finance pool}\) |

**Unit CIF** = unit goods BDT (incl. surplus) + unit freight BDT.

Handling / other by qty: simple ops rule; heavy and light units get the same per piece.

---

## 5 — Algorithm order

```text
1. Build capitalizable BDT pools per bucket (paid + provisional rules).
2. Shipment material rate.
3. Freight BDT per kg (kg basis).
4. For each line: goods BDT, then material surplus share, then freight BDT.
5. Sum total qty, total goods BDT, total CIF.
6. For each line: customs, handling, finance, other (per §4).
7. Unit landed = sum of parts. Round per line; customs pool should match allocated customs within rounding.
```

**Do not** use step 1’s all-foreign average in steps 4–7.

---

## 6 — Edge cases

| Case | Rule |
| :--- | :--- |
| No material pays yet | Provisional material pool from issued bills; material rate from bill FX or 1 |
| No freight pool | Unit freight = 0 |
| total CIF = 0 | Customs share = 0 |
| total goods BDT = 0 | Finance share = 0; surplus split = 0 |
| total qty = 0 | No qty-based handling/other |
| All weights zero | All freight by qty |
| Mixed pay / partial bill | Pool uses paid BDT + unpaid open at bill rate |

**Restamp:** when a new pay, credit, bill edit, or weight/qty change — rerun steps 1–7.

---

## 7 — Worked example (shipment 53, Aveeno)

**SKU:** Aveeno Moisturising Lotion 500ML, qty 12. Section is for **listing only** — material rate is **shipment-wide**.

### Pools and constants (paid, capitalizable)

| Item | Value |
| :--- | ---: |
| Material pool | **262,382.40 BDT** (1,561.80 GBP) → rate **168.00** |
| Line list goods (Σ qty × price GBP × rate) | ≈ **256,887 BDT** |
| **Material surplus** | ≈ **5,495 BDT** (spread by line goods BDT share) |
| Freight pool | **163,265 BDT** |
| Kg basis (Σ line kg×qty) | **145** (matches header on this shipment) |
| Freight BDT/kg | **1,125.97** |
| Customs / handling / other pools | 5,000 / 3,400 / 300 BDT |
| Total qty | **1,101** |

### This SKU — unit parts (rounded)

| Part | How | BDT / unit |
| :--- | :--- | ---: |
| Goods (price) | 5.21 × 167.029974 | 870.23 |
| Material surplus share | line goods ÷ total goods × surplus ÷ 1 | ≈ **296.5** |
| Goods + surplus | | ≈ **1,166.7** |
| Freight | 0.595785 × 1,125.97 | 670.83 |
| **Unit CIF** | | ≈ **1,837.6** |
| Customs | 5,000 × unit CIF ÷ **total CIF** | ≈ **18.09** |
| Handling | 3,400 ÷ 1,101 | 3.09 |
| Other | 300 ÷ 1,101 | 0.27 |
| Finance | — | 0 |

**Total CIF** ≈ **507,747 BDT** (= prior line CIF ≈ 420,252 + material surplus 87,495). Customs check: Σ(customs per unit × qty) ≈ **5,000** BDT.

### Unit landed (all buckets)

\[
1{,}166.7 + 670.83 + 18.09 + 3.09 + 0.27 \approx \mathbf{1{,}859\ BDT\ per\ bottle}
\]

**Without surplus** (old mistake when AP matches price only): ≈ **1,563 BDT** — too low when material AP > line list.

---

## 8 — Reference

- Spec bucket splits: [spec.md](spec.md) US-1 table.
- Human worked numbers depend on live pays; steps 1–7 are the contract.