# Shipment Lifecycle & Workflow Specification

This document details the step-by-step business flow and maps each lifecycle stage to its corresponding APIs and RPCs.

---

## Lifecycle Overview

```
[ STAGE 1: DRAFT CREATION ] ➔ [ STAGE 2: EDIT ITEMS, PAYMENTS & BOXES ] ➔ [ STAGE 3: RECEIVE & POST INVENTORY ]
  • RPC: create_shipment_draft   • APIs: shipment_items CRUD               • RPC / API: finalize_shipment_receive
  • Creates header & payments   • APIs: shipment_payments CRUD            • Wallet ledgers & inventory posting
                                 • APIs: shipment_boxes CRUD
```

---

## Stage 1: Minimal Draft Creation (`status: 'draft'`)

* **Action**: User fills basic shipment details and creates a draft.
* **Execution**: Single RPC function creates shipment header and initial payments in 1 transaction.
* **API / RPC Used**:
  * [create_shipment_draft.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/shipment/rpc/create_shipment_draft.md) (`supabase.rpc('create_shipment_draft', ...)`)

---

## Stage 2: Incremental Editing & Bulk Balancing (Items, Payments & Boxes)

* **Action**: User iteratively adds items, performs bulk price/weight balancing, updates payment amounts/sources, and records box weights.
* **Key Operations**:
  * **Bulk Item Price Balancing**: Update unit purchase prices across multiple or all items in a single batch call when vendor invoice or exchange rates are adjusted.
  * **Bulk Item Weight Balancing**: Update product weights (`product_weight_gm`) and packaging weights (`package_weight_gm`) across all items or auto-distribute total cargo bill weight proportionally across items.
* **APIs Used**:
  * **Items (Single & Bulk Upsert)**: `supabase.from('shipment_items').upsert([...])` — [shipment_item_api.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/shipment/api/shipment_item_api.md)
  * **Payments**: `supabase.from('shipment_payments').upsert(...)` — [shipment_payment_api.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/shipment/api/shipment_payment_api.md)
  * **Boxes**: `supabase.from('shipment_boxes').upsert(...)` — [shipment_box_api.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/shipment/api/shipment_box_api.md)

---

## Stage 3: Receiving & Inventory Posting (`status: 'received'`)

* **Action**: User marks shipment as received after final weight and rate verification.
* **Operations Executed**:
  1. Calculate effective conversion rates from `shipment_payments`.
  2. Post wallet ledger entries for vendor and cargo accounts.
  3. Post batch physical inventory stock to products (`inventory_added = true`).
  4. Lock shipment header against hard deletion.






