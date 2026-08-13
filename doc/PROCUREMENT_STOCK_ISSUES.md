# Procurement & Stock — Open Architecture Issues

**Module:** `procurement_stock`  
**Architecture (locked):** [v2/shipment](./v2/shipment/) · [v2/stock](./v2/stock/) · [v2/wallet](./v2/wallet/)  
**Updated:** 2026-08-13

Sell model, assign, ATP, listing FK, availability, and soft-allocation retirement are **decided** in the v2 docs — not listed here.

---

## 1. Warehouse ops after receive — deferred

**Solution locked:** [v2/stock/schema.md §2.4](./v2/stock/schema.md) — movement documents + post RPC; `global_stocks` stays balances-only; UI never free-edits qty.

**Still open:** exact table/RPC names and migration SQL. Not required before assign + ATP cutover.

| Gap | Meaning | In first movement cut? |
| :--- | :--- | :---: |
| Availability transfer / adjustment | sellable ↔ held / unsellable; write-off; cycle count | Yes |
| Return inbound | Return doc → qty onto a stock row (usually `held`) | Yes |
| Receive rollback | Clean reverse of posted stock + stamps | Yes |
| Partial receive | Cost share when only part of the batch arrives | Later |
| Weight audit | History when package weights / cost inputs change | Later |
| Transfer / multi-location | Later if single warehouse | Later |

---

## 2. Cost revision RPC detail

**Solution locked:** [v2/shipment/schema.md §4](./v2/shipment/schema.md) · [workflow Stage 4](./v2/shipment/workflow_flow.md) —

| Rule | Detail |
| :--- | :--- |
| Path | Edit `shipment_cost_entries` via **revision RPC only** → server recompute → re-stamp `shipment_items.landed_cost_bdt` |
| After finalize | No silent upsert of rates / entries |
| Stock | Qty only — cost always via `shipment_item_id` → stamp |
| Posted invoices | Provisional `unit_cost_price` / `landed_cost_bdt` snapshot **frozen** |
| Report / investor P&L | `revenue − (current stamp × sold_qty)` — join living stamp, not invoice snapshot |
| Wallet variance | **Stub-optional** — not required for day-one report truth ([schema §4.2](./v2/shipment/schema.md)) |

**Still open:** exact RPC name / args / return shape; which module action may call it. Wallet on revise is locked stub-skip — [§3](#3-wallet-posts-on-finalize--revision).

---

## 3. Wallet posts on finalize / revision

**Solution locked:** Money ≠ shipment status. Day one finalize / revision = **cost stamp + stock only**. Ledger posts are **stub-skip**; settle cash/credit later via an explicit Pay / Settle action. Details: [shipment schema §1.2 money handoff](./v2/shipment/schema.md) · [workflow Stages 3–4](./v2/shipment/workflow_flow.md) · [wallet workflow Stage 2](./v2/wallet/workflow_flow.md).

| Event | Wallet posts (day one) |
| :--- | :--- |
| Finalize — `payment_source` / payee **null** | **Skip** — costing only |
| Finalize — cash / credit / wallet (+ entity) set | **Stub-skip** — keep intent on cost entry; **do not** post ledger |
| Cost revision | **Stub-skip** — re-stamp only; no auto wallet delta |
| Explicit Pay / Settle (later) | **Required** when that action runs — debit/credit tenant + payee; `source_type` / `source_id` = shipment (cost-entry id optional in metadata) |
| Vendor return (cash refund / store credit) | Separate from finalize — see workflow Stage 4 return table |

**Why:** Receive must not depend on treasury readiness; sell-first / cost-later often revises freight after receive; reports join living stamp × sold qty (no variance ledger needed day one).

**Still open:** exact Pay / Settle RPC + UI when AP/cash UX is built. Not required for assign + ATP + finalize cutover.
