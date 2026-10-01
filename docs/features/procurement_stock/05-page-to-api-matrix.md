# Procurement & Stock — Page-to-API Matrix

Mapping of all UI views, buttons, dialog triggers, and user actions to corresponding Supabase RPCs, database mutations, and TanStack Vue Query cache keys.

---

## 📊 Interaction & Endpoint Matrix

| Page / Component | UI Control / Action | Triggered Composable / Method | Backend RPC / Operation | Cache Invalidation / Optimistic Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **`InboundShipmentListPage`** | Table Mount / Filter Search | `useInboundShipmentsQuery` | `RPC: list_global_shipments_paginated` (with `is_archived=false`) | Cached on `procurementStockQueryKeys.shipments` (`staleTime: 30s`) |
| **`InboundShipmentListPage`** | Direct Row Archive Click | `useArchiveShipmentMutation` | `RPC: archive_shipment` | Optimistically removed from list; invalidates active & archived keys |
| **`ArchivedShipmentsModal`** | Modal Open / Refresh | `useArchivedShipmentsQuery` | `RPC: list_global_shipments_paginated` (with `is_archived=true`) | Cached on `procurementStockQueryKeys.archivedShipments` |
| **`ArchivedShipmentsModal`** | Click Restore / Unarchive | `useUnarchiveShipmentMutation` | `RPC: unarchive_shipment` | Invalidates active & archived shipment caches |
| **`ArchivedShipmentsModal`** | Click Purge (Draft/Cancelled) | `usePurgeArchivedShipmentMutation`| `RPC: purge_archived_shipment` | Optimistic item removal; invalidates `archivedShipments` |
| **`ShipmentFormDialog`** | Submit "Create Shipment" | `useCreateShipmentMutation` | `RPC: create_shipment_draft` | Invalidates active shipments list, navigates to detail |
| **`ShipmentLineItemsV2Page`** | Mount / refresh shipment | `useShipmentOverviewDetailsQuery` | `RPC: get_shipment_overview_details` (`sections`, `items`, …) | `procurementStockQueryKeys.shipmentOverview` |
| **`ShipmentLineItemsV2Page`** | Section tab bar (add / edit / delete / reorder) | `globalShipmentStore` → `shipmentSectionRepository` | `Table: global_shipment_sections`; `RPC: reorder_shipment_sections` | Reload sections + items; `currentShipmentSections` |
| **`ShipmentLineItemsV2Page`** | Add Catalog Item / Bulk Paste (active section) | `useAddShipmentItemMutation` | `RPC: add_shipment_item_from_product` (optional `section_id`) | Target: also insert outcome **sellable/ordered** ([PS7](00-gaps.md)). Refetch overview |
| **`ShipmentLineItemsV2Page`** | Batch code column | `useBatchCodeItemsByShipmentQuery` | `batch_code_lists` by `shipment_id` → `batch_code_items` | Client match on barcode / product code |
| **`ShipmentLineBatchCodeDialog`** | Add missing batch | `ensureList` + `batch_code_items` insert | Table insert; patch `batchCodeItemsByShipment` | Compact batch count updates |
| **`ShipmentBatchCodeGrid`** | Arrived checkbox | `updateItem` (`is_arrived`) | `Table: batch_code_items` update | Patch items cache |
| **`ShipmentLineItemsV2Page`** | Save Cost Entries | `useSaveCostEntriesMutation` | `Table: global_shipment_cost_entries` | Recalculates and restamps landed cost BDT |
| **`ShipmentSettingsDrawer`** → Local costs tab | Add / edit / delete local costs | `globalShipmentStore.saveShipmentLocalCost` / `deleteShipmentLocalCost` | `Table: global_shipment_local_costs` (optional `section_id`) | **No** landed stamp; profit uses sum ([PS8](00-gaps.md)) |
| **`ShipmentLineItemsV2Page`** | Click "Lock Shipment Costs" | `useLockCostsMutation` | `RPC: lock_global_shipment_costs` | Sets `costs_locked = true`; invalidates `shipmentOverview` |
| **Shipment** (target) | Close | TBD | `is_closed = true`; block writes | UI read-only ([PS10](00-gaps.md)) |
| **`ReceiveShipmentPage`** | Confirm inbound qty (today) | `useFinalizeShipmentMutation` | `RPC: finalize_global_shipment` (line `received_quantity` + `landed_cost_bdt`) | Stamps line cost, creates `global_stocks` |
| **`ReceiveShipmentPage`** (target) | Add extra outcomes; post stock | TBD | Extra rows `kind` sellable/unsellable; lots from sellable only ([PS7](00-gaps.md)) | Ordered does not create lots |
| **Shipment restamp** (target) | After delivery return + vendor better price | TBD | Return inbound movement, then restamp **on-hand** lots from outcomes | Do not rewrite sold/out qty; abort if on-hand short; not a hand stock patch |
| **`WarehouseStockListPage`** | Table Mount / Search Filter | `useWarehouseStockQuery` | `Table: global_stocks` | Cached on `procurementStockQueryKeys.allocatableStockList` |
| **`StockMoveLocationDialog`** | Submit Location Transfer | `useStockMovementMutation` | `RPC: create_and_post_stock_movement` | Updates physical location; invalidates stock & movement lists |
| **`StockMoveGradeDialog`** | Submit Grade Transition | `useStockMovementMutation` | `RPC: create_and_post_stock_movement` | Updates `availability`; invalidates stock & movement lists |
| **`StockLocationsPage`** | Create / Edit Tree Location | `useLocationMutation` | `Table: stock_locations` (leaf/nesting validation) | Invalidates `stockLocations` key |
| **`ProcurementDemandPage`** | Mount groups / expand group | `useProcurementDemandGroupsQuery`, `useProcurementDemandGroupItemsInfiniteQuery` | `RPC: list_procurement_demand_groups`; `RPC: list_procurement_demand_group_items` (cursor) | `demandGroups` + `demandGroupItems` |
| **`ProcurementDemandPage`** | Save vendor PO qty (row) | `useUpsertPreorderDemandMutation` | `RPC: upsert_preorder_demand` (`p_placed_quantity`) | Invalidates `demandGroupItems` for document |
| **`ProcurementDemandPage`** | Fill place qty / Set vendor (group) | `useFillPreorderDemandPlacedQuantitiesMutation`, `useSetPreorderDemandVendorMutation` | `RPC: fill_preorder_demand_placed_quantities_for_document`; `RPC: set_preorder_demand_vendor_for_document` | Invalidates group items + group headers |
| **`ProcurementDemandPage`** | Open file / Open order | `router.push` | none | `product-based-costing-file-details-page` or `app-shop-order-detail-page` by `document_type` |
| **`ProcurementFulfillPage`** | Mount groups / expand group | `useProcurementFulfillGroupsQuery`, `useProcurementFulfillGroupItemsInfiniteQuery` | `RPC: list_procurement_fulfill_groups` (`procuring` / `ready_for_shipment`); `RPC: list_procurement_fulfill_group_items` (cursor) | `fulfillGroups` + `fulfillGroupItems`; group includes `invoice_stale` |
| **`ProcurementFulfillPage`** | Fill oldest stock (group) | `useFillPreorderDemandOldestStockMutation` | `RPC: fill_preorder_demand_oldest_stock_for_document` | Invalidates demand + fulfill caches |
| **`ProcurementFulfillPage`** | Pick stock | `useUpsertPreorderDemandMutation` | `RPC: upsert_preorder_demand` (`p_stock_picks`) | Invalidates demand + fulfill caches |
| **`ProcurementFulfillPage`** | Change status → ready for shipment | `useSetDemandGroupStatusMutation` | Shop: `RPC: update_shop_order_status_for_staff` (`ready_for_shipment`). PBC: `product_based_costing_files.status` | Status only; no invoice |
| **`ProcurementFulfillPage`** | Create invoice | `useCreateDemandDocumentInvoiceMutation` | `RPC: create_invoice_from_preorder_demand_document` | **Live:** proforma from picks. **Target:** delivery paper ([PS6](00-gaps.md)) |
| **`ProcurementFulfillPage`** | Update invoice | `useSyncDemandDocumentInvoiceMutation` | `RPC: sync_invoice_from_preorder_demand_document` | Live: ready + stale draft/proforma. Target: delivery paper, not bill |
| **`ProcurementFulfillPage`** | Open invoice | `router.push` | none | Live: linked bill. Target: delivery paper, then take / condition bills |
| **`ShipmentSettingsDrawer` More** | Batch Code | Router | `app-procurement-shipment-batch-code` | — |
| **`ShipmentBatchCodePage`** | Mount / ensure list | `ensureList` | `Table: batch_code_lists` select/insert by `shipment_id` | `procurementStockQueryKeys.batchCodeList` |
| **`ShipmentBatchCodePage`** | Add line dialog | `createItem` | `Table: batch_code_items` insert | Patch items cache |
| **`ShipmentBatchCodePage`** | Grid blur save / delete / paste | composable | `batch_code_items` + `paste_batch_code_items` | Patch list cache; no full refetch required |
| **`ShipmentBatchCodeGrid`** | Import CSV dialog | `pasteGrid(itemCount, 0, matrix)` | `RPC: paste_batch_code_items` (append) | Same as paste; clears row drafts |
| **`ShipmentBatchCodeGrid`** | CheckFresh (row) | `openCheckFreshTab(brand)` | `products.brand` via barcode / product code / `product_id` | New tab to brand page |
| **`BatchCodeListPage`** | Row open | Router | `app-procurement-shipment-batch-code` | Hub directory only; no create |
