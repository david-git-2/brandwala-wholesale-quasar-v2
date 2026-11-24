# Customer Shop Dashboard — UX Audit & Solution Report

**Date:** 2026-11-24  
**Scope:** Customer Shop Portal Dashboard (`/shop/:tenantSlug/:shopType/dashboard`)  
**Primary Files:**
- `web/src/modules/workspace/submodules/dashboard/pages/CustomerDashboard.vue`
- `web/src/modules/workspace/submodules/dashboard/components/CustomerDashboardQuickAction.vue`
- `web/src/modules/workspace/submodules/dashboard/components/CustomerDashboardActiveCarts.vue`
- `web/src/modules/workspace/submodules/dashboard/components/CustomerDashboardTopSection.vue`
- `web/src/modules/workspace/submodules/dashboard/components/CustomerDashboardCategories.vue`
- `web/src/modules/workspace/submodules/dashboard/components/CustomerDashboardOrdersPanel.vue`
- `web/src/modules/workspace/submodules/dashboard/components/CustomerDashboardStatusStrip.vue`
- `web/src/layouts/shop/ShopShell.vue`

---

## 1. Status Summary

The Customer Dashboard has been upgraded from a passive summary page into a **scoped, action-oriented workspace** with a personalized command header, attention banner, full-width metric cards, an active carts strip, interactive shop/category/order-status entry points, and a 7/5 desktop bento layout.

---

## 2. What Remains To Be Done

### 2.1. Backend / Data Enhancements
1. **Shop Logos in Dashboard & Cart Payloads**
   - `get_customer_dashboard_summary` currently returns `null::text as shop_logo_url` for `active_carts` and omits `logo_url` on `shops`.
   - **To do:** Return actual shop logo URLs in `get_customer_dashboard_summary` so `CustomerDashboardTopSection` and `CustomerDashboardActiveCarts` display real brand avatars instead of fallback icons.
2. **Shop-Scoped Filtering on `CustomerOrdersPage.vue`**
   - Clicking `{N} active orders` on a shop card currently opens `shop-orders-page` without filtering to that specific `shop.id`.
   - **To do:** Add optional `?shopId=` query param support to `CustomerOrdersPage.vue` and `list_customer_shop_orders` so clicking a shop's active-orders chip opens pre-filtered orders for that shop.

### 2.2. Layout & UX Polish
3. **Recent Orders Table Alignment (`CustomerOrdersList.vue`)**
   - On desktop, the `DATE` column header in `layout="dashboard"` sits slightly left of the right-aligned date value, and `Shop` + `Date` can be condensed into a cleaner two-line or tightly aligned row inside the 5-column side panel.
   - **To do:** Refine `CustomerOrdersList.vue` `layout="dashboard"` column spacing and responsive density.
4. **Skeleton Parity (`CustomerDashboardSkeleton.vue`)**
   - Update `CustomerDashboardSkeleton.vue` to mirror the new Command Header + 3-column Metric Strip + 7/5 Bento Grid (Shops + Recent Orders) so loading transitions do not shift layout.
5. **Multi-Shop Cross-Type Switcher on Dashboard (Optional)**
   - The dashboard intentionally preserves the URL `:shopType` scope (`catalog` | `stock` | `dropship`).
   - **To do (if needed):** Add an explicit top-level shop-type segmented toggle on the dashboard so users with access to multiple shop types (e.g. `Catalog` and `Dropship`) can switch `:shopType` in one click without using the shell navigation.
