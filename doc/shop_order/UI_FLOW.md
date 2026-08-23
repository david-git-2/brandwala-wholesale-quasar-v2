# Shop Order — UI Flow & Interaction Specification

This document defines user interaction flows, route navigation, button visibility rules, and validation matrices for the **Shop Order** module.

For RPC/API contracts and query keys, see [`SHOP_ORDER.md`](./SHOP_ORDER.md). Customer group creation is in [`CUSTOMER.md`](../customer/CUSTOMER.md).

---

## 1. Shop Setup Operator Journey (`shop_config`)

Recommended order for staff configuring a new storefront:

```mermaid
flowchart TD
    H["Shop Setup Hub<br/>/app/shop/shops"] --> G["Customer Groups<br/>/app/customers"]
    H --> C["Shop Categories<br/>/app/shop/categories"]
    H --> L["Shops List<br/>/app/shop/shops/list"]
    L --> D["Create Shop Dialog<br/>name + pick 1 of 3 types"]
    D --> S["Shop Settings<br/>/app/shop/shops/:id/setup"]
    S --> A["Access tab<br/>grant customer groups"]
    S --> P["Listings tab<br/>fixed_price / dropship only"]
    G -.->|"groups must exist first"| A
    C -.->|"tag shops on setup form"| S
```

| Step | Route | Grant key | Primary action |
| :--- | :--- | :--- | :--- |
| Hub | `/:tenantSlug/app/shop/shops` | `shop_config` | Navigate to Shops, Categories, or Customer Groups |
| Categories | `/:tenantSlug/app/shop/categories` | `shop_category` | CRUD `shop_categories` |
| Shops list | `/:tenantSlug/app/shop/shops/list` | `shop_config` | Search, filter, create shop |
| Shop settings | `/:tenantSlug/app/shop/shops/:shopId/setup` | `shop_config` | Save setup, access, listings (tabbed) |
| Staff preview | `/:tenantSlug/app/shop/shops/:shopId/preview` | `shop_config` | Open storefront as staff |

---

## 2. Shop Settings — Tabs & Actions

[`ShopSettingsPage.vue`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/pages/ShopSettingsPage.vue) uses `?tab=` query sync.

| Tab | Visible when | Header actions | Embedded page |
| :--- | :--- | :--- | :--- |
| **Setup** | Always | **Save** (calls `ShopSettingsForm.buildPayload` → `upsert_shop`) | `ShopSettingsForm` + danger zone |
| **Access** | `shop_permissions` grant | None (actions inside matrix) | `ShopAccessMatrixPage` (`embedded`) |
| **Listings** | `shop_pricing` grant **and** shop type ≠ `vendor_catalog` | None (actions inside pricing page) | `ShopPricingPage` (`embedded`) |

### Danger zone (Setup tab only)

Delete is **not** on the page header or shops list menu for settings — it lives at the bottom of the Setup tab.

| Field | Rule |
| :--- | :--- |
| Keyword | Must type exactly `DELETE` |
| Shop name | Must match shop name exactly (trimmed) |
| Delete button | Disabled until both match; no confirmation dialog |
| On success | Toast + redirect to shops list |

> **Note:** [`ShopsPage.vue`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/pages/ShopsPage.vue) row menu still uses a simple confirm dialog for quick delete from the list.

---

## 3. Publish & Save Rules (`ShopSettingsForm`)

Shop type is **immutable** after create. Draft shops (`is_active = false`) can save with only name + slug. Turning **Public** on enforces full publish blockers.

| Shop type | Listings tab | Publish blockers (when `is_active = true`) |
| :--- | :--- | :--- |
| **`vendor_catalog`** | Hidden | Name, slug, buy/sell currency, **at least one vendor** |
| **`fixed_price`** | Shown (if `shop_pricing`) | Name, slug, buy/sell currency; if pricing method = markup → markup ≥ 0 |
| **`dropship`** | Shown (if `shop_pricing`) | Name, slug, buy/sell currency; readiness card shown on Setup tab |

