# Thrift — TanStack Query Migration

**Canon:** [THRIFT.md](THRIFT.md)
**State management canon:** [STATE_MANAGEMENT.md](STATE_MANAGEMENT.md)

Update this file when a phase completes. Agent: set status to `done` and stop.

**Next phase:** Phase 1 (Query key factory + master data queries)

---

## Background

The thrift module currently stores all server data inside Pinia stores and bare `ref`s in pages, violating the split defined in `STATE_MANAGEMENT.md`:

> Use Pinia for client/UI/workflow state. Use TanStack Query for server state. Do not duplicate the same server dataset in both Pinia state and query cache.

`@tanstack/vue-query` v5 is already installed (`web/package.json`) and wired via `web/src/boot/vue-query.ts`. `shop_order` is the first module to follow the pattern (Phases A–D there). This document tracks the same migration for the thrift module.

---

## Scope Map — What Moves Where

| Resource | Current location | Moves to |
|---|---|---|
| categories, types, boxes, shelves | `thriftStore` (Pinia) | `useThriftMasterDataQuery` composables |
| paginated stocks + meta | `thriftStockStore` (Pinia) | `useThriftStocksQuery` |
| paginated barcodes + meta | `thriftBarcodeStore` (Pinia) | `useThriftBarcodesQuery` |
| thrift settings row | `thriftSettingsStore` (Pinia) | `useThriftSettingsQuery` |
| global currencies | `thriftCurrencyStore` (Pinia, manual cache guard) | `useThriftCurrenciesQuery` |
| shipments (list + detail) | Local `ref`s in pages | `useThriftShipmentsQuery` / `useThriftShipmentDetailQuery` |

**Pinia stores keep:** local filters, pagination cursor, dialog open/close flags, selection state, wizard/step progress.

---

## Phase Summary

| Phase | Status | Area |
|---|---|---|
| 1 | pending | Query key factory + master data queries (categories, types, boxes, shelves) |
| 2 | pending | Currency query — replace manual cache guard |
| 3 | pending | Settings query |
| 4 | pending | Shipment list + detail queries + shipment mutations |
| 5 | pending | Stock query (paginated) + stock mutations |
| 6 | pending | Barcode query (paginated) + barcode mutations |
| 7 | pending | Strip server state from all Pinia stores; delete empty stores |
| 8 | pending | Update all pages/components to consume query composables |

---

## Phase 1 — Query Key Factory + Master Data Queries

**Goal:** Establish the key convention and migrate the four shared reference datasets (categories, types, boxes, shelves) that `thriftStore.loadModuleData` currently fetches in one `Promise.all`.

### Files to create

**`web/src/modules/thrift/shared/queryKeys/thriftQueryKeys.ts`**

```ts
export const thriftQueryKeys = {
  categories: (tenantId: number) => ['thrift', 'categories', { tenantId }] as const,
  types:       (tenantId: number) => ['thrift', 'types',      { tenantId }] as const,
  boxes:       (tenantId: number) => ['thrift', 'boxes',      { tenantId }] as const,
  shelves:     (tenantId: number) => ['thrift', 'shelves',    { tenantId }] as const,
  currencies:  ()                 => ['thrift', 'currencies']               as const,
  settings:    (tenantId: number) => ['thrift', 'settings',   { tenantId }] as const,
  stocks:      (params: object)   => ['thrift', 'stocks',     params]       as const,
  barcodes:    (params: object)   => ['thrift', 'barcodes',   params]       as const,
  shipments:   (tenantId: number) => ['thrift', 'shipments',  { tenantId }] as const,
  shipmentDetail: (id: string)    => ['thrift', 'shipment-detail', { id }]  as const,
}
```

**`web/src/modules/thrift/shared/composables/useThriftMasterDataQuery.ts`**

Four named composables wrapping `useQuery`, each reading from `thriftRepository`:

- `useThriftCategoriesQuery(tenantId: Ref<number>)` — `staleTime: 10 * 60 * 1000`
- `useThriftTypesQuery(tenantId: Ref<number>)` — `staleTime: 10 * 60 * 1000`
- `useThriftBoxesQuery(tenantId: Ref<number>)` — `staleTime: 10 * 60 * 1000`
- `useThriftShelvesQuery(tenantId: Ref<number>)` — `staleTime: 10 * 60 * 1000`

