# Thrift Sales & Reports — Scenario Examples

Canon: [sales/schema.md](./sales/schema.md) · [sales/workflow.md](./sales/workflow.md) · [reports/workflow.md](./reports/workflow.md)

Worked examples of every major money / parcel / report case.  
**Inbound shipment & stock schemas are unchanged.** COGS = live `compute_thrift_landed_unit_cost(stock_id)`.

Money amounts in ৳. Fee allocation uses **sell-value share**. Rounding: penny-fix on last line in real RPC; examples use exact thirds where noted.

---

## Shared cast

| Piece | Detail |
| :--- | :--- |
| Item A | From **inbound shipment 1**, sell `1000` |
| Item B | From **inbound shipment 2**, sell `2000` |
| Line total | `3000` |
| Shares | A = `1/3`, B = `2/3` |
| Assume landed COGS | A = `400`, B = `900` (examples only — always computed live) |

---

## 1. Offline (in-store) sale

**What happens:** Customer pays at desk. No courier. Stock walks out.

| Step | System |
| :--- | :--- |
| Create | `sale_channel = IN_STORE`, `payment_status = PAID`, fees `0` |
| Ledger | `REVENUE = 3000` |
| PnL | Immediate `outcome = DELIVERED` for both lines |
| Delivery | `delivery_status = null` |

**PnL lines**

| Line | sell | fees | cogs (live) | net |
| :--- | ---: | ---: | ---: | ---: |
| A / ship 1 | 1000 | 0 | 400 | 600 |
| B / ship 2 | 2000 | 0 | 900 | 1100 |

**Shipment report:** ship1 net `600`, ship2 net `1100`.

---

## 2. Online sale — customer pays delivery + COD fee; shop pays packing

**Fees at create**

| Fee | Amount | Payer |
| :--- | ---: | :--- |
| Delivery | 100 | CUSTOMER |
| COD fee | 50 | CUSTOMER |
| Packing / print | 10 | SHOP |

```text
cod_expected = 3000 + 100 + 50 = 3150
```

| Step | System |
| :--- | :--- |
| Create | `COD_PENDING`, `delivery_status = PENDING`, stock `SOLD`; e.g. `courier_provider_id` → Pathao + name snapshot |
| Ledger | `REVENUE = 3000`, `EXPENSE packing = 10` |
| PnL | **None yet** (wait for deliver / RTO) |
| Catalog | Provider from seeded **system** catalog or a **tenant custom** (`is_system=false`); system rows not editable by tenant |

Customer is asked to pay **3150** to the courier. Shop already spent **10** on packing.

---

## 3. Same order — delivered + COD remitted

**Parcel:** `PENDING → … → DELIVERED` → write PnL `DELIVERED`.

**Shop fee pool for PnL:** only packing `10` (delivery/COD are customer-paid).

| Line | sell | alloc packing | cogs | net |
| :--- | ---: | ---: | ---: | ---: |
| A / ship 1 | 1000 | 3.33 | 400 | 596.67 |
| B / ship 2 | 2000 | 6.67 | 900 | 1093.33 |

**Remittance (separate):** courier pays shop ~`3150` (or less if disputes) → remittance RPC `outcome = PAID` (allowed even when remitted &lt; expected).  
**No second `REVENUE`.** Remittance does not change PnL or `cod_expected`.

**Invoice P&L:** revenue `3000`, cogs `1300`, fees `10`, net `1690`.  
**Shipment P&L:** ship1 ≈ `596.67`, ship2 ≈ `1093.33`.

---

## 4. Situation A — No pickup / RTO (never delivered)

Customer did **not** pick up; courier returns the parcel. **Whole invoice.** No `thrift_sales_returns` row.

**Assume courier bills:** forward delivery `100` + RTO return `80`. Packing `10` already spent.

| Step | System |
| :--- | :--- |
| Close | Invoice RTO: `delivery_status = RETURNED`, `close_reason = RTO`, `status = RETURNED`, `payment_status = REFUNDED` |
| Invoice `return_courier_amount` | `80` |
| Stock | All lines restored `AVAILABLE` |
| Ledger | `REFUND = 3000`; `LOSS` delivery `100`; `LOSS` return `80`; **keep** packing `EXPENSE 10` |
| PnL | All lines `outcome = RTO`, `sell_amount = 0` |

**RTO fee pool:** `100 + 10 + 80 = 190`

| Line | sell | alloc fees | cogs | net (loss) |
| :--- | ---: | ---: | ---: | ---: |
| A / ship 1 | 0 | 63.33 | 0 | −63.33 |
| B / ship 2 | 0 | 126.67 | 0 | −126.67 |

**Shipment report:** logistics loss only on both inbound shipments.

---

## 5. Situation B — Partial return (customer paid, return some items)

**Return items UI (separate):** Invoice detail → **Return items** (not Mark RTO). Pick line A only → …

| Step | System |
| :--- | :--- |
| UI / RPC | **Return items** → `create_thrift_sales_return` with line A only, `condition = SELLABLE` |
| Return doc | `refund_amount = 1000`, `return_courier_amount = 60` |
| Stock | A → `AVAILABLE`; B stays `SOLD` |
| Ledger | `REFUND = 1000`; `LOSS = 60` |
| Invoice | `status = PARTIALLY_RETURNED`, `payment_status = PARTIALLY_REFUNDED`, `close_reason = null` |
| PnL | **Only A** → `CUSTOMER_RETURN`; B stays `DELIVERED` |

**After partial return**

