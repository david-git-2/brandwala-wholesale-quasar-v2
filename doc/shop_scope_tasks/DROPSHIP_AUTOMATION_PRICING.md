# Dropship Store Automation & Pricing Strategy

## Goal
Automate dropship store setup and pricing by allowing tenants to set a global pricing strategy (e.g., +25% markup) instead of manually setting prices per product. Implement automated syncing for new allocations and reactive cost adjustments when the parent's cost changes. Provide a grid-view for bulk pricing management.

## Phases

### Phase 1: Database Schema & RPC
**Goal:** Create the underlying database structures, triggers, and RPCs to handle pricing rules, auto-publishing, and cost adjustments.
**Files to Change:**
- `supabase/migrations/xxxx_shop_pricing_rules.sql` (New)
**Details:**
- Create `shop_pricing_rules` table with `tenant_id`, `shop_id`, `markup_percentage`, and `is_auto_publish`.
- Add RLS policies for tenant isolation.
- Create `bulk_apply_shop_markup` RPC to apply markups across multiple listings.
- Create a database trigger on `global_stock_allocations` to auto-publish a listing into `shop_product_listings` if `is_auto_publish` is true for the tenant's shop.
- Create a database trigger on parent stock updates to reactively adjust `minimum_sell_price` in child tenant listings.

### Phase 2: State Management & Types
**Goal:** Update the frontend data layer to support pricing rules and bulk updates.
**Files to Change:**
- `web/src/modules/shop_order/types/pricing.ts`
- `web/src/modules/shop_order/composables/useShopPricingQuery.ts` (New)
- `web/src/modules/shop_order/composables/useShopPricingMutations.ts` (New)
**Details:**
- Define `ShopPricingRule` interface in `pricing.ts`.
- Implement `useShopPricingRuleQuery` and other data fetching queries in `useShopPricingQuery.ts`.
- Implement `useSaveShopPricingRuleMutation` and `useBulkApplyShopMarkupMutation` in `useShopPricingMutations.ts`.

### Phase 3: Global Pricing Settings UI
**Goal:** Allow users to set and save their global pricing rules.
**Files to Change:**
- `web/src/modules/shop_order/pages/ShopPricingPage.vue`
- `web/src/modules/shop_order/components/ShopPricingRuleCard.vue` (New)
**Details:**
- Build `ShopPricingRuleCard.vue` with inputs for markup percentage and a toggle for auto-publish.
- Embed this card at the top of `ShopPricingPage.vue`.
- Wire the UI to use the new TanStack Query composables (`useShopPricingRuleQuery` and `useSaveShopPricingRuleMutation`) to fetch and update the rule on mount and on save.

### Phase 4: Spreadsheet Grid View & Bulk Actions
**Goal:** Provide an inline, bulk-editable grid for managing existing listings efficiently.
**Files to Change:**
- `web/src/modules/shop_order/pages/ShopPricingPage.vue`
- `web/src/modules/shop_order/components/ShopPricingGrid.vue` (New)
- `web/src/modules/shop_order/components/ShopPricingBulkActionBar.vue` (New)
**Details:**
- Add a view switcher (List / Grid) to `ShopPricingPage.vue`.
- Build `ShopPricingGrid.vue` for spreadsheet-like inline editing of `sell_price_amount` and `minimum_sell_price_amount`.
- Build `ShopPricingBulkActionBar.vue` that appears when rows are selected, containing a markup input and apply button.
- Wire the apply button to the `useBulkApplyShopMarkupMutation` composable.

### Phase 5: Verification & End-to-End Testing
**Goal:** Ensure all automated flows and UI components function together perfectly.
**Files to Change:**
- None directly, manual or automated tests.
**Details:**
- Verify that parent stock allocation automatically creates child listings if auto-publish is on.
- Verify that parent cost increases auto-update child `minimum_sell_price`.
- Ensure grid view inline edits save correctly.
- Fix any TypeScript (`vue-tsc`) or ESLint errors.

### Phase 6: Dropship Pricing UX Fixes (v2)
**Goal:** Address user feedback regarding unlisted products, manual price/quantity locking, bulk overrides, and default visibility settings.
**Files to Change:**
- `supabase/migrations/xxxx_pricing_ux_fixes.sql` (New)
- `web/src/modules/shop_order/pages/AddShopListingsPage.vue` (New)
- `web/src/modules/shop_order/pages/ShopPricingPage.vue`
- `web/src/modules/shop_order/components/ShopPricingGrid.vue`
- `web/src/modules/shop_order/components/ShopPricingBulkActionBar.vue`
**Details:**
- Add `is_price_locked` and `is_quantity_locked` (booleans) to `shop_product_listings` to prevent global rule overrides on manual edits.
- Add `quantity_override_type` (absolute/relative) to `shop_product_listings` to allow flexible display quantities.
- Add `default_show_quantity` to `shop_pricing_rules` for inherited quantity visibility.
- Update `upsert_shop_product_listing`, `bulk_apply_shop_markup`, and `trg_reactive_adjust_child_listing_cost` to respect the lock fields.
- Create `AddShopListingsPage.vue` (adhering to `PAGE_HEADER.md`) to list candidate allocations with a 1-click "Quick Add" button, replacing the current modal dialog.
- Update `ShopPricingGrid.vue` with lock icons for price/quantity inputs, auto-locking on manual edit, and an absolute/relative toggle for quantity overrides.
- Update `ShopPricingBulkActionBar.vue` to support both percentage and fixed amount markups, targeting either Sell Price or Min Sell Price.
