# Shop & Order — Phase Progress & Deliverables

**Agent index:** [.cursor/plans/shop_order_phased_build_0010b204.plan.md](../.cursor/plans/shop_order_phased_build_0010b204.plan.md)  
**Canon:** [SHOP_ORDER.md](SHOP_ORDER.md)

Update this file when a phase completes. Agent: set status to `done` and stop.

**Next phase:** None (all phases completed)

---

## Summary

| Phase | Status | Migration file | Submodule |
|-------|--------|----------------|-----------|
| P0 | done | `20260901_shop_order_p0_products_currency.sql` | — |
| P1 | done | `20260902000000_shop_order_p1_scaffold.sql` | `shop_order` |
| P2 | done | `20260902000100_shop_order_p2_rpcs.sql` | `shop_config` |
| P3 | done | `20260902000200_shop_order_p3_permissions.sql` | `shop_permissions` |
| P4 | done | `20260902000300_shop_order_p4_listings.sql` | `shop_pricing` |
| P5 | done | `20260902000400_shop_order_p5_browse.sql` | `shop_storefront` |
| P6 | done | `20260902000500_shop_order_p6_cart.sql` | `shop_cart` |
| P7 | done | `20260902000600_shop_order_p7_orders.sql` | `shop_order_mgmt` |
| P8 | done | `20260902000700_shop_order_p8_fulfillment.sql` | `shop_fulfillment` |
| P9 | done | — (web only) | — |

---

## P0–P2 (done)

| Phase | Delivered |
|-------|-----------|
| P0 | Products multi-currency; `list_price_amount` + currency FK; dropped `price_gbp` |
| P1 | `shops` table, enums, RLS, `shop_order` + 7 submodules in `public.modules`; route scaffold |
| P2 | `list_shops`, `upsert_shop` RPCs; `ShopsListPage`, `ShopFormDialog`; guard `shop_config` |

---

## P3 — Permissions (`shop_permissions`)

**Read:** SHOP_ORDER §5, §7.2–7.3, §12 | **Permissions canon:** [PERMISSION_SYSTEM.md](PERMISSION_SYSTEM.md) §8 (resource grants; full `tenant_roles` at B8)

### Migration

**Tables:** `customer_group_shop_profiles`, `shop_customer_group_access` — columns per SHOP_ORDER §5.1–5.2

**RPCs:**

- `get_shop_permissions_for_customer(p_shop_id)` → json flags
- `can_customer_access_shop(p_shop_id)`
- `can_customer_see_shop_price(p_shop_id)`
- `can_customer_negotiate_on_shop(p_shop_id)`
- `upsert_customer_group_shop_profile(...)`
- `upsert_shop_customer_group_access(...)`

Effective resolution: §5.3 formula in SQL.

### Web

| Route | Page |
|-------|------|
| `/app/shop/customer-groups/:groupId/permissions` | `CustomerGroupShopProfilePage.vue` |
| `/app/shop/shops/:shopId/access` | `ShopAccessMatrixPage.vue` |

Guard: `shop_permissions`

### Exit

- [ ] Profile defaults save per customer group
- [ ] Per-shop override `null` = inherit from profile
- [ ] `get_shop_permissions_for_customer` returns expected flags

---

## P4 — Listings & pricing (`shop_pricing`)

**Read:** SHOP_ORDER §4, §7.4, §12

### Migration

**Table:** `shop_product_listings` per §7.4. UNIQUE `(shop_id, global_stock_allocation_id)`

**RPCs:**

- `list_shop_product_listings(p_shop_id)`
- `upsert_shop_product_listing(...)` — sell + min_sell money pairs
- `list_allocations_for_shop_pick(p_tenant_id, p_shop_id)` — child allocations only

### Web

| Route | Page / component |
|-------|------------------|
| `/app/shop/shops/:shopId/pricing` | `ShopPricingPage.vue` |
| — | `AllocationPickDialog.vue` — borrow from `NetworkStockSearchPanel` |

### Exit

- [ ] List allocation with sell price on fixed_price shop
- [ ] `display_quantity_override` saves
- [ ] Only `global_stock_allocations` for shop's tenant

---

## P5 — Storefront (`shop_storefront`)

**Read:** SHOP_ORDER §5.4, §12 | **Scope:** shop (customer_group_members guard)

### Migration

