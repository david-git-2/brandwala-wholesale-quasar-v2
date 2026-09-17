# Products & Tag Catalog — Technical Design Document (TDD)

> **Frontend Module Target**: `web/src/modules/products/` and `web/src/modules/tag/`  
> **Repository Target**: `web/src/modules/products/repositories/` and `web/src/modules/tag/repositories/`  
> **Query Keys**: `web/src/modules/products/shared/queryKeys/productsQueryKeys.ts`

---

## 1. Component Architecture & Hierarchy

```text
web/src/modules/products/
├── pages/
│   ├── ProductsPage.vue                  # Main product catalog grid & table view
│   ├── ProductDetailsPage.vue            # Product specs, weights & pricing details
│   ├── ProductBrandsPage.vue             # Master brand manager
│   └── ProductCategoriesPage.vue         # Hierarchical category manager
├── components/
│   ├── ProductGrid.vue                   # Visual card-based product grid
│   ├── ProductCreateDialog.vue           # Single product creation modal
│   ├── BulkImportDialog.vue              # CSV / JSON / Excel batch uploader
│   └── ProductFilterDrawer.vue           # Brand, category & price range filters
└── repositories/
    └── productRepository.ts              # Supabase catalog query & batch mutations

web/src/modules/tag/
└── repositories/
    └── tagRepository.ts                  # Universal tag dictionary queries
```

---

## 2. Server State Management & TanStack Query Keys

```typescript
export const productsQueryKeys = {
  all: ['products'] as const,
  lists: () => [...productsQueryKeys.all, 'list'] as const,
  list: (params?: Record<string, unknown>) =>
    [...productsQueryKeys.lists(), params] as const,
  detail: (id: string) =>
    [...productsQueryKeys.all, 'detail', { id }] as const,
  brands: (params?: Record<string, unknown>) =>
    [...productsQueryKeys.all, 'brands', params] as const,
  categories: (params?: Record<string, unknown>) =>
    [...productsQueryKeys.all, 'categories', params] as const,
};

export const tagQueryKeys = {
  all: ['tags'] as const,
  categories: (moduleKey?: string) =>
    [...tagQueryKeys.all, 'categories', moduleKey] as const,
  list: (moduleKey?: string, code?: string) =>
    [...tagQueryKeys.all, 'list', { moduleKey, code }] as const,
};
```

---

## 3. Performance & Taxonomy Caching Invariants

1. **Long Stale Times for Taxonomies**: Master brands, categories, and universal tags use `staleTime: 5m` to `10m` since taxonomy dictionaries rarely change during a session.
2. **Debounced Search**: Product keyword queries are debounced to avoid firing API requests on every keystroke.
3. **Optimistic Tag Binding**: Tag attachment updates reflect immediately in the UI.
