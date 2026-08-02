# Stock & Inventory Lifecycle Specification

This document details the step-by-step business flow for stock management, line-item quantity splits, auto-acceptance, and tenant allocations.

---

## Lifecycle Overview

```
[ STAGE 1: CONFIGURE STOCK TYPES ] ➔ [ STAGE 2: SHIPMENT ITEM SPLITS ] ➔ [ STAGE 3: STOCK COMMIT & TENANT ALLOCATION ]
  • API: global_stock_types CRUD      • API: global_stocks upsert          • API: Update shipment status 'Ready Stock'
                                      • RPC / API: auto_accept_splits      • RPC: bulk_allocate_shipment_stock
```

---

## Stage 1: Stock Type Configuration

* **Action**: Admin configures stock categories (e.g. *Standard Sellable*, *Damaged*, *Hold*, *Display Sample*).
* **APIs Used**:
  * `global_stock_types` CRUD operations — [stock_type_api.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/stock/api/stock_type_api.md)

---

## Stage 2: Shipment Item Quantity Splits

* **Action**: While shipment is in `"Warehouse Received"` status, each shipment item's ordered quantity is allocated into stock pools.
* **Validation**: Total allocated quantity across all splits for an item must equal `shipment_items.ordered_quantity`.
* **Shortcut Option (Auto Accept)**:
  * User triggers "Auto Accept Splits" to allocate 100% of pending quantities to the default `"Standard Sellable"` stock type.
* **APIs / RPCs Used**:
  * **Manual Splits**: `global_stocks` upsert / insert / delete — [global_stock_api.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/stock/api/global_stock_api.md)
  * **Auto Accept Splits**: Bulk replace pending item stock entries — [global_stock_api.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/stock/api/global_stock_api.md#3-auto-accept-splits-bulk-replacement)

---

## Stage 3: Stock Commitment & Tenant Allocation

* **Action**: Once splits are complete for all items, the shipment is promoted to status `"Ready Stock"`.
* **Tenant Distribution**: Stock quantities in `global_stocks` are allocated from parent tenant to child/shop tenants.
* **APIs / RPCs Used**:
  * **Shipment Promotion**: Update shipment header `status: "Ready Stock"`, `stock_ready: true`.
  * **Tenant Allocation**: `supabase.rpc('bulk_allocate_shipment_stock', ...)` — [bulk_allocate_shipment_stock.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/stock/rpc/bulk_allocate_shipment_stock.md)
  * **Direct Allocation CRUD**: `global_stock_allocations` CRUD — [stock_allocation_api.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/stock/api/stock_allocation_api.md)
