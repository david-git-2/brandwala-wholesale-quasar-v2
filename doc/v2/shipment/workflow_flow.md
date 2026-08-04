# Shipment Lifecycle & Workflow Specification

This document details the step-by-step business flow and maps each lifecycle stage to its corresponding APIs and RPCs.

---

## Lifecycle Overview

```
[ STAGE 1: DRAFT ]  ➔  [ STAGE 2: EDIT ]  ➔  [ STAGE 3: FINALIZE ]  ➔  [ STAGE 4: COST REVISION ]
  • Create header       • Items CRUD          • Stamp landed costs     • Update cost entries
  • (no cost entries     • Cost entries CRUD   • Post wallet ledger     • Recompute costs
    needed yet)          • Boxes CRUD          • Post inventory         • Post variance to ledger
                         • Balance operations  • Lock shipment          • Re-stamp items
                         • Live cost preview
```

---

## Stage 1: Minimal Draft Creation (`status: 'draft'`)

* **Action**: User fills basic shipment details and creates a draft.
* **Execution**: Creates the shipment header only. No cost entries are pre-created — they are added by the user when they're ready to enter rates.
* **API Used**:
  * `supabase.from('shipments').insert(payload)` — [shipment_api.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/shipment/api/shipment_api.md)

---

## Stage 2: Incremental Editing & Balancing (Items, Costs & Boxes)

* **Action**: User iteratively adds items, enters cost/rate entries, performs bulk price/weight balancing, and records box weights.
* **Live Cost Preview**: As items and cost entries change, the **shipment engine** computes landed costs client-side in real-time for instant feedback. No server calls for preview.
* **Key Operations**:
  * **Bulk Item Price Balancing**: Distribute vendor invoice total proportionally across item purchase prices.
  * **Bulk Item Weight Balancing**: Distribute cargo invoice weight proportionally across item package weights.
* **APIs Used**:
  * **Items**: `supabase.from('shipment_items').upsert([...])` — [shipment_item_api.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/shipment/api/shipment_item_api.md)
  * **Cost Entries**: `supabase.from('shipment_cost_entries').upsert(...)` — CRUD for rate/cost inputs
  * **Boxes**: `supabase.from('shipment_boxes').upsert(...)` — [shipment_box_api.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/shipment/api/shipment_box_api.md)

---

## Stage 3: Finalization & Inventory Posting (`status: 'received'`)

* **Action**: User marks shipment as received after verifying weights and rates.
* **Execution**: Single RPC transaction that:
  1. Reads `shipment_cost_entries` and computes effective rates (server-side, authoritative).
  2. Stamps `landed_cost_bdt` on each `shipment_item`.
  3. Iterates through all `shipment_cost_entries`. For any entry where `payment_source = 'wallet'` and `entity_type`/`entity_id` are defined, posts a generic ledger entry to the target wallet entity.
  4. Posts batch physical inventory stock to products (`inventory_added = true`).
  5. Locks shipment header against hard deletion.

> **Important**: The server computes costs independently — it does NOT trust client-side computed values. The client preview is for UX only.

---

## Stage 4: Cost Revision & Variance Posting (post-finalization)

* **Trigger**: Actual exchange rate or cargo bill arrives after goods were already received and selling began.
* **Action**: User updates the cost entry with the actual rate/amount.
* **Execution**:
  1. User edits `shipment_cost_entries` (e.g. changes `exchange_rate` from estimated 168 to actual 172).
  2. System recomputes landed costs via the shipment engine.
  3. Computes per-item variance: `new_landed_cost - old_landed_cost`.
  4. Posts a **single variance ledger entry** to `universal_wallet_ledger` (credited/debited to the specific `entity_type` and `entity_id` linked to the modified cost entry):
     ```json
     {
       "entity_type": "vendor",
       "entity_id": 12,
       "source_type": "shipment_cost_variance",
       "source_id": "88",
       "amount": 5000,
       "metadata": {
         "cost_type": "product",
         "old_rate": 168,
         "new_rate": 172,
         "units_affected": 100,
         "variance_per_unit": 50
       }
     }
     ```
  5. Re-stamps `landed_cost_bdt` on affected `shipment_items` with the new actual cost.

> **Invoice impact**: Already-issued invoices/orders are NOT modified. Each order line snapshots `unit_cost_at_sale` at time of sale. The variance shows up only in accounting reports (Provisional COGS vs Actual COGS).
