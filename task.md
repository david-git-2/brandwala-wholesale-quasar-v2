# Execution Task Matrix: Shop Dropship Feature

## Phase 0: Macro — Global Database & Models
- **Goal:** Update schema and RPCs to support dropship charges, prepaid logic, and correct minimum sell price floors.
- **Depends On:** None
- **Files to Change:**
  - `supabase/migrations/20261026000000_shop_order_p16_dropship_charges.sql`
  - `web/src/types/supabase.ts`
- **Specification:**
  - Create migration `20261026000000_shop_order_p16_dropship_charges.sql`.
  - Add charge columns to `shop_carts` and `shop_orders`: `cod_charge_amount`, `delivery_charge_amount`, `print_charge_amount`, `packing_charge_amount`, `discount_amount` (numeric).
  - Add `is_prepaid` (boolean, default false) and `delivery_instructions` (text) to `shop_carts`.
  - Add `is_prepaid_snapshot` (boolean, default false) and `delivery_instructions` (text) to `shop_orders`.
  - Add default charge settings to `shops`: `default_cod_charge_pct`, `default_delivery_charge_amount`, `default_print_charge_amount`, `default_packing_charge_amount` (numeric).
  - Create helper `resolve_billing_profile_for_customer_group(p_tenant_id bigint, p_customer_group_id bigint) returns bigint`.
  - Update `add_to_shop_cart` and `update_shop_cart_item_price` RPCs to enforce `unit_minimum_sell_price_amount` instead of `unit_sell_price_amount` as the floor.
  - Update `submit_shop_order_from_cart` RPC to accept charge params, `is_prepaid`, and `delivery_instructions`, validate the dropship floor on all lines, and auto-resolve `billing_profile_id`.
  - Update `fulfill_shop_order_to_invoice` RPC to pass charges and `delivery_instructions` (as invoice `note`). Implement Pre-paid logic: if `is_prepaid_snapshot` is true, set `collection_source = 'billing_profile'`; else `collection_source = 'recipient'`.
  - Run `npm run backend:types` to regenerate `web/src/types/supabase.ts`.
- **Rollback:** Revert the migration, drop added columns, restore old RPC definitions, and regenerate types.
- **Review Gate:** Code review of the migration file and generated types.
- **Status:** [x] Completed

## Phase 1a: Cart & Checkout — UI & Mock Data
- **Goal:** Update storefront, cart, and checkout UI to support dropship pricing, charges, and pre-paid toggles.
- **Depends On:** Phase 0
- **Files to Change:**
  - `web/src/modules/shop_order/pages/StorefrontPage.vue`
  - `web/src/modules/shop_order/pages/ShopCartPage.vue`
  - `web/src/modules/shop_order/pages/ShopCheckoutPage.vue`
- **Specification:**
  - In `StorefrontPage.vue` (and related browse cards), show sell price and minimum sell price for dropship items, respecting `see_price` permissions.
  - In `ShopCartPage.vue`, fix the minimum price hint and validation to use `unit_minimum_sell_price_amount`. Gate price input based on `can_set_dropship_price` from the permissions store.
  - In `ShopCartPage.vue`, replace hardcoded `£` with the shop's sell currency symbol.
  - In `ShopCheckoutPage.vue`, add a Payment Mode toggle ("Courier collects from customer (COD)" vs "I have already collected payment (Pre-paid)").
  - In `ShopCheckoutPage.vue`, add a "Delivery Instructions / Order Notes" text area.
  - In `ShopCheckoutPage.vue`, add a charges section (delivery, COD, print, packing). Hide/zero the COD charge if Pre-paid is selected.
  - In `ShopCheckoutPage.vue`, build client-side receipt totals: line face subtotal + charges = recipient grand total, alongside accounting cost and estimated profit.
- **Rollback:** Revert UI changes in the Vue files.
- **Review Gate:** Visual review of the cart and checkout pages to ensure new fields and totals render correctly.
- **Status:** [x] Completed

## Phase 1b: Cart & Checkout — API / RPC Layer
- **Goal:** Update cart and order repositories and stores to handle charges, pre-paid status, and dual totals.
- **Depends On:** Phase 1a
- **Files to Change:**
  - `web/src/modules/shop_order/repositories/shopCartRepository.ts`
  - `web/src/modules/shop_order/repositories/shopOrderRepository.ts`
  - `web/src/modules/shop_order/stores/shopCartStore.ts`
  - `web/src/modules/shop_order/stores/shopOrderStore.ts`
