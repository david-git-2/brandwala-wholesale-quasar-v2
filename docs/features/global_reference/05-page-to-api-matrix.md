# Global Reference, Koba Vertical & Central Trash — Page to API Matrix

## 1. Global Reference Interfaces

### 1.1 Platform Superadmin Management (`/platform/reference/*`)
| Route / URL | Component Path | Triggers & User Actions | Backend Endpoint / RPC | TanStack Query Key | Invalidation Targets |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `/platform/reference` | `ReferenceHubPage.vue` | Page mount | N/A (Static catalog cards) | N/A | N/A |
| `/platform/reference/currencies` | `CurrenciesPage.vue` | Mount, rate refresh | `Table: global_currencies` | `['global-reference', 'currencies']` | N/A |
| `/platform/reference/currencies` | `CurrenciesPage.vue` | Upsert / edit rate | `RPC: upsert_global_currency` | Mutation | `['global-reference', 'currencies']` |
| `/platform/reference/markets` | `MarketsPage.vue` | Mount, search | `Table: markets` | `['global-reference', 'markets']` | N/A |
| `/platform/reference/payment-methods` | `PaymentMethodsPage.vue` | Mount, toggle scope | `Table: payment_methods` | `['global-reference', 'payment-methods']` | N/A |
| `/platform/reference/units` | `UnitsOfMeasurePage.vue` | Mount, unit edit | `Table: units_of_measure` | `['global-reference', 'units-of-measure']` | N/A |

### 1.2 Tenant App Read-Only Surfaces (`/:tenantSlug/app/reference/*`)
| Route / URL | Component Path | Triggers & User Actions | Backend Endpoint / RPC | TanStack Query Key | Invalidation Targets |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `/:slug/app/reference/currencies` | `AppCurrenciesPage.vue` | Mount | `Table: global_currencies` | `['global-reference', 'currencies']` | N/A (Read-only) |
| `/:slug/app/reference/markets` | `AppMarketsPage.vue` | Mount | `Table: markets` | `['global-reference', 'markets']` | N/A (Read-only) |
| `/:slug/app/reference/payment-methods` | `AppPaymentMethodsPage.vue`| Mount | `Table: payment_methods` | `['global-reference', 'payment-methods']` | N/A (Read-only) |
| `/:slug/app/reference/units` | `AppUnitsPage.vue` | Mount | `Table: units_of_measure` | `['global-reference', 'units-of-measure']` | N/A (Read-only) |

---

## 2. Koba Sourcing & Commerce Interfaces

### 2.1 Admin & Staff App Surfaces (`/:tenantSlug/app/koba/retail/*`)
| Route / URL | Component Path | Triggers & User Actions | Backend Endpoint / RPC | TanStack / Pinia Key | Invalidation Targets |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `/:slug/app/koba/retail` | `KobaRetailProductsPage.vue` | Mount, brand filter | `Table: koba_products` | `['koba', 'products', filters]` | N/A |
| `/:slug/app/koba/retail/cart` | `KobaCartPage.vue` | Mount, sync items | `RPC: get_koba_cart` | `['koba', 'cart', tenantId]` | `['koba', 'cart']` |
| `/:slug/app/koba/retail/cart` | `KobaCartPage.vue` | Type customer phone | `RPC: get_koba_customer_profile` | `['koba', 'profile', phone]` | N/A |
| `/:slug/app/koba/retail/cart` | `KobaCartPage.vue` | Submit order | `RPC: create_koba_order` | Mutation | `['koba', 'cart']`, `['koba', 'orders']` |
| `/:slug/app/koba/retail/orders` | `KobaOrdersPage.vue` | Mount, status filter | `Table: koba_orders` | `['koba', 'orders', filters]` | N/A |
| `/:slug/app/koba/retail/orders/:id` | `KobaOrderDetailPage.vue` | Update delivery state | `Table: koba_orders` | `['koba', 'orders', id]` | `['koba', 'orders', id]` |
| `/:slug/app/koba/retail/settings` | `KobaRetailSettingsPage.vue`| Save commission % | `Table: koba_retail_settings` | `['koba', 'settings']` | `['koba', 'settings']` |

### 2.2 Storefront Customer Surfaces (`/:tenantSlug/shop/koba/retail/*`)
| Route / URL | Component Path | Triggers & User Actions | Backend Endpoint / RPC | TanStack / Pinia Key | Invalidation Targets |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `/:slug/shop/koba/retail` | `KobaRetailProductsPage.vue` | Catalog browsing | `Table: koba_products` | `['shop', 'koba', 'products']` | N/A |
| `/:slug/shop/koba/retail/cart` | `KobaCartPage.vue` | Add to cart / checkout | `RPC: create_koba_order` | Mutation | `['shop', 'koba', 'cart']` |
| `/:slug/shop/koba/retail/orders` | `KobaOrdersPage.vue` | Track order by phone | `Table: koba_orders` | `['shop', 'koba', 'orders']` | N/A |

---

## 3. Central Trash & Recovery Interface

| Route / URL | Component Path | Triggers & User Actions | Backend Endpoint / RPC | TanStack Query Key | Invalidation Targets |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `/:slug/app/trash` | `TrashPage.vue` | Mount, type filter, search | `RPC: list_trash_entries` | `['trash', 'list', filters]` | N/A |
| `/:slug/app/trash` | `TrashPage.vue` | Click "Restore" | `RPC: restore_from_trash` | Mutation | `['trash', 'list']`, target domain list |
| `/:slug/app/trash` | `TrashPage.vue` | Click "Permanently Delete" | `RPC: purge_trash_entry` | Mutation (Optimistic) | `['trash', 'list']` |
