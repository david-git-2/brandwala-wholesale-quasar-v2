# Web type-check fix list

Generated from `NODE_OPTIONS=--max-old-space-size=6144 pnpm --filter web type-check` on 2026-10-18.

**Result:** 6 errors in 2 files (exit code 2). **Fixed** in code on 2026-10-18.

---

## 1. `ShipmentCostEntriesPanel.vue` — missing weight fields on item type (5 errors)

**File:** `web/src/modules/procurement_stock/components/ShipmentCostEntriesPanel.vue`  
**Lines:** 796, 811, 812, 818

**Error:** `TS2339` — Property `product_weight` / `package_weight` does not exist on the inline cast type (only `weight` is declared).

**Cause:** `shipmentItems` is computed with a manual type that omits `product_weight` and `package_weight`, but `estimatedLinesKg`, `distributionPreview`, and weight distribution use those fields (same as `ShipmentWeightBalanceCard.vue` and the store’s `GlobalShipmentItem`).

**Fix (pick one):**

- [x] Use `shipmentStore.currentShipmentItems ?? []` so items are typed as `GlobalShipmentItem[]` from the store (removed incorrect inline cast with `weight?` only).

**Verify:** `estimatedLinesKg` and `computePackageWeightAdjustments` inputs match `web/src/modules/procurement_stock/utils/weightBalance.ts` (`WeightBalanceItem`).

---

## 2. `ShipmentSettingsDrawer.vue` — excessively deep type instantiation (1 error)

**File:** `web/src/modules/procurement_stock/components/ShipmentSettingsDrawer.vue`  
**Line:** 1825 (`syncCostsFromStore` — assignment from `shipmentStore.currentCostEntries`)

**Error:** `TS2589` — Type instantiation is excessively deep and possibly infinite.

**Cause:** vue-tsc struggles to infer through Pinia store refs plus `.map(mapEntryToCostRow).filter(isVisibleCostRow)` when `currentCostEntries` is tied to a heavy `GlobalShipmentCostEntry` / metadata union. The logic is fine; the checker blows its depth budget.

**Fix options (try in order):**

- [x] `CostEntryRowSource` slim type + read via `shipmentStore.$state.currentCostEntries as unknown as CostEntryRowSource[]`; split watches on shipment id and cost entries (avoid deep Pinia `Database` row inference).

**Verify:** Cost rows still sync when `currentCostEntries` changes and when `savingCosts` is false.

---

## After fixes

```bash
pnpm --filter web exec quasar prepare
NODE_OPTIONS=--max-old-space-size=6144 pnpm --filter web type-check
```

Deploy no longer runs type-check; use `pnpm run frontend:check` or `pnpm --filter web type-check` locally before deploy if you want it.