- **Specification:**
  - In `shopCartRepository.ts`, add a method `updateShopCartCharges(cartId, charges)` or include charge fields in existing cart update methods.
  - In `shopOrderRepository.ts`, extend the `submitOrder` signature to accept charge amounts, `is_prepaid`, and `delivery_instructions`.
  - In `shopCartStore.ts`, add getters for `faceSubtotal`, `chargeTotal`, `recipientGrandTotal`, and `estimatedProfit`.
  - In `shopOrderStore.ts`, update the `submitOrder` action to pass the new charge and instruction parameters to the repository.
- **Rollback:** Revert changes to repositories and stores.
- **Review Gate:** Code review of the repository and store logic.
- **Status:** [x] Completed

## Phase 1c: Cart & Checkout — Live Wiring
- **Goal:** Wire the checkout submit action to pass charges and handle server-side validation.
- **Depends On:** Phase 1b
- **Files to Change:**
  - `web/src/modules/shop_order/pages/ShopCheckoutPage.vue`
- **Specification:**
  - Update the `submitOrder` function in `ShopCheckoutPage.vue` to pass the calculated charges, `is_prepaid` toggle state, and `delivery_instructions` to `orderStore.submitOrder`.
  - Ensure the client blocks submission if any line's `customer_sell_price` is less than its `unit_minimum_sell_price`.
  - Handle post-submit logic: clear the cart and redirect to the order detail page.
- **Rollback:** Revert the submit wiring in `ShopCheckoutPage.vue`.
- **Review Gate:** End-to-end test of placing a dropship order from cart to order detail.
- **Status:** [x] Completed

## Phase 2a: Order Receipt — UI
- **Goal:** Display the three-party summary and charges on the customer order detail page.
- **Depends On:** Phase 1c
- **Files to Change:**
  - `web/src/modules/shop_order/pages/CustomerOrderDetailPage.vue`
- **Specification:**
  - Update `CustomerOrderDetailPage.vue` to show accounting unit price, recipient unit price, quantity, and line totals for dropship orders.
  - Add a recipient delivery block to the header showing address and `delivery_instructions`.
  - Add a footer receipt section displaying subtotals, COD, delivery, print, packing, discount, recipient pay total, middle-man cost, and estimated profit.
  - Display a badge or text indicating whether the order is Pre-paid or COD.
- **Rollback:** Revert UI changes in `CustomerOrderDetailPage.vue`.
- **Review Gate:** Visual review of a placed dropship order's detail page.
- **Status:** [x] Completed

## Phase 2b: Staff Fulfill — Live Wiring
- **Goal:** Update the staff order detail page to show the three-party context and verify fulfillment linkage.
- **Depends On:** Phase 2a
- **Files to Change:**
  - `web/src/modules/shop_order/pages/StaffOrderDetailPage.vue`
- **Specification:**
  - Update `StaffOrderDetailPage.vue` to display the three-party context (actual seller, middle man, end recipient) before fulfillment.
  - Show a preview of the middle-man payout based on the profit spread.
  - Ensure the fulfillment action correctly calls the updated `fulfill_shop_order_to_invoice` RPC and links to the created dropship invoice.
- **Rollback:** Revert changes in `StaffOrderDetailPage.vue`.
- **Review Gate:** End-to-end test of a staff member fulfilling a dropship order and verifying the resulting global invoice.
- **Status:** [x] Completed

## Phase 3: Permissions & Admin Polish
- **Goal:** Add shop charge defaults UI and billing profile linkage UX for dropship shops.
- **Depends On:** Phase 2b
- **Files to Change:**
  - `web/src/modules/shop_order/pages/CustomerAccessPage.vue`
  - `web/src/modules/shop_order/components/ShopFormDialog.vue`
- **Specification:**
  - In `CustomerAccessPage.vue`, add UX to ensure a customer group is linked to a billing profile before they can place dropship orders.
  - In `ShopFormDialog.vue`, add fields for shop charge defaults (COD %, default delivery, print, packing) visible only for dropship shops.
  - Add bilingual help text in the Scenario F section of the shop form explaining the charge defaults.
- **Rollback:** Revert UI changes in `CustomerAccessPage.vue` and `ShopFormDialog.vue`.
- **Review Gate:** Visual and functional review of the shop admin configuration and customer access pages.
- **Status:** [x] Completed