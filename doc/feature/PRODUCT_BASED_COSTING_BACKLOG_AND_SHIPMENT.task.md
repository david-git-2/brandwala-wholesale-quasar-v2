# Execution Task Matrix: Product Based Costing Backlog And Shipment

## Phase 0: Feature Specification & Planning Docs
- **Goal:** Write complete feature blueprint and execution task matrix for low-context phase-by-phase implementation.
- **Depends On:** None
- **Files to Change:**
  - `[NEW]` [PRODUCT_BASED_COSTING_BACKLOG_AND_SHIPMENT.md](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/doc/feature/PRODUCT_BASED_COSTING_BACKLOG_AND_SHIPMENT.md)
  - `[NEW]` [PRODUCT_BASED_COSTING_BACKLOG_AND_SHIPMENT.task.md](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/doc/feature/PRODUCT_BASED_COSTING_BACKLOG_AND_SHIPMENT.task.md)
- **Specification:** Feature spec & task details under `doc/feature/`.
- **Rollback:** Delete newly created feature doc files.
- **Review Gate:** Verification of blueprint contracts and phase boundaries.
- **Status:** [Done]

---

## Phase 1: Database Schema, Foreign Keys & Types
- **Goal:** Migration for `billing_profile_id`, `product_based_costing_backlog_items` table, status `unavailable`, FK retargets to `global_shipments`.
- **Depends On:** Phase 0
- **Files to Change:**
  - `[NEW]` `supabase/migrations/20260905000100_pbc_backlog_and_shipment_schema.sql`
  - `[MODIFY]` `web/src/types/database.types.ts` (generated via `npm run backend:types`)
- **Specification:**
  - Add `billing_profile_id` to `product_based_costing_files` with FK to `billing_profiles(id)`.
  - Retarget `default_shipment_id` on `product_based_costing_files` and `assigned_shipment_id` on `product_based_costing_items` to `global_shipments(id)`.
  - Create table `product_based_costing_backlog_items` with unique `(tenant_id, billing_profile_id, product_id)`.
  - Add RLS policies for backlog table.
- **Rollback:** `DROP TABLE product_based_costing_backlog_items; ALTER TABLE product_based_costing_files DROP COLUMN billing_profile_id;`
- **Review Gate:** Supabase migration applies cleanly; `npm run backend:types` generates valid TypeScript types.
- **Status:** [Done]

---

## Phase 2: SQL RPC Functions & Contracts
- **Goal:** Database RPCs for backlog upsert, listing, consumption, and hardening shipment child line additions.
- **Depends On:** Phase 1
- **Files to Change:**
  - `[NEW]` `supabase/migrations/20260905000200_pbc_backlog_and_shipment_rpcs.sql`
- **Specification:**
  - Implement `upsert_pbc_backlog_from_item(p_costing_item_id)`.
  - Implement `list_pbc_backlog_items(p_tenant_id, p_billing_profile_id)`.
  - Implement `add_pbc_backlog_to_costing_file(p_file_id, p_backlog_ids)`.
  - Harden `add_child_line_to_parent_shipment` and `list_child_procurement_lines` for `delivered_quantity` handling and costing union checks.
- **Rollback:** Drop newly created RPCs.
- **Review Gate:** SQL test queries verify partial fulfillment backlog upserting and consume flows.
- **Status:** [Done]

---

## Phase 3a: Billing Profile UI (Components & Forms)
- **Goal:** UI components for selecting and displaying billing profile on costing files.
- **Depends On:** Phase 2
- **Files to Change:**
  - `[MODIFY]` [ProductBasedCostingFileDialog.vue](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/web/src/modules/product_based_costing/components/ProductBasedCostingFileDialog.vue)
  - `[MODIFY]` [ProductBasedCostingFileDetailsPage.vue](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/web/src/modules/product_based_costing/pages/ProductBasedCostingFileDetailsPage.vue)
- **Specification:** Add billing profile picker dropdown bound to form state and display billing profile badge on file header.
- **Rollback:** Revert UI changes in components.
- **Review Gate:** UI renders billing profile dropdown properly in file dialog.
- **Status:** [Done]

---

