# Stock & Inventory Lifecycle Specification

Receive (qty checklist) → stock @ default location + **standard grade** → organize via movements (availability / grade / bin) → assign → list/sell on shared ATP.

**Design lock:** [schema.md](./schema.md). Shipment finalize UX: [../shipment/workflow_flow.md](../shipment/workflow_flow.md) Stage 3. Grades: [../../tag/presets.md](../../tag/presets.md).

---

## Lifecycle Overview

```
[ STAGE 1: AVAILABILITY + GRADE + LOCATION ] ➔ [ STAGE 2: RECEIVE ] ➔ [ STAGE 3: READY + ASSIGN + LIST ]
  • sellable | held | unsellable              • qty checklist UI       • status → received
  • grade_tag_id → stock_grade tags           • ordered vs received    • assign one child
  • stock_locations (bin/zone)                • post sellable +        • listing.global_stock_id
  • (grade never drives ATP)                    standard @ default     • ATP = pickable sellable − holds
                                                location
                                              • no damage/grade on recv
```

---

## Stage 1: Availability + grade + location

* **Sell gate (locked):** `stock_availability` = `sellable` | `held` | `unsellable` on `global_stocks`.
* **Grade (locked):** `grade_tag_id` → system tag (`module_key = stock_grade`). Warehouse day one: `standard` \| `open_box` \| `box_damage` \| `box_less` \| `badly_damaged`.
* **Where (locked):** `stock_locations` + required `global_stocks.location_id`. Availability ≠ bin ≠ grade.
* **ATP (locked):** `availability = sellable` **and** `location.is_pickable` − draft invoice holds − shop cart holds. **Grade does not gate ATP** (open_box etc. stay sellable).
* **Live bridge:** `global_stock_types` until W7 cutover — [stock_type_api.md](./api/stock_type_api.md) transitional.

---

## Stage 2: Receive → `global_stocks`

* **PO + GR on shipment line:** `ordered_quantity` (bought) + `received_quantity` (counted, persisted on finalize). Short = ordered − received. No separate PO/GR module — [../shipment/schema.md](../shipment/schema.md) §1.3.
* **UI (locked):** checklist — product image, name, ordered qty, received qty (prefill = ordered). See [../shipment/workflow_flow.md](../shipment/workflow_flow.md) Stage 3.
* **Post (W7):** each line’s `received_quantity` → one parent stock row: **`sellable`** + grade **`standard`** at **default leaf** location.
* Balance grain: `(shipment_item_id, availability, location_id, grade_tag_id)`.
* **Do not** capture damage, grade splits, or put-away bins on receive — use Stage 4 movements.
* Multi-wave partial receive + cost share remains **deferred**.
* APIs: finalize writes `received_quantity` + builds `p_stock_rows` (include `grade_tag_id` / default standard); [global_stock_api.md](./api/global_stock_api.md).

---

## Stage 3: Ready + assign + list/sell

* Promote shipment to `received`. Qty lives only on parent `global_stocks` (per location + grade).
* **Assign (Option A):** `assigned_child_tenant_id` = list permission only.
* **List:** `shop_product_listings.global_stock_id` (not allocation id).
* **Display:** real ATP or dummy override; UI may show grade label.
* **Sell:** desk picks `global_stock_id` (shows location + grade); shop may auto-allocate pickable sellable rows; shared ATP formula.
* RPCs: assign replaces soft-qty meaning of [bulk_allocate_shipment_stock.md](./rpc/bulk_allocate_shipment_stock.md).

---

## Stage 4: Warehouse movements (ops)

After receive, all qty / availability / **grade** / **location** changes go through movement docs — [schema §2.5](./schema.md).

* Location transfer (bin A → bin B) — organize put-away after the door check
* Availability transfer (same bin) — quarantine / write-off (`held` | `unsellable`)
* **Grade transfer** — e.g. `standard` → `open_box` / `box_damage` / `box_less` (usually stay `sellable`); or → `badly_damaged` with `unsellable`
* Return inbound → usually `held` @ returns location
* Never free-edit stock rows in UI

> Loss, damage grades, and condition are recorded **here**, not on the shipment receive checklist.

---

## Explicit non-goals (this lifecycle)

* Soft qty allocation as a second warehouse  
* Multi-child same batch / request-reassign (day one)  
* **Inter-warehouse / multi-site** transfer (day one = one warehouse; bins only)  
* Reservation ledger in procurement (holds stay on cart / draft invoice)  
* Return/sold columns on `global_stocks`  
* Damage / grade / bin splits on the receive checklist (use movements instead)  
* Discount % on grade tags (pricing elsewhere)  
* Tags as ATP / sell gate (availability only)
