# Procurement & Stock — Open Architecture Issues

**Module:** `procurement_stock`  
**Architecture (locked):** [shipment/](./shipment/) · [stock/](./stock/) · [../wallet/](../wallet/)  
**Updated:** 2026-08-15

Sell model, assign, ATP (incl. pickable locations), listing FK, availability, **stock locations**, soft-allocation retirement, movement **pattern**, **two “held”s**, and **return inbound via movement** are **decided** — not listed here as open design.

---

## 1. Warehouse ops + location — implement

**Solution locked:** [stock/schema.md](./stock/schema.md) —

* `stock_locations` catalog + required `global_stocks.location_id`
* Balance grain today `(shipment_item_id, availability, location_id)`; after W7 add `grade_tag_id`
* Movements post all qty / availability / location / grade changes; UI never free-edits
* **ATP** = pickable sellable − draft invoice holds − shop cart holds. Order hold ≠ warehouse `held`.
* Receive posts `received_quantity` as sellable + `standard` @ default leaf (W7b)
* Organize by shipment via movements (W8). Customer return → `return_inbound` (W9)

**Locations catalog (locked names):** table `stock_locations` with SMB hierarchy `shelf` → `slot` → `box` (+ `returns` area), `parent_location_id`; no auto-seed; hard delete via `delete_stock_location` (cascade children). RPCs `list_stock_locations`, `upsert_stock_location`, `set_default_stock_location`, `delete_stock_location` — [stock/api/stock_location_api.md](./stock/api/stock_location_api.md).

**Still open:** movement table/RPC names; `global_stocks.location_id` cutover SQL — **location columns + list/movement RPCs shipped** in `20270814000045` / `20270814000210`. Grade column = W7a.

| Gap | Meaning | In first movement cut? |
| :--- | :--- | :---: |
| Locations CRUD (no seed; hard delete) | SMB shelf/slot/box catalog | **Done** |
| Receive put-away | Persist `received_quantity` on line (GR); post that qty @ default location; short = ordered − received. Organize bins / damage via movements. UI = qty checklist — [shipment/schema.md](./shipment/schema.md) §1.3 | Yes (UX + column → **W6**); grade `standard` → **W7b** |
| Location transfer | Bin A → bin B (same availability) | Yes |
| Availability transfer / adjustment | sellable ↔ held / unsellable; write-off; cycle count | Yes |
| Grade transfer | standard → open_box / box_damage / … | **W7c** |
| Shipment-first organize UI | Filter warehouse by `shipment_id`; deep-link from shipment | **W8** |
| Return inbound | Sales/shop return doc → posted `return_inbound`; default `held` @ returns; staff set grade + availability | **W9** |
| Receive rollback | Clean reverse of posted stock + stamps | Yes |
| Partial receive | Cost share when only part of the batch arrives | Later |
| Weight audit | History when package weights / cost inputs change | Later |
| Inter-warehouse / multi-site | Second warehouse | Later |

---

## 2. Cost revision RPC detail

**Solution locked:** [shipment/schema.md §4](./shipment/schema.md) · [workflow Stage 4](./shipment/workflow_flow.md) —

| Rule | Detail |
| :--- | :--- |
| Path | Edit `shipment_cost_entries` via **revision RPC only** → server recompute → re-stamp `shipment_items.landed_cost_bdt` |
| After finalize | No silent upsert of rates / entries |
| Stock | Qty + location only — cost always via `shipment_item_id` → stamp |
| Posted invoices | Provisional `unit_cost_price` / `landed_cost_bdt` snapshot **frozen** |
| Report / investor P&L | `revenue − (current stamp × sold_qty)` — join living stamp, not invoice snapshot |
| Wallet variance | **Stub-optional** — not required for day-one report truth ([schema §4.2](./shipment/schema.md)) |

**Still open:** which module action may call revise in UI. RPC names locked: `finalize_global_shipment`, `revise_global_shipment_costs`, `settle_shipment_payee`, cost-entry CRUD — see [shipment/rpc/](./shipment/rpc/). Wallet on revise is locked stub-skip — [§3](#3-wallet-posts-on-finalize--revision). Header rate columns dropped — UI reads cost entries + stamp only. Bulk `pay_settle_shipment_costs` was removed from UI on purpose.

---

## 3. Wallet posts on finalize / revision

**Solution locked:** Money ≠ shipment status. Day one finalize / revision = **cost stamp + stock only**. Ledger posts are **stub-skip**; settle cash/credit later via per-payee **Pay** / **Record credit** / **Use credit** (`settle_shipment_payee`). Details: [shipment schema §1.2 money handoff](./shipment/schema.md) · [workflow Stages 3–4](./shipment/workflow_flow.md) · [wallet workflow Stage 2](../wallet/UNIVERSAL_WALLET_LEDGER.md).

| Event | Wallet posts (day one) |
| :--- | :--- |
| Finalize — `payment_source` / payee **null** | **Skip** — costing only |
| Finalize — cash / credit / wallet (+ entity) set | **Stub-skip** — keep intent on cost entry; **do not** post ledger |
| Cost revision | **Stub-skip** — re-stamp only; no auto wallet delta |
| Explicit payee settlement | **Required** when that action runs — RPC **`settle_shipment_payee`** (migration `20270818000010`); per-payee **Pay** / **Record credit** / **Use credit**. `source_type` / `source_id` = shipment. Multiple posts OK. **Not** bulk settle-all cost entries |
| Vendor return (cash refund / store credit) | Separate from finalize — see workflow Stage 4 return table |

**Why:** Receive must not depend on treasury readiness; sell-first / cost-later often revises freight after receive; reports join living stamp × sold qty (no variance ledger needed day one).

**Resolved:** Inline Pay / Record credit / Use credit panel on inbound shipment details (`settle_shipment_payee` + `list_shipment_payee_settlements`). Bulk `pay_settle_shipment_costs` is retired from UI.
