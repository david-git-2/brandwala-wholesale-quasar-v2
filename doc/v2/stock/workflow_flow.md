# Stock & Inventory Lifecycle Specification

Receive → parent stock → assign → list/sell on shared ATP.

**Design lock:** [schema.md](./schema.md).

---

## Lifecycle Overview

```
[ STAGE 1: AVAILABILITY ] ➔ [ STAGE 2: RECEIVE ] ➔ [ STAGE 3: READY + ASSIGN + LIST ]
  • sellable | held | unsellable   • post global_stocks     • status → received
  • (no tag-driven ATP)            • default 100% sellable  • assign one child (list only)
                                   • rare splits            • listing.global_stock_id
                                                            • ATP = sellable − holds
```

---

## Stage 1: Availability model

* **Sell gate (locked):** `stock_availability` = `sellable` | `held` | `unsellable` on `global_stocks`.
* **Not tags:** optional detail notes/labels never drive ATP.
* **Live bridge:** `global_stock_types.is_sellable` maps into availability until cutover — [stock_type_api.md](./api/stock_type_api.md) transitional.

---

## Stage 2: Receive → `global_stocks`

* Split each line’s ordered qty into parent stock rows by **availability** (default: all `sellable`).
* Validation: total split = `ordered_quantity` (partial receive deferred).
* Auto-accept → 100% `sellable`.
* APIs: [global_stock_api.md](./api/global_stock_api.md)

---

## Stage 3: Ready + assign + list/sell

* Promote shipment to `received`. Qty lives only on parent `global_stocks`.
* **Assign (Option A):** `assigned_child_tenant_id` = list permission only.
* **List:** `shop_product_listings.global_stock_id` (not allocation id).
* **Display:** real ATP or dummy override.
* **Sell:** desk + shop deduct parent sellable qty; shared ATP formula.
* RPCs: assign replaces soft-qty meaning of [bulk_allocate_shipment_stock.md](./rpc/bulk_allocate_shipment_stock.md).

---

## Explicit non-goals (this lifecycle)

* Soft qty allocation as a second warehouse  
* Multi-child same batch / request-reassign (day one)  
* Inter-warehouse transfer  
* Reservation ledger in procurement (holds stay on cart / draft invoice)  
* Day-one adjustment / return UI (movement docs later — issues §4.1)  
* Return/sold columns on `global_stocks`