**RPC:** `browse_shop_catalog(p_shop_slug)` — null price/qty when permission denies

- `vendor_catalog`: products by `shops.vendor_code`
- `fixed_price` / `dropship`: active listings

### Web

| Route | Page |
|-------|------|
| `/:tenantSlug?/shop/browse/:shopSlug` | `ShopBrowsePage.vue` |

Borrow cards: `commerce_shop/components/CommerceStoreProductsBrowser.vue`

### Exit

- [x] `see_price=false` hides unit price
- [x] `can_browse=false` cannot open shop
- [x] Shop scope guard on routes

---

## P6 — Cart (`shop_cart`)

**Read:** SHOP_ORDER §7.5–7.6, §8.3, §12

### Migration

**Tables:** `shop_carts`, `shop_cart_items`, `shop_stock_reservations` per §7.5–7.6

**Enum:** `shop_cart_status` (if not created in P1)

**RPCs:** `get_or_create_shop_cart`, `add_to_shop_cart`, `update_shop_cart_item_qty`, `remove_shop_cart_item`

Reservation capped by `available_to_sell` on allocation (§4).

### Web

| Route | Page |
|-------|------|
| `/shop/cart` | `ShopCartPage.vue` |
| `/shop/checkout` | `ShopCheckoutPage.vue` (submit disabled until P7) |

### Exit

- [x] Add to cart creates reservation
- [x] Cannot exceed `available_to_sell`
- [x] Checkout page shell only (no submit yet)

---

## P7 — Orders (`shop_order_mgmt`)

**Read:** SHOP_ORDER §7.7, §8, §12

### Migration

**Tables:** `shop_orders`, `shop_order_items` per §7.7

**Enum:** `shop_order_status` per §8 lifecycle

**RPCs:**

- `submit_shop_order_from_cart(p_cart_id)`
- `staff_price_shop_order`, `customer_counter_offer`, `staff_counter_offer`
- `confirm_shop_order`
- `list_shop_orders_for_customer`, `list_shop_orders_for_staff`

Enforce shop_type × order_mode matrix at submit (§3).

### Web

| Route | Scope | Page |
|-------|-------|------|
| `/shop/orders` | shop | `CustomerOrdersPage.vue` |
| `/shop/orders/:id` | shop | `CustomerOrderDetailPage.vue` |
| `/app/shop/orders` | app | `StaffOrdersPage.vue` |
| `/app/shop/orders/:id` | app | `StaffOrderDetailPage.vue` |

Borrow negotiate UX: `commerce_order/pages/AdminCommerceOrderDetailsPage.vue`

### Exit

- [x] Vendor catalog order reaches `placed`
- [x] Fixed checkout reaches `confirmed`
- [x] Cart status = converted after submit

---

## P8 — Fulfillment (`shop_fulfillment`)

**Read:** SHOP_ORDER §8.3, §9, §12 | **Note:** blocked until `sales_invoice` can post `global_invoices`

### Migration

**RPCs:**

- `place_shop_order_for_procurement(p_order_id)`
- `list_procurement_shop_order_lines(p_parent_tenant_id, ...)`
- `fulfill_shop_order_to_invoice(p_order_id)` → sets `shop_orders.global_invoice_id`

If sales_invoice not ready: stub `fulfill_shop_order_to_invoice` with clear error; UI button disabled + tooltip.

### Web

Extend `StaffOrderDetailPage.vue` — fulfill actions, links to invoice / shipment pull.

### Exit

- [x] Vendor `placed` lines appear in procurement pull RPC
- [x] OR stub documented with sales_invoice dependency (sales_invoice is fully ready and integrated)
- [x] Fulfill UI wired (enabled or disabled with reason)

---

## P9 — Legacy redirects

**Read:** SHOP_ORDER §2 redirects, §13

### Web only

Add to `shop_order/routes/adminRoutes.ts` and `shopRoutes.ts`:

| From | To |
|------|-----|
| `/app/commerce/shop` | `/app/shop/shops` |
| `/app/commerce/orders` | `/app/shop/orders` |
| `/shop/commerce/*` | `/shop/*` equivalents |

Update [MASTER_PLAN.md](MASTER_PLAN.md) §10.1: `shop_order` status.

### Exit

- [x] Legacy commerce routes redirect to shop_order targets
- [x] No broken nav links for enabled tenants
- [x] MASTER_PLAN status updated
