# Product-Based Costing (PBC) — Page-to-API Matrix

Mapping of all costing pages, modals, formula calculators, and backlog drawers to their corresponding Supabase RPCs, database operations, and TanStack Vue Query cache keys.

---

## 📊 Interaction & Endpoint Matrix

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation / Optimistic Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **`ProductBasedCostingPage`** | Mount / Filter by Status | `useCostingFilesQuery` | `Table: product_based_costing_files` | Cached on `productBasedCostingQueryKeys.files` (`staleTime: 30s`) |
| **`ProductBasedCostingFileDialog`** | Submit "Create Costing File"| `useCreateCostingFileMutation` | `RPC: create_costing_file` | Appends file to list, navigates to detail |
| **`PbcBacklogSuggestDrawer`** | Drawer Open / Refresh | `useBacklogItemsQuery` | `RPC: list_pbc_backlog_items` | Cached on `productBasedCostingQueryKeys.backlog` |
| **`PbcBacklogSuggestDrawer`** | Click "Add Selected to File" | `useImportBacklogMutation` | `RPC: add_pbc_backlog_to_file` | Consumes backlog rows; refetches file items |
| **`ProductBasedCostingFileDetails`** | Update FX / Markup Rates | `useUpdateFileHeaderMutation` | `Table: product_based_costing_files` | Recalculates quoted totals across line items |
| **`ProductBasedCostingFileDetailsV2Page`** | Table / card toggle | `itemsView` (localStorage) | No RPC | Same item query cache |
| **`ProductBasedCostingFileDetailsV2Page`** | Load lines (both views) | `useProductBasedCostingItemsInfiniteQuery` | `RPC: list_product_based_costing_items` | `productBasedCostingQueryKeys.itemsInfinite` |
| **`ProductBasedCostingFileDetailsV2Page`** | Card catalog meta | `usePbcItemProductCatalogMap` | `Table: products` (select by ids from loaded lines) | Keyed by sorted `product_id` list |
