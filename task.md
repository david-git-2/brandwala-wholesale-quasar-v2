# Execution Task Matrix: Shop Scope UX, Navigation & Page Header DNA

## Phase 1: Dynamic Category Data Layer & Service Integration
- **Goal**: Implement dynamic category fetching from customer-accessible shops in `shopOrderService.ts` and `shopOrderRepository.ts`.
- **Depends On**: None
- **Files to Change**:
  - `web/src/modules/shop_order/repositories/shopOrderRepository.ts`
  - `web/src/modules/shop_order/services/shopOrderService.ts`
- **Specification**:
  1. Add `fetchCustomerShopCategories(tenantId: number)` in `shopOrderRepository.ts`. Query distinct category names and item counts from products belonging to active shops accessible by the user's customer groups in `tenantId`.
  2. Add `listCustomerShopCategories(tenantId: number)` in `shopOrderService.ts` returning `{ success: boolean, data?: { name: string, icon: string, bgColor: string, color: string, count: number }[], error?: string }`.
  3. Include explicit category icon and color resolver (case-insensitive substring match):
     - `t-shirt`, `apparel`, `shirt` -> `icon: 'checkroom'`, `color: 'blue-7'`, `bgColor: 'blue-1'`
     - `hoodie`, `jacket`, `outerwear` -> `icon: 'sports_outdoor'`, `color: 'deep-orange-7'`, `bgColor: 'deep-orange-1'`
     - `activewear`, `sport` -> `icon: 'directions_run'`, `color: 'green-7'`, `bgColor: 'green-1'`
     - `accessory`, `watch`, `jewel` -> `icon: 'watch'`, `color: 'purple-7'`, `bgColor: 'purple-1'`
     - `footwear`, `shoe` -> `icon: 'roller_skating'`, `color: 'indigo-7'`, `bgColor: 'indigo-1'`
     - `pant`, `trouser`, `bottom` -> `icon: 'layers'`, `color: 'teal-7'`, `bgColor: 'teal-1'`
     - Default fallback -> `icon: 'category'`, `color: 'grey-7'`, `bgColor: 'grey-2'`
- **Rollback**: Revert changes in `shopOrderRepository.ts` and `shopOrderService.ts`.
- **Review Gate**: Verify `listCustomerShopCategories` returns clean array of dynamic category objects with icons.
- **Status**: [Pending]

## Phase 2: Customer Dashboard (`CustomerDashboard.vue`) & Nav Drawer Refactoring
- **Goal**: Refactor `CustomerDashboard.vue` layout to `q-page.q-pa-md` + `div.q-gutter-y-md`, wire dynamic categories query, inter-page search, and update navigation drawer.
- **Depends On**: Phase 1
- **Files to Change**:
  - `web/src/modules/dashboard/pages/CustomerDashboard.vue`
  - `web/src/modules/navigation/useWorkspaceNavigation.ts`
- **Specification**:
  1. Replace static categories array in `CustomerDashboard.vue` with `useQuery(['customer-shop-categories-dashboard', authStore.tenantId], ...)`.
  2. Connect category card click to `router.push({ path: `${tenantBase}/browse/${activeShopSlug}`, query: { category: categoryName } })`.
  3. Connect search bar trigger to `router.push({ path: `${tenantBase}/browse/${activeShopSlug}`, query: { q: searchQuery } })`.
  4. Ensure `CustomerDashboard.vue` template uses `<q-page class="q-pa-md theme-shop"><div class="q-gutter-y-md">...</div></q-page>`.
  5. Apply avatar initials generator (`getAvatarColor`, `getInitials`) size `36px` on recent orders list.
  6. Verify `useShopWorkspaceLinks` in `useWorkspaceNavigation.ts` renders structured links for Dashboard, Wholesale Shops, My Orders, Cart & Checkout.
- **Rollback**: Revert `CustomerDashboard.vue` and `useWorkspaceNavigation.ts`.
- **Review Gate**: Dashboard renders dynamic categories from DB; clicking a category or searching navigates to storefront with query params attached.
- **Status**: [Pending]

## Phase 3: Wholesale Shops Picker (`ShopPickerPage.vue`) & Storefront (`StorefrontPage.vue`)
- **Goal**: Align Shop Picker & Storefront pages with locked LIST header DNA (`PAGE_HEADER.md`) and query param filtering.
- **Depends On**: Phase 2
- **Files to Change**:
  - `web/src/modules/shop_order/pages/ShopPickerPage.vue`
  - `web/src/modules/shop_order/pages/StorefrontPage.vue`