| Control | Rule |
| :--- | :--- |
| **Public toggle** | Disabled when publish blockers exist **and** shop is currently draft |
| **Save** | Validates name + slug always; full publish validation only when `is_active = true` |
| **Vendor pickers** | Catalog only; multi-vendor via `vendor_filters[]`; brands load on focus |
| **Categories** | Multi-select from active `shop_categories` (+ already-selected inactive) |

---

## 4. Create Shop Dialog

[`ShopFormDialog.vue`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/components/ShopFormDialog.vue)

```mermaid
flowchart LR
    A["Enter shop name"] --> B["Pick type card"]
    B --> C["Create & Continue"]
    C --> D["upsert_shop"]
    D --> E["Navigate to /shops/:id/setup"]
```

| Type card | Enum | Post-create defaults |
| :--- | :--- | :--- |
| Catalog | `vendor_catalog` | `order_mode = procurement_intent`, negotiable |
| In stock | `fixed_price` | Stock-backed listings flow |
| Dropship | `dropship` | `order_mode = checkout_fixed`, courier checkout |

**Validation:** name required, type required, global currencies must load (sets buy/sell currency from tenant defaults).

---

## 5. Customer Access Matrix

[`ShopAccessMatrixPage.vue`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/pages/ShopAccessMatrixPage.vue) — standalone route or embedded in Setup tab.

| Action | Trigger | Result |
| :--- | :--- | :--- |
| **Add group** | Pick existing group from tenant | Opens edit drawer → `upsert_shop_customer_group_access` |
| **Create group** | Inline dialog | `create_customer_account` → auto-grant on this shop |
| **Edit row** | Click granted group | Toggle capabilities + credit limit |
| **Copy login URL** | Top-right button | Copies `/:tenantSlug/shop` login link |

### Capability toggles (per group × shop)

Price visibility uses two **field groups** (see [`SHOP_ORDER.md`](./SHOP_ORDER.md) §1). Access-matrix toggles map to each group:

| Toggle | Default | Field group | Effect on storefront |
| :--- | :--- | :--- | :--- |
| Can see purchase price | `true` | **Unit** | `unit_price_*` on browse/detail/search (`vendor_catalog`, `dropship`) |
| Can see sell price | `true` | **Sell** | Line sell amounts + cart/checkout/order totals; `unit_price_*` on `fixed_price` browse |
| Can see resell minimum price | `true` | **Sell** (resell minimum) | `minimum_sell_price_*` on browse/detail, `unit_minimum_sell_price_*` in cart (`dropship`). *(Planned `can_see_resell_minimum_price`; today still tied to sell price in code.)* |

| Toggle | Default | Effect on storefront |
| :--- | :--- | :--- |
| Browse catalog | `true` | Can open `StorefrontPage` |
| View quantity | `true` | Stock/qty visible when shop allows |
| Add to cart | `true` | Add-to-cart actions enabled |
| Place order | `true` | Checkout submit allowed |
| Negotiate | `false` | Counter-offer UI (catalog shops) |
| Set dropship price | `false` | Customer can set sell price above floor (dropship) |

**Add group** button disabled when every tenant group is already granted.

---

## 6. Customer Storefront Journey (`shop` scope)

```mermaid
flowchart TD
    D["Customer Dashboard<br/>/shop/dashboard"] --> B["Browse shop<br/>/shop/browse/:shopSlug"]
    B --> P["Product detail<br/>/shop/browse/:shopSlug/product/:productId"]
    P --> B
    B --> C["Cart<br/>/shop/cart"]
    C -->|"vendor_catalog / fixed_price"| O["Orders<br/>/shop/orders"]
    C -->|dropship| K["Checkout<br/>/shop/checkout"]
    K --> O
    O --> W["Merchant wallet<br/>/shop/orders/wallet"]
```