## Phase 3b/c: Billing Profile Repository & Integration
- **Goal:** Wire repository and mutation composables for `billing_profile_id` persistence on costing file create/edit.
- **Depends On:** Phase 3a
- **Files to Change:**
  - `[MODIFY]` [productBasedCostingRepository.ts](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/web/src/modules/product_based_costing/repositories/productBasedCostingRepository.ts)
  - `[MODIFY]` [useProductBasedCostingFileMutations.ts](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/web/src/modules/product_based_costing/composables/useProductBasedCostingFileMutations.ts)
- **Specification:** Update repository calls to read/write `billing_profile_id` and auto-sync `order_for`.
- **Rollback:** Revert repository methods.
- **Review Gate:** Saving a costing file persists `billing_profile_id` to Supabase.
- **Status:** [Done]

---

## Phase 4a: Backlog UX Components
- **Goal:** UI components for backlog drawer, fulfillment inline input, and status dropdowns (`unavailable`).
- **Depends On:** Phase 3c
- **Files to Change:**
  - `[NEW]` [PbcBacklogSuggestDrawer.vue](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/web/src/modules/product_based_costing/components/PbcBacklogSuggestDrawer.vue)
  - `[MODIFY]` [ProductBasedCostingItemsTable.vue](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/web/src/modules/product_based_costing/components/ProductBasedCostingItemsTable.vue)
- **Specification:** Build slide-over drawer to suggest open backlog items for current file's billing profile.
- **Rollback:** Remove drawer component and table modifications.
- **Review Gate:** UI drawer opens and lists candidate backlog items.
- **Status:** [Done]

---

## Phase 4b/c: Backlog Live Wiring & Composables
- **Goal:** Wire composables for fetching backlog items, upserting open quantity on fulfillment save, and consuming into costing file.
- **Depends On:** Phase 4a
- **Files to Change:**
  - `[NEW]` [usePbcBacklog.ts](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/web/src/modules/product_based_costing/composables/usePbcBacklog.ts)
  - `[MODIFY]` [ProductBasedCostingFileDetailsPage.vue](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/web/src/modules/product_based_costing/pages/ProductBasedCostingFileDetailsPage.vue)
- **Specification:** Add backlog query and mutations; connect drawer "Add Selected" action to consume RPC.
- **Rollback:** Revert composables and wiring.
- **Review Gate:** Selecting backlog items populates new rows into costing file and clears backlog.
- **Status:** [Done]

---

## Phase 5a: Default Shipment & Batch Add UI
- **Goal:** Header default shipment selector and table batch action bar for shipment additions.
- **Depends On:** Phase 4c
- **Files to Change:**
  - `[MODIFY]` [ProductBasedCostingFileDetailsPage.vue](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/web/src/modules/product_based_costing/pages/ProductBasedCostingFileDetailsPage.vue)
  - `[MODIFY]` [ProductBasedCostingItemsTable.vue](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/web/src/modules/product_based_costing/components/ProductBasedCostingItemsTable.vue)
  - `[MODIFY]` [ShipmentItemCompactDialog.vue](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/web/src/modules/procurement_stock/components/ShipmentItemCompactDialog.vue)
- **Specification:** Add file header shipment binding control, table bulk action "Add to file shipment", and modal picker for custom shipments.
- **Rollback:** Revert UI updates.
- **Review Gate:** Header allows choosing default shipment; table bulk action is enabled for eligible rows.
- **Status:** [Done]

---

## Phase 5b/c: Shipment Live Wiring & Verification
- **Goal:** Wire shipment mutations and execute full end-to-end verification.
- **Depends On:** Phase 5a
- **Files to Change:**
  - `[MODIFY]` [productBasedCostingRepository.ts](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/web/src/modules/product_based_costing/repositories/productBasedCostingRepository.ts)
  - `[MODIFY]` [ProductBasedCostingFileDetailsPage.vue](file:///Users/daviditc/Documents/Personal%20Project/brandwala-wholesale-quasar-v2/web/src/modules/product_based_costing/pages/ProductBasedCostingFileDetailsPage.vue)
- **Specification:** Execute `add_child_line_to_parent_shipment` for single/bulk line additions and update file default shipment ID.
- **Rollback:** Revert live wiring.
- **Review Gate:** Complete flow validation (backlog creation, backlog consumption, batch shipment addition).
- **Status:** [Done]
