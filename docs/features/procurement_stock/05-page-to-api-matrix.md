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
| **`ShipmentLineItemsV2Page`** | Add Catalog Item / Bulk Paste | `useAddShipmentItemMutation` | `RPC: add_shipment_item_from_product` | Refetches `shipmentOverview` details |
| **`ShipmentLineItemsV2Page`** | Save Cost Entries | `useSaveCostEntriesMutation` | `Table: global_shipment_cost_entries` | Recalculates and restamps landed cost BDT |
| **`ShipmentLineItemsV2Page`** | Click "Lock Shipment Costs" | `useLockCostsMutation` | `RPC: lock_global_shipment_costs` | Sets `costs_locked = true`; invalidates `shipmentOverview` |
| **`ReceiveShipmentPage`** | Confirm Inbound Physical Qty | `useFinalizeShipmentMutation` | `RPC: finalize_global_shipment` | Stamps final landed cost, creates `global_stocks`, routes to detail |
| **`WarehouseStockListPage`** | Table Mount / Search Filter | `useWarehouseStockQuery` | `Table: global_stocks` | Cached on `procurementStockQueryKeys.allocatableStockList` |
| **`StockMoveLocationDialog`** | Submit Location Transfer | `useStockMovementMutation` | `RPC: create_and_post_stock_movement` | Updates physical location; invalidates stock & movement lists |
| **`StockMoveGradeDialog`** | Submit Grade Transition | `useStockMovementMutation` | `RPC: create_and_post_stock_movement` | Updates `availability`; invalidates stock & movement lists |
| **`StockLocationsPage`** | Create / Edit Tree Location | `useLocationMutation` | `Table: stock_locations` (leaf/nesting validation) | Invalidates `stockLocations` key |