| Screen | Grant key | Key rules |
| :--- | :--- | :--- |
| **Catalog entry** | `shop_storefront` | Redirect hub before slug browse |
| **Storefront** | `shop_storefront` | Permissions from `get_shop_permissions_for_customer`; unit + sell price groups (§5) |
| **Product detail** | `shop_storefront` | `get_shop_catalog_product_for_customer`; same permission gates as catalog; shareable URL |
| **Cart** | `shop_cart` | Per-shop cart via `get_or_create_shop_cart`; **`vendor_catalog`** and **`fixed_price`** submit from cart (Place Order) |
| **Checkout** | `shop_cart` | **`dropship`** only — see §7 |
| **Orders** | `shop_order_mgmt` | Customer order list + detail |
| **Wallet** | `shop_order_mgmt` | Dropship merchant ledger |

---

## 7. Checkout — Validation & Submit

[`ShopCheckoutPage.vue`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/pages/ShopCheckoutPage.vue) — **dropship shops only**. `vendor_catalog` and `fixed_price` place orders from [`ShopCartPage.vue`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/pages/ShopCartPage.vue) with empty delivery fields (banner: no delivery form on cart).

### Cart — direct place order (`vendor_catalog`, `fixed_price`)

[`ShopCartPage.vue`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/pages/ShopCartPage.vue)

| Shop type | CTA | On submit |
| :--- | :--- | :--- |
| **`vendor_catalog`** | Place Order | `submit_shop_order_from_cart` → status `submitted` → `/shop/orders` |
| **`fixed_price`** | Place Order | `submit_shop_order_from_cart` → status `draft` → `/shop/orders` |
| **`dropship`** | Proceed to Checkout | Navigate to checkout (§7 below) |

Place order disabled when cart empty, unsaved qty/price edits, save in progress, or (dropship cart only) sell price below floor.

### Checkout — dropship

| Shop type | Delivery form | Place order disabled when |
| :--- | :--- | :--- |
| **`dropship`** | **Required** (auto-enabled) | Name, phone (`01[3-9]########`), or address missing; or sell price below floor |

**On submit (`submit_shop_order_from_cart`):**

1. Validate delivery form when `requestDelivery = true`
2. Dropship: each line `customer_sell_price_amount` ≥ `unit_minimum_sell_price_amount`
3. Success → invalidate cart + orders queries → navigate to order confirmation / orders list

**Phone blur:** looks up saved recipient profile by phone and prefills name, address, district/thana/postcode.

---

## 8. Staff Orders Desk (`shop_order_mgmt`)

[`ShopOrdersPage.vue`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/pages/ShopOrdersPage.vue)

Loads `list_shop_orders_for_staff` on mount (no `total_amount`, no `global_currencies`). Compact toolbar: search, **shop** (`p_shop_id`), shop type, and status filters. Shop list loads via `list_shops` for the shop dropdown.

| Filter | Source | Effect |
| :--- | :--- | :--- |
| Shop | `q-select` → `p_shop_id` on RPC | Server-side shop filter |
| Shop type | `q-select` or `?shopType=` query | Client-side via loaded shops' `shop_type` |
| Status | `q-select` → `p_status` on RPC | Server-side status filter |
| Search | debounced input → `p_search` on RPC | Server-side text search |

Row click → `StaffOrderDetailPage` (B2B) or `DropshipOrderDetailPage` (dropship URL under `/app/shop/dropship/:id`).

---

## 9. Dropship Order Status Workflow

[`DropshipOrderStatusWorkflow.vue`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/components/DropshipOrderStatusWorkflow.vue) — clickable status chips on order detail.

**Happy path (left → right):**

`confirmed` → `processing` → `ready_for_pickup` → `shipped` → `delivered` → `payment_received`

**Side branch:** `returned` (separate chip, not on happy-path strip)

| UI behavior | Rule |
| :--- | :--- |
| Current status | Filled chip with type color |
| Passed statuses | Grey filled (progress shading) |
| Future statuses | Grey outline |
| Click chip | Emits `update-status` → parent calls `advance_dropship_order_status` |

Off-strip statuses (e.g. `submitted`, `cancelled`) show as a badge above the strip.

---

## 10. Dropship Finance Hub

[`DropshipFinanceHubPage.vue`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/pages/DropshipFinanceHubPage.vue) — grant: `shop_shipping`

