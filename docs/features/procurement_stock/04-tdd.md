# Procurement & Stock — Technical Design Document (TDD)

> **Frontend Module Target**: `web/src/modules/procurement_stock/`  
> **Repository Target**: `web/src/modules/procurement_stock/repositories/`  
> **Query Keys**: `web/src/modules/procurement_stock/shared/queryKeys/procurementStockQueryKeys.ts`

---

## 1. Component Architecture & Hierarchy

```text
web/src/modules/procurement_stock/
├── pages/
│   ├── InboundShipmentListPage.vue       # Flat QTable with direct archive actions
│   ├── ShipmentLineItemsV2Page.vue       # Canonical detail: workflow bar, lines & costs
│   ├── ReceiveShipmentPage.vue           # Physical receiving checklist & stock posting
│   ├── ShipmentBoxWeightPage.vue         # Box weights Excel grid
│   ├── ShipmentBatchCodePage.vue         # Shipment-scoped batch code analyze
│   ├── BatchCodeListPage.vue             # Parent-owned batch file list
│   ├── BatchCodeDetailsPage.vue          # Standalone batch file details
│   ├── WarehouseStockListPage.vue        # Searchable inventory pool with ATP badges
│   ├── StockLocationsPage.vue            # Interactive 4-tier tree location builder
│   ├── StockMovementsPage.vue            # Immutable movement & transfer audit log
│   └── CargoCompaniesPage.vue            # Freight carrier list & wallet links
├── components/
│   ├── ShipmentBoxWeightGrid.vue         # Box Excel grid
│   ├── ShipmentBatchCodeGrid.vue         # Batch code Excel grid (q-markup-table)
│   ├── BatchCodeRowPasteDialog.vue       # Column paste (one value per line)
│   ├── ShipmentSettingsDrawer.vue        # Gear sidebar; More → Box Weight / Batch Code
│   ├── ArchivedShipmentsModal.vue        # Dedicated dialog for archived records
│   ├── ShipmentFormDialog.vue            # Draft shipment creator modal
│   ├── ShipmentStatusWorkflowBar.vue     # Visual status & progress tag tracker
│   ├── ShipmentCostEntriesPanel.vue      # Apportioned cost entry manager
│   ├── StockMoveLocationDialog.vue       # Location transfer dialog
│   └── StockMoveGradeDialog.vue          # Condition grade transition modal
├── repositories/
│   ├── shipmentRepository.ts             # Supabase RPC invocation client
│   └── warehouseStockRepository.ts       # Location, movement & pool queries
└── shared/
    └── queryKeys/
        └── procurementStockQueryKeys.ts  # TanStack query key definitions
```

---

## 2. Server State Management & TanStack Query Keys

```typescript
export const procurementStockQueryKeys = {
  all: ['procurementStock'] as const,
  shipments: (tenantId: string, params?: Record<string, unknown>) =>
    [...procurementStockQueryKeys.all, 'shipments', { tenantId, ...params }] as const,
  archivedShipments: (tenantId: string) =>
    [...procurementStockQueryKeys.all, 'archivedShipments', { tenantId }] as const,
  shipmentOverview: (shipmentId: string) =>
    [...procurementStockQueryKeys.all, 'shipmentOverview', { shipmentId }] as const,
  allocatableStockList: (params?: Record<string, unknown>) =>
    [...procurementStockQueryKeys.all, 'allocatableStockList', params] as const,
  stockLocations: (tenantId: string) =>
    [...procurementStockQueryKeys.all, 'stockLocations', { tenantId }] as const,
  cargoCompanies: (tenantId: string) =>
    [...procurementStockQueryKeys.all, 'cargoCompanies', { tenantId }] as const,
  childStockAtp: (params?: Record<string, unknown>) =>
    [...procurementStockQueryKeys.all, 'childStockAtp', params] as const,
  batchCodeList: (shipmentId: number) =>
    [...procurementStockQueryKeys.all, 'batchCodeList', { shipmentId }] as const,
};
```

---

## 3. UI Implementation Patterns & Layout Compliance

1. **Zero In-Page Headers**: Never render `<h1>` banners on list pages; rely on top bar breadcrumbs and compact table toolbar.
2. **Table Height Lock**: Lock `q-page` container with `height: calc(100vh - 55px)` and `overflow: hidden`.
3. **No 3-Dots Dropdowns**: Active shipment rows have a direct `Archive` button with a confirmation popup.
4. **Optimistic Archiving**: On archive confirmation, optimistically remove the shipment from active table cache and decrement active total while incrementing `archived_total`.
