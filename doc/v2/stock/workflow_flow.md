# Stock & Inventory Lifecycle Specification

Receive → put-away at location → parent stock → assign → list/sell on shared ATP.

**Design lock:** [schema.md](./schema.md).

---

## Lifecycle Overview

```
[ STAGE 1: AVAILABILITY + LOCATION ] ➔ [ STAGE 2: RECEIVE ] ➔ [ STAGE 3: READY + ASSIGN + LIST ]
  • sellable | held | unsellable         • post global_stocks     • status → received
  • stock_locations (bin/zone)           • default location       • assign one child (list only)
  • (no tag-driven ATP)                  • default 100% sellable  • listing.global_stock_id
                                         • rare avail. splits     • ATP = pickable sellable − holds
```

---

## Stage 1: Availability + location model

* **Sell gate (locked):** `stock_availability` = `sellable` | `held` | `unsellable` on `global_stocks`.
* **Where (locked):** `stock_locations` + required `global_stocks.location_id`. Availability ≠ bin.
* **ATP (locked):** sellable **and** `location.is_pickable` − draft invoice holds − shop cart holds.
* **Not tags:** optional detail notes/labels never drive ATP.
* **Live bridge:** `global_stock_types.is_sellable` maps into availability until cutover — [stock_type_api.md](./api/stock_type_api.md) transitional.

---

## Stage 2: Receive → `global_stocks`

* Split each line’s ordered qty into parent stock rows by **availability** (default: all `sellable`) at a **location** (default: `stock_locations.is_default`, or explicit put-away).
* Balance grain: `(shipment_item_id, availability, location_id)`.
* Validation: total split = `ordered_quantity` (partial receive deferred).
* Auto-accept → 100% `sellable` @ default location.
* APIs: [global_stock_api.md](./api/global_stock_api.md) (extend for `location_id`).

---

## Stage 3: Ready + assign + list/sell

* Promote shipment to `received`. Qty lives only on parent `global_stocks` (per location).
* **Assign (Option A):** `assigned_child_tenant_id` = list permission only.
* **List:** `shop_product_listings.global_stock_id` (not allocation id).
* **Display:** real ATP or dummy override.
* **Sell:** desk picks `global_stock_id` (shows location); shop may auto-allocate pickable sellable rows; shared ATP formula.
* RPCs: assign replaces soft-qty meaning of [bulk_allocate_shipment_stock.md](./rpc/bulk_allocate_shipment_stock.md).

---

## Stage 4: Warehouse movements (ops)

After receive, all qty / availability / **location** changes go through movement docs — [schema §2.5](./schema.md).

* Location transfer (bin A → bin B)
* Availability transfer (same bin)
* Return inbound → usually `held` @ returns location
* Never free-edit stock rows in UI

---

## Explicit non-goals (this lifecycle)

* Soft qty allocation as a second warehouse  
* Multi-child same batch / request-reassign (day one)  
* **Inter-warehouse / multi-site** transfer (day one = one warehouse; bins only)  
* Reservation ledger in procurement (holds stay on cart / draft invoice)  
* Return/sold columns on `global_stocks`