```mermaid
flowchart LR
    S1["1. Delivered Costing"] --> S2["2. Courier Remittance"]
    S2 --> S3["3. Merchant Payout"]
```

| Step | Component | RPC |
| :--- | :--- | :--- |
| 1. Delivered costing | `FinanceHubStepDelivered` | Review delivered orders awaiting costing |
| 2. Courier remittance | `FinanceHubStepRemittance` | `record_dropship_courier_remittance` |
| 3. Merchant payout | `FinanceHubStepPayout` | `dispense_middleman_payout_from_tenant` |

**Deep links:** `?step=courier_remittance|middleman_payout|delivered_costing`, `?orderId=`, `?merchantId=` (opens payout step with merchant preselected).

Legacy courier-remittance URLs redirect to this hub with `step=courier_remittance`.

---

## 11. Screen & Dialog Catalog

### 11.1 Shop Setup Hub (`/app/shop/shops`)
- **Page:** `ShopSetupHubPage.vue`
- **Cards:** Shops list, Categories, Customer Groups (external module)
- **No data mutations** — navigation only

### 11.2 Shops List (`/app/shop/shops/list`)
- **Page:** `ShopsPage.vue`
- **Toolbar:** Search (debounced), filter pills (All / Public / Draft), **New shop**
- **Row click:** → shop settings
- **Row menu:** Setup, Delete (simple `$q.dialog` confirm)

### 11.3 Shop Settings (`/app/shop/shops/:shopId/setup`)
- **Page:** `ShopSettingsPage.vue`
- **Tabs:** Setup · Access · Listings (see §2)
- **Dropship only:** `DropshipShopReadinessCard` above form on Setup tab

### 11.4 Shop Categories (`/app/shop/categories`)
- **Page:** `ShopCategoriesPage.vue`
- **Actions:** Create, edit name/slug/icon, toggle active, delete

### 11.5 Shop Pricing (`/app/shop/pricing` and `/app/shop/shops/:shopId/pricing`)
- **Pages:** `ShopPricingListPage.vue`, `ShopPricingPage.vue`, `AddShopListingsPage.vue`
- **Actions:** List stock-backed listings, upsert price/qty overrides, bulk markup

### 11.6 Storefront (`/shop/browse/:shopSlug`)
- **Page:** `StorefrontPage.vue`
- **Components:** `StorefrontHeader`, `StorefrontProductCard`, `StorefrontFilterDrawer`
- **Product card click / quick view** → product detail route (see §12)
- **Cart FAB / header link** → `/shop/cart`

### 11.7 Product detail (`/shop/browse/:shopSlug/product/:productId`)
- **Page:** `StorefrontProductDetailPage.vue` (planned)
- **Components:** `ProductDetailGallery`, `ProductDetailSummary`, `ProductDetailSpecs`, `ProductDetailPricing`, `ProductDetailActionBar`, `ProductDetailRelated`
- **RPCs:** `get_shop_catalog_product_for_customer` (§8), `list_related_shop_catalog_products_for_customer` (§9) — see [`SHOP_ORDER.md`](./SHOP_ORDER.md)
- **Entry points:** product card click, quick-view “View details”, direct URL, copy-link share

### 11.8 Dropship Order Detail (`/app/shop/dropship/:id`)
- **Page:** `DropshipOrderDetailPage.vue`
- **Cards:** `DropshipRecipientFormCard`, `DropshipCourierCard`, status workflow
- **Actions:** Advance status, issue dual invoice, print packing slip / recipient invoice preview

---

## 12. Product Detail Page (`shop` scope)

**Route:** `/:tenantSlug?/shop/browse/:shopSlug/product/:productId`  
**Layout:** `ShopLayout` (header search, cart, profile)

### Page structure

