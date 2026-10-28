# Bills & pays — gaps

What is **not finished** yet vs the money kernel target. Full product scope: [spec.md](spec.md). Build order for engineers: [kernel plan](../../../doc/fix/2026-10-12-bills-pays-kernel-plan.md).

**Status:** `not_built` = missing · `partial` = started · `design` = naming/copy only.

---

## Spine (core money rules — finish these before new pay/bill writers)

_No open BP25 items — duplicate POST with the same `idempotency_key` per books tenant returns the existing pay ([`post_money_in` / `post_money_out`](../../supabase/schemas/bills_pays/05_money_spine.sql))._

---

## Bills, notes, and adapters

| ID | Status | In plain words |
| :--- | :--- | :--- |
| **BP8** | partial | Credit notes and debit notes work in the desk for many cases (compose, vendor refund on AP CN, dropship auto-note). Still missing: **shipment shortage → credit note**, **cash refund to customer** on AR CN (RPC exists, UI does not send amount), full **print** for notes, and using open CN balance on the next bill ([BP11](#pay-leftover-and-fixes)). |
| **BP9** | partial | Generic “create/update draft bill” and “issue bill” RPCs exist. **Shop, shipment, and compose** still call their own older RPCs. Target: every feature uses the same kernel entry with `source_type` / `source_id` / `source_key`. |
| **BP5** | not_built | **Returns** should create a credit note on the bill, not shrink the original total. After-sales does not call `create_bill_adjustment` yet. Extra refund goes to customer custody cashbook. |
| **BP10** | not_built | Features should **list bills and pays** by source (this order, this shipment) and by profile without adding up allocations in the app. Today only some reads exist (`get_bill_net_balances`, adjustments list); shipment still uses custom filters. |
| **BP23** | partial | Bills list page works with keyset pagination (`list_bills_desk_page`). Target **reporting view** `v_kernel_bill_summaries` for one stable “bill + due + party” shape is not built yet. |

---

## Shipment and adapters

_No open WA15 items — shipment AP sync uses `source_key` per bucket (and `bucket:CCY` when mixed); see [procurement money-kernel wiring](../procurement_stock/money-kernel-wiring.md)._

---

## Pay, leftover, and fixes

| ID | Status | In plain words |
| :--- | :--- | :--- |
| **BP11** | partial | Extra money after collect (or open credit on a note) should apply to **the next bill** the same way for customers, vendors, and AP. Today only **customer cash/bank leftover** on pay detail works; AP payout leftover and credit-note balance need one path (`apply_settlement_to_bill`). |
| **BP12** | not_built | Undo a **wrong payout or receipt** without voiding the bill — bill stays issued, “amount still due” goes back up. Customer receipt void exists; **AP payout** and generic reverse pay do not. |
| **WA13** | not_built | **Cheque bounced** should reverse the pay (needs [BP12](#pay-leftover-and-fixes)). Cheque fields exist at collect; bounce flow is not built. |

---

## Cashbook (till, safe, FX)

| ID | Status | In plain words |
| :--- | :--- | :--- |
| **BP15** | partial | When tenant cash moves, staff pick **which till/safe** (`cashbook_point`). AP payout and vendor refund record the point. **Customer collect** often does not copy the point onto the pay row and ledger the same way. Point-to-point transfer RPC is later. |
| **BP16** | partial | Each till holds **per-currency pots**; each cash line stores amount, currency, and frozen BDT rate. Tables exist; many paths still behave like **BDT only @ 1**. UI should show pot balances; rate table is only a form default before post. |
| **BP21** | not_built | Cashbook accounts should be tagged **tenant money** vs **customer/vendor custody** so reports never mix “our drawer” with “their advance on file”. |

---

## Later cleanup

| ID | Status | In plain words |
| :--- | :--- | :--- |
| **BP17** | not_built | **Stock FIFO** must run in the warehouse feature **before** issue bill — not inside the kernel. Line stock link should live in line meta, not a legacy column on `bill_lines`. |
| **BP24** | not_built | Merchant profit payout still uses a **special RPC**. Target: same generic pay-out as everything else (`post_money_out` + `source_type=commission`). |
| **BP2** | design | UI still says **wallet** in routes/modules; product name is **cashbook**. Rename when convenient — no behavior change. |