| Line | outcome | sell | fees (example) | cogs | net |
| :--- | :--- | ---: | ---: | ---: | ---: |
| A / ship 1 | `CUSTOMER_RETURN` | 0 | packing keep 3.33 + return 60 = 63.33 | 0 | −63.33 |
| B / ship 2 | `DELIVERED` | 2000 | packing 6.67 | 900 | 1093.33 |

**Shipment report:** ship1 takes return loss; ship2 keeps delivered profit.

---

## 6. Situation B — Full return via return doc (all items)

Same as §5 but select **A and B**.

| Invoice | `status = RETURNED`, `payment_status = REFUNDED`, `close_reason = CUSTOMER_RETURN` |
| Ledger | `REFUND = 3000`; `LOSS` = this return’s courier |
| PnL | Both lines `CUSTOMER_RETURN` |
| Diff vs RTO | Customer had goods / paid; use **return tables**, not invoice RTO |

---

## 7. Cheat sheet — no pickup vs paid return

| | **A. No pickup (RTO)** | **B. Paid / received return** |
| :--- | :--- | :--- |
| Delivered? | No | Yes (or Offline paid) |
| Document | Invoice RTO close | `thrift_sales_returns` + items |
| Scope | **Always whole** invoice | **Partial or full** |
| `close_reason` | `RTO` | `CUSTOMER_RETURN` only when all lines returned |
| Invoice status | `RETURNED` | `PARTIALLY_RETURNED` or `RETURNED` |
| Forward delivery loss | Yes (shop eats) | Not re-charged; sunk shop fees stay on delivered lines / returned lines as allocated |
| Return courier | On **invoice** | On **return** header |
| Staff UI | **Mark RTO** (whole order) | **Return items** on invoice + **Returns management** list/hub |

---

## 8. Online — shop pays delivery

Item total `3000`, delivery `100` `SHOP`, other fees `0`.

| At create | Ledger `REVENUE 3000` + `EXPENSE delivery 100`; `cod_expected = 3000` |
| At DELIVERED | PnL allocates delivery `100` → A `33.33`, B `66.67` |
| Net | `3000 − 1300 − 100 = 1600` |

If **RTO** instead: sell `0`; pool still includes delivery `100` (+ return courier); no packing.

---

## 9. Single-item invoice (one inbound shipment)

Only item A `1000`, delivery `100` customer-paid, packing `10` shop-paid → delivered.

| PnL A | sell `1000`, pack `10`, cogs `400`, net `590` |
| Shipment 1 | sole owner of that net |
| Shipment 2 | untouched |

Allocation trivial (share `100%`).

---

## 10. COD outstanding (cash with courier)

Invoice still `ACTIVE` + `COD_PENDING`, maybe already `DELIVERED`.

| Profit report | Uses PnL (if delivered) — sale recognized |
| Cash report | `cod_expected − cod_remitted` on COD queue — **separate** |
| Ledger | Still only create-time `REVENUE`; remittance adds **no** row |

---

## 11. COD written off

Courier will never remit. Staff calls `record_thrift_cod_remittance` with `outcome = WRITTEN_OFF` (+ notes) — same cash-track RPC as remittance, not a separate write path.

| PnL | Unchanged (economics already closed on deliver/RTO) |
| Cash | Drops out of COD outstanding |

---

## 12. Staff mistake

Wrong invoice entered (no returns yet). Erase — do not RTO / do not create a return doc.

| Piece | Rule |
| :--- | :--- |
| Action | Hard-delete invoice + lines |
| Stock | All lines → `AVAILABLE` |
| Ledger / PnL | Scrub (delete invoice-sourced rows / PnL); no `REFUND`/`LOSS` |
| Counter | **Unchanged** — e.g. delete `…00007` → next sale still `…00008` (gap OK) |
| Block | If any `thrift_sales_returns` exist |

---

## 13. Damaged partial return

Return only A with `condition = DAMAGED`, return courier `40`.

| Stock A | `DAMAGED` (not sellable) |
| PnL A | `CUSTOMER_RETURN`, `sell_amount = 0`, `cogs_is_loss = true` → report COGS loss `400` + fees |
| PnL B | Still `DELIVERED` |
| Ledger | `REFUND = 1000`; `LOSS = 40` |

---

## 14. Mixed report rollup (one day)

| Event | Effect on day report |
| :--- | :--- |
| Offline sale (ex 1) | +3000 rev, +1300 cogs |
| Online delivered (ex 3) | +3000 rev, +1300 cogs, +10 fees |
| RTO (ex 4) | +0 rev, +190 fees as loss |
| Partial return A (ex 5) | −1000 rev on A; ship1 loss grows |
| Remittance | Cash card only |

---

## Quick formula card

```text
share_i = line_sell_i / Σ line_sell   (scope = lines in the event)

DELIVERED:
  sell_i = line_sell_i
  fees_i = share_i × (sum of invoice fees where payer = SHOP)
  cogs_i = landed(stock_i) × qty
  net_i  = sell_i − cogs_i − fees_i

RTO (whole invoice, no pickup):
  sell_i = 0
  fees_i = share_i × (courier_amount + packing_if_any + invoice.return_courier_amount)
  cogs_i = 0
  net_i  = −fees_i

CUSTOMER_RETURN (return doc; only returned lines):
  sell_i = 0
  fees_i = prior_shop_fee_alloc_on_line + share_among_returned × return.return_courier_amount
  cogs_i = cogs_is_loss ? landed × qty : 0
  net_i  = −cogs_i − fees_i
  other lines unchanged (stay DELIVERED)
```

Group by `inbound_shipment_id` on `thrift_sales_pnl_lines` for shipment-wise P&L.