All four use `enabled: computed(() => !!tenantId.value)` to skip fetching before auth resolves.

### Files to update

- `thriftStore.ts` — remove `loadModuleData`, `categories`, `types`, `boxes`, `shelves`, `loading`, `error` state. Keep any UI-only state if present.

### Acceptance criteria

- Pages that previously called `thriftStore.loadModuleData(tenantId)` now call the individual query composables and render correctly.
- Network tab shows one request per resource (not one per component that calls the composable).
- Vue Query Devtools shows `['thrift', 'categories', ...]` etc. with correct stale timers.

---

## Phase 2 — Currency Query

**Goal:** Replace `thriftCurrencyStore` and its manual `if (this.currencies.length) return` early-return guard with a TanStack Query composable using `staleTime`.

### Files to create

**`web/src/modules/thrift/currency/composables/useThriftCurrenciesQuery.ts`**

```ts
export function useThriftCurrenciesQuery() {
  return useQuery({
    queryKey: thriftQueryKeys.currencies(),
    queryFn: () => thriftCurrencyRepository.fetchCurrencies(),
    staleTime: 15 * 60 * 1000,  // reference data — 15 min
  })
}
```

### Files to update / delete

- `thriftCurrencyStore.ts` — remove `currencies`, `loading`, `loadCurrencies`. Delete if nothing UI-specific remains.
- `ThriftCurrencyPage.vue` — swap store usage for `useThriftCurrenciesQuery()`.
- `ThriftShipmentPage.vue` — remove `currencyStore.loadCurrencies()` from `onMounted`.

### Acceptance criteria

- Opening shipment page while currencies are already warm (< 15 min old) makes zero new network requests for currencies.

---

## Phase 3 — Settings Query

**Goal:** Replace `thriftSettingsStore` server-state with a query.

### Files to create

**`web/src/modules/thrift/settings/composables/useThriftSettingsQuery.ts`**

```ts
export function useThriftSettingsQuery(tenantId: Ref<number>) {
  return useQuery({
    queryKey: thriftQueryKeys.settings(tenantId.value),
    queryFn: () => thriftSettingsRepository.fetchSettings(tenantId.value),
    staleTime: 10 * 60 * 1000,
    enabled: computed(() => !!tenantId.value),
  })
}
```

### Files to update / delete

- `thriftSettingsStore.ts` — remove `settings`, `loading`, `loadSettings`. Delete if empty.
- `ThriftSettingsPage.vue` — consume `useThriftSettingsQuery`.
- `ThriftShipmentPage.vue` — remove `settingsStore.loadSettings(tenantId)` from `onMounted`.

---

## Phase 4 — Shipment List + Detail Queries + Mutations

**Goal:** Replace the bare `ref`s and manual `loadShipments()` function in `ThriftShipmentPage.vue` (no store ever existed for shipments).

### Files to create

**`web/src/modules/thrift/shipment/composables/useThriftShipmentQuery.ts`**

- `useThriftShipmentsQuery(tenantId: Ref<number>)` — `staleTime: 2 * 60 * 1000`
- `useThriftShipmentDetailQuery(id: Ref<string>)` — `staleTime: 30_000`

**`web/src/modules/thrift/shipment/composables/useThriftShipmentMutations.ts`**

- `useCreateShipmentMutation()` — on success: `invalidateQueries(['thrift', 'shipments'])`
- `useUpdateShipmentMutation()` — on success: `setQueryData` for detail + invalidate list
- `useDeleteShipmentMutation()` — on success: invalidate list

### Files to update

- `ThriftShipmentPage.vue` — remove `loading ref`, `shipments ref`, `loadShipments()`, `onMounted` orchestration. Consume `useThriftShipmentsQuery`.
- `ThriftShipmentDetailsPage.vue` — consume `useThriftShipmentDetailQuery` + mutation composables.

---

## Phase 5 — Stock Query + Mutations

**Goal:** Replace `thriftStockStore` server-state with a paginated query.

