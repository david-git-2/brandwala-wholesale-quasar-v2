# Procurement & Stock — Open Architecture Issues

**Module:** `procurement_stock`  
**Architecture (locked):** [v2/shipment](./v2/shipment/) · [v2/stock](./v2/stock/) · [v2/wallet](./v2/wallet/)  
**Updated:** 2026-08-13

Sell model, assign, ATP (incl. pickable locations), listing FK, availability, **stock locations**, soft-allocation retirement, and movement **pattern** are **decided** in the v2 docs — not listed here as open design.

---

## 1. Warehouse ops + location — implement

**Solution locked:** [stock/schema.md](./stock/schema.md) —

* `stock_locations` catalog + required `global_stocks.location_id`
* Balance grain `(shipment_item_id, availability, location_id)`
* Movements post all qty / availability / location changes; UI never free-edits

**Locations catalog (locked names):** table `stock_locations` with SMB hierarchy `shelf` → `slot` → `box` (+ `returns` area), `parent_location_id`; no auto-seed; hard delete via `delete_stock_location` (cascade children). RPCs `list_stock_locations`, `upsert_stock_location`, `set_default_stock_location`, `delete_stock_location` — [stock/api/stock_location_api.md](./stock/api/stock_location_api.md).

**Still open:** movement table/RPC names; `global_stocks.location_id` cutover SQL — **location columns + list/movement RPCs shipped** in `20270814000045` / `20270814000210`.

| Gap | Meaning | In first movement cut? |
| :--- | :--- | :---: |
| Locations CRUD (no seed; hard delete) | SMB shelf/slot/box catalog | **Done** |
| Receive put-away | Persist `received_quantity` on line (GR); post that qty @ default location; short = ordered − received. Organize bins / damage via movements. UI = qty checklist — [shipment/schema.md](./shipment/schema.md) §1.3 | Yes (UX + column → **W6**) |
| Location transfer | Bin A → bin B (same availability) | Yes |
| Availability transfer / adjustment | sellable ↔ held / unsellable; write-off; cycle count | Yes |
| Return inbound | Return doc → usually `held` @ returns location | Yes |
| Receive rollback | Clean reverse of posted stock + stamps | Yes |
| Partial receive | Cost share when only part of the batch arrives | Later |
| Weight audit | History when package weights / cost inputs change | Later |
| Inter-warehouse / multi-site | Second warehouse | Later |

---

## 2. Cost revision RPC detail

**Solution locked:** [v2/shipment/schema.md §4](./v2/shipment/schema.md) · [workflow Stage 4](./v2/shipment/workflow_flow.md) —

| Rule | Detail |
| :--- | :--- |
| Path | Edit `shipment_cost_entries` via **revision RPC only** → server recompute → re-stamp `shipment_items.landed_cost_bdt` |
| After finalize | No silent upsert of rates / entries |
| Stock | Qty + location only — cost always via `shipment_item_id` → stamp |
| Posted invoices | Provisional `unit_cost_price` / `landed_cost_bdt` snapshot **frozen** |
| Report / investor P&L | `revenue − (current stamp × sold_qty)` — join living stamp, not invoice snapshot |
| Wallet variance | **Stub-optional** — not required for day-one report truth ([schema §4.2](./v2/shipment/schema.md)) |

**Still open:** which module action may call revise in UI. RPC names locked: `finalize_global_shipment`, `revise_global_shipment_costs`, `pay_settle_shipment_costs`, cost-entry CRUD — see [v2/shipment/rpc/](./v2/shipment/rpc/). Wallet on revise is locked stub-skip — [§3](#3-wallet-posts-on-finalize--revision). Header rate columns dropped — UI reads cost entries + stamp only.

---

## 3. Wallet posts on finalize / revision

**Solution locked:** Money ≠ shipment status. Day one finalize / revision = **cost stamp + stock only**. Ledger posts are **stub-skip**; settle cash/credit later via an explicit Pay / Settle action. Details: [shipment schema §1.2 money handoff](./v2/shipment/schema.md) · [workflow Stages 3–4](./v2/shipment/workflow_flow.md) · [wallet workflow Stage 2](./v2/wallet/workflow_flow.md).

| Event | Wallet posts (day one) |
| :--- | :--- |
| Finalize — `payment_source` / payee **null** | **Skip** — costing only |
| Finalize — cash / credit / wallet (+ entity) set | **Stub-skip** — keep intent on cost entry; **do not** post ledger |
| Cost revision | **Stub-skip** — re-stamp only; no auto wallet delta |
| Explicit Pay / Settle | **Required** when that action runs — RPC **`pay_settle_shipment_costs`** (migration `20270814000100`); debit/credit tenant + payee; `source_type` / `source_id` = shipment |
| Vendor return (cash refund / store credit) | Separate from finalize — see workflow Stage 4 return table |

**Why:** Receive must not depend on treasury readiness; sell-first / cost-later often revises freight after receive; reports join living stamp × sold qty (no variance ledger needed day one).

**Resolved:** Inline Pay / Record credit / Use credit panel implemented with RPC `settle_shipment_payee` and `list_shipment_payee_settlements` (`20270818000010_settle_shipment_payee.sql`).