```text
StorefrontProductDetailPage
├── Breadcrumbs: Shop › {category} › {product_name}
├── ProductDetailHero (desktop: 2-col | mobile: stack)
│   ├── ProductDetailGallery        — main image (SmartImage), placeholder if missing
│   └── ProductDetailSummary
│       ├── brand (caption)
│       ├── name (h1)
│       ├── copy-link button
│       ├── ProductDetailSpecs        — dl rows (see field table below)
│       ├── ProductDetailPricing      — unit price group + sell group (resell minimum on dropship)
│       └── ProductDetailStock        — available badge (can_view_quantity)
├── ProductDetailRelated              — same-category cards (`vendor_catalog` only; RPC §9)
└── ProductDetailActionBar (sticky)   — qty stepper + Add to cart / Update cart
```

### Field visibility

| Field / block | Source | Show when |
| :--- | :--- | :--- |
| Image | `product_image_url` | Always (placeholder if null) |
| Name | `product_name` | Always |
| Brand | `product_brand` | When non-null |
| Category | `product_category` | When non-null |
| Country of origin | `country_of_origin` | When non-null |
| Expire date | `expire_date` | When non-null |
| MOQ | `minimum_order_quantity` | Always; banner when > 1 |
| Product code | `product_code` | When non-null |
| Barcode | `product_barcode` | When non-null |
| Stock | `available_units` | `can_view_quantity` and value not null |
| Qty stepper + cart CTA | — | `can_add_to_cart`; disabled when `available_units = 0` |
| Copy link | current URL | Always |
| Related products | `list_related_shop_catalog_products_for_customer` | `vendor_catalog` + non-empty category + RPC returns rows |

#### Unit price group

| Field | Show when |
| :--- | :--- |
| `unit_price_amount` | `can_see_buy_price` (`vendor_catalog`, `dropship`); `can_see_sell_price` (`fixed_price`) |
| `unit_price_currency_symbol` | With unit price (same permission) |

#### Sell price group

| Field | Show when |
| :--- | :--- |
| `sell_price_amount` (+ currency fields) | `can_see_sell_price` **and** `shop.shop_type = dropship` |
| `resell_minimum_price_amount` (+ currency fields) | `can_see_resell_minimum_price` *(planned)* **and** `shop.shop_type = dropship` |

### Interactions

| Action | Trigger | Result |
| :--- | :--- | :--- |
| **Open detail** | Product card click or quick-view link | Navigate to `/shop/browse/:shopSlug/product/:productId` |
| **Copy link** | Link icon in summary | Copy `window.location.href` → toast “Link copied” |
| **Back to catalog** | Breadcrumb or browser back | Return to `StorefrontPage` (preserve `?search=` / filter query when possible) |
| **Add to cart** | Sticky action bar | `add_to_shop_cart` with selected qty; toast; optional badge update |
| **Update cart** | When line already in cart | `update_shop_cart_item_qty` |
| **Related card click** | Related product card | Navigate to `/shop/browse/:shopSlug/product/:productId` |
| **View all in category** | Link in related header | `StorefrontPage` with `?category={product_category}` |

### Shop-type notes (price groups)

| Shop type | Unit price group | Sell price group | Stock |
| :--- | :--- | :--- | :--- |
| `vendor_catalog` | List / purchase price (`can_see_buy_price`) | None on browse; totals in cart/checkout if `can_see_sell_price` | Usually hidden (`available_units` null) |
| `fixed_price` | Listing price via **sell** permission (`can_see_sell_price`) | No resell minimum on browse | ATP when listing + permissions allow |
| `dropship` | Landed cost + buy currency (`can_see_buy_price`) | `sell_price_*` + `resell_minimum_price_*` on browse/detail | Same as `fixed_price` |

### Error states

| State | UI |
| :--- | :--- |
| Loading | Page skeleton (image + spec rows) |
| Product not found / no browse access | `q-banner` + link back to catalog |
| `can_see_buy_price` off | Hide **unit price group**; specs and add-to-cart still shown if allowed |
| `can_see_resell_minimum_price` off (dropship) | Hide **sell group — resell minimum** on browse/detail/cart |
| `can_see_sell_price` off | Hide **sell group** (line sell amounts + totals) on cart/checkout/orders |
| Out of stock | Stock badge red; Add to cart disabled |
