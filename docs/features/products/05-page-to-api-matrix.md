# Products & Tag Catalog — Page-to-API Matrix

Mapping of all product views, brand pages, batch uploaders, and universal tag lookups to their corresponding Supabase RPCs, database operations, and TanStack Vue Query cache keys.

---

## 📊 Interaction & Endpoint Matrix

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation / Optimistic Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **`ProductsPage`** | Mount / Search / Filter | `useProductListQuery` | `RPC: list_products_paginated` | Cached on `productsQueryKeys.list` (`staleTime: 60s`) |
| **`ProductCreateDialog`** | Submit "Create Product" | `useCreateProductMutation` | `Table: products` | Invalidates `productsQueryKeys.lists()` |
| **`ProductDetailsPage`** | Update Specs / Weights | `useUpdateProductMutation` | `Table: products` | Invalidates `productsQueryKeys.detail` |
| **`ProductBrandsPage`** | Create / Edit Brand | `useBrandMutations` | `Table: product_brands` | Invalidates `productsQueryKeys.brands` |
| **`ProductCategoriesPage`** | Create / Edit Category | `useCategoryMutations` | `Table: product_categories` | Invalidates `productsQueryKeys.categories` |
| **`BulkImportDialog`** | Upload Batch Catalog | `useBulkCreateProductsMutation` | `Table: products` (bulk insert) | Refetches catalog list |
| **`TagSelectorWidget`** | Mount / Load Grade Swatches| `useTagsQuery` | `RPC: list_tags_for_category` | Cached on `tagQueryKeys.list` (`staleTime: 10m`) |