- **Specification**:
  1. In `ShopPickerPage.vue`: Wrap in `q-page class="q-pa-md"` and `div class="q-gutter-y-md"`. Add header with overline `Shop Scope`, `h1.text-h5` "Select Wholesale Shop", and `pill-btn` CTA. Toolbar card `q-card flat bordered q-pa-sm` with `.soft-input` search box and shop type filter.
  2. In `StorefrontPage.vue`: Add header with back button, overline `Wholesale Storefront`, title `h1.text-h5` "{{ shopName }}", and floating cart icon in right CTA slot. Read `route.query.category` and `route.query.q` on load and apply to active filters. Add toolbar card `q-card flat bordered q-pa-sm` with `.soft-input` search bar and `FilterSidebar` trigger with badge.
- **Rollback**: Revert `ShopPickerPage.vue` and `StorefrontPage.vue`.
- **Review Gate**: Navigating to `StorefrontPage.vue?category=T-Shirts` automatically applies the `T-Shirts` category filter on load.
- **Status**: [Pending]

## Phase 4: Cart (`ShopCartPage.vue`) & Checkout (`ShopCheckoutPage.vue`) Refactoring
- **Goal**: Refactor Cart and Checkout views to conform to standard page stack, header DNA, and CTA guidelines.
- **Depends On**: Phase 3
- **Files to Change**:
  - `web/src/modules/shop_order/pages/ShopCartPage.vue`
  - `web/src/modules/shop_order/pages/ShopCheckoutPage.vue`
- **Specification**:
  1. In `ShopCartPage.vue`: Wrap in `q-page class="q-pa-md"` and `div class="q-gutter-y-md"`. Header: Overline `Shop Cart`, title `h1.text-h5` "Your Cart ({{ count }} items)", back button to Storefront. Primary CTA in summary card: `q-btn color="primary" unelevated no-caps class="pill-btn full-width" label="Proceed to Checkout"`.
  2. In `ShopCheckoutPage.vue`: Wrap in `q-page class="q-pa-md"` and `div class="q-gutter-y-md"`. Header: Overline `Checkout`, title `h1.text-h5` "Complete Wholesale Order", back button to Cart. Header Primary CTA: `q-btn color="primary" unelevated no-caps label="Submit Order"` (square button, NO `pill-btn`).
- **Rollback**: Revert `ShopCartPage.vue` and `ShopCheckoutPage.vue`.
- **Review Gate**: Cart uses `pill-btn`; Checkout uses square unelevated primary submit button per `PAGE_HEADER.md`.
- **Status**: [Pending]

## Phase 5: Orders List (`CustomerOrdersPage.vue`) & Order Detail (`CustomerOrderDetailPage.vue`) Status Workflow Strip
- **Goal**: Update Orders List to list DNA and migrate Customer Order Detail to locked horizontal Status Workflow Strip.
- **Depends On**: Phase 4
- **Files to Change**:
  - `web/src/modules/shop_order/pages/CustomerOrdersPage.vue`
  - `web/src/modules/shop_order/pages/CustomerOrderDetailPage.vue`
- **Specification**:
  1. In `CustomerOrdersPage.vue`: Wrap in `q-page class="q-pa-md"` and `div class="q-gutter-y-md"`. Header: Overline `Orders`, title `h1.text-h5` "My Orders", List CTA `pill-btn` "Browse Wholesale Shops". Toolbar Card `q-card flat bordered q-pa-sm` with search input and status filter dropdown.
  2. In `CustomerOrderDetailPage.vue`: Header with back button, overline `Customer Order`, title `h1.text-h5` "Order #{{ order_no }}", subtitle `text-body2 text-grey-7` "Placed on {{ date }} • {{ shop_name }}", primary CTA "Download Invoice". Insert `<q-card flat bordered class="q-pa-sm">` under header containing horizontal status workflow strip (`pending` -> `negotiating` -> `approved` -> `shipped` -> `delivered`) separated by `chevron_right` icons with `check_circle` on active status and `Cancelled` state placed aside after vertical separator.
- **Rollback**: Revert `CustomerOrdersPage.vue` and `CustomerOrderDetailPage.vue`.
- **Review Gate**: CustomerOrderDetailPage displays the locked horizontal status workflow strip with `check_circle` icon on current status and `chevron_right` separators.
- **Status**: [Pending]