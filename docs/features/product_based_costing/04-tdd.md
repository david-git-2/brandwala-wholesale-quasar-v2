# Product-Based Costing (PBC) — Technical Design Document (TDD)

> **Frontend Module Target**: `web/src/modules/product_based_costing/`  
> **Repository Target**: `web/src/modules/product_based_costing/repositories/productBasedCostingRepository.ts`  
> **Query Keys**: `web/src/modules/product_based_costing/shared/queryKeys/productBasedCostingQueryKeys.ts`

---

## 1. Component Architecture & Hierarchy

```text
web/src/modules/product_based_costing/
├── pages/
│   ├── ProductBasedCostingPage.vue       # Costing files list with status tabs
│   ├── ProductBasedCostingFileDetailsPage.vue # Live quote builder & items grid
│   └── ProductBasedCostingSharedPreviewPage.vue # Printable client quote sheet
├── components/
│   ├── ProductBasedCostingFileDialog.vue # Create/edit costing batch modal
│   ├── ProductBasedCostingItemsTable.vue # Formula-driven items pricing spreadsheet
│   ├── PbcBacklogSuggestDrawer.vue       # Shortfall waiting list import drawer
│   └── ProductBasedCostingFileWorkflowBar.vue # Status lifecycle tracker
└── repositories/
    └── productBasedCostingRepository.ts  # Supabase RPC invocation layer
```

---

## 2. Server State Management & TanStack Query Keys

```typescript
export const productBasedCostingQueryKeys = {
  all: ['productBasedCosting'] as const,
  files: (params?: Record<string, unknown>) =>
    [...productBasedCostingQueryKeys.all, 'files', params] as const,
  fileDetails: (id: string) =>
    [...productBasedCostingQueryKeys.all, 'fileDetails', id] as const,
  fileItems: (fileId: string) =>
    [...productBasedCostingQueryKeys.all, 'fileItems', fileId] as const,
  backlog: (billingProfileId: string) =>
    [...productBasedCostingQueryKeys.all, 'backlog', billingProfileId] as const,
};
```

---

## 3. Calculation & Formula Invariants

1. **Client-Side Live Preview**: Modifying FX rate or customer markup recalculates line prices and total quote in real-time before saving.
2. **Backlog Auto-Clearing**: When backlog items are inserted into a draft file, their state is updated to `is_consumed = true` to prevent duplicate quoting.
3. **Demand Desk Alignment**: Procurement stages (`procuring` $\rightarrow$ `ready_for_shipment` $\rightarrow$ `delivered`) share identical backend models with catalog shop orders.