### Files to create

**`web/src/modules/thrift/stock/composables/useThriftStocksQuery.ts`**

- `useThriftStocksQuery(params: Ref<StockQueryParams>)` — paginated `useQuery`, `staleTime: 2 * 60 * 1000`
- Query key includes page, filters, tenantId so each unique filter set is independently cached.

**`web/src/modules/thrift/stock/composables/useThriftStockMutations.ts`**

- `useCreateStockMutation()` — invalidates `['thrift', 'stocks']`
- `useUpdateStockMutation()` — pessimistic: invalidate list
- `useDeleteStockMutation()` — invalidate list

### Files to update

- `thriftStockStore.ts` — remove `stocks`, `loading`, `error`, `page`, `total`, `loadStocks`. Keep filter/sort/selection state.
- `ThriftStockPage.vue` — consume `useThriftStocksQuery(params)`.

---

## Phase 6 — Barcode Query + Mutations

**Goal:** Replace `thriftBarcodeStore` server-state with a paginated query.

### Files to create

**`web/src/modules/thrift/barcode/composables/useThriftBarcodesQuery.ts`**

- `useThriftBarcodesQuery(params: Ref<BarcodeQueryParams>)` — `staleTime: 2 * 60 * 1000`

**`web/src/modules/thrift/barcode/composables/useThriftBarcodeMutations.ts`**

- `useCreateBarcodeMutation()`, `useDeleteBarcodeMutation()` — both invalidate `['thrift', 'barcodes']`

### Files to update

- `thriftBarcodeStore.ts` — remove server state. Keep pagination cursor / UI state if any.
- `ThriftBarcodePage.vue` — consume `useThriftBarcodesQuery`.

---

## Phase 7 — Strip Pinia Stores

**Goal:** Remove all remaining server-state from Pinia stores. Delete stores that become empty.

### Checklist

- [x] `thriftStore.ts` — confirm `loadModuleData` and all data arrays removed (Phase 1). Kept for helper actions.
- [x] `thriftCurrencyStore.ts` — deleted in Phase 2/7 since server-state moved to TanStack Query.
- [x] `thriftSettingsStore.ts` — deleted in Phase 3/7 since server-state moved to TanStack Query.
- [x] `thriftStockStore.ts` — stripped in Phase 5; retained UI pagination/filter state only.
- [x] `thriftBarcodeStore.ts` — stripped in Phase 6; retained UI pagination/filter state only.
- [x] Audit all remaining Pinia `state` fields — verified zero server data in Pinia state.

---

## Phase 8 — Page/Component Sweep

**Goal:** Confirm zero `onMounted` store-fetch calls remain across all thrift pages; clean up any unused imports.

### Pages to audit

| Page | What to verify |
|---|---|
| `ThriftShipmentPage.vue` | No `loadShipments`, no `currencyStore.loadCurrencies`, no `settingsStore.loadSettings` |
| `ThriftShipmentDetailsPage.vue` | Uses `useThriftShipmentDetailQuery` |
| `ThriftStockPage.vue` | Uses `useThriftStocksQuery`; no `thriftStockStore.loadStocks` |
| `ThriftBarcodePage.vue` | Uses `useThriftBarcodesQuery`; no `thriftBarcodeStore.loadBarcodes` |
| `ThriftSettingsPage.vue` | Uses `useThriftSettingsQuery` |
| `ThriftCurrencyPage.vue` | Uses `useThriftCurrenciesQuery` |
| `ThriftCategoryPage.vue` | Uses `useThriftCategoriesQuery` |
| `ThriftTypePage.vue` | Uses `useThriftTypesQuery` |
| `ThriftBoxPage.vue` | Uses `useThriftBoxesQuery` |
| `ThriftShelfPage.vue` | Uses `useThriftShelvesQuery` |

### Acceptance criteria (full module)

- No `loadXxx` Pinia actions remain that call Supabase.
- No `loading` / `error` boolean state in Pinia for server resources.
- All thrift queries visible in Vue Query Devtools with correct keys and stale timers.
- Behaviour parity: loading states, error states, and data display match the old implementation.
- Multiple components sharing the same query key make exactly one network request.
