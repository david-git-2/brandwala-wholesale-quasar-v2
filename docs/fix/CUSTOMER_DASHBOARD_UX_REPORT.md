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
- `web/src/modules/workspace/submodules/dashboard/components/CustomerDashboardSkeleton.vue`
- `web/src/modules/shop_order/pages/storefront/CustomerOrdersPage.vue`
- `web/src/modules/shop_order/components/CustomerOrdersList.vue`
- `web/src/layouts/shop/ShopShell.vue`

---

## 1. Status Summary

All planned UX/UI phases and follow-up polish items have been implemented:
- **Interactive affordances:** Category cards route to `?category=`, order status pills link to `shop-orders-page?bucket=`, KPI cards (`Total products`, `Total orders placed`) are clickable, and shop cards expose `Browse catalog`, `Resume cart`, and `?shopId=`-filtered active order chips.
- **Command Header & Bento Layout:** Personalized greeting, scoped `:shopType` eyebrow badge (strictly locked to the login `:shopType`—no cross-type toggle), `Needs you` / `Payment needed` attention banner, active carts strip, full-width 3-column KPI strip, 7/5 desktop bento grid, shop monogram avatars, and matching skeleton.
- **Shell Alignment:** Global product search remains accessible across dashboard, catalog, cart, and order routes alongside `CatalogShopHeaderSwitcher`.

---

## 2. Optional Future Backend Enhancement

- **Shop Logo Column (`public.shops`):** `public.shops` currently has no `logo_url` column (`get_customer_dashboard_summary` returns `null::text as shop_logo_url`). Shop cards currently render monogram initials; if a `shops.logo_url` column is added later, wire it into `get_customer_dashboard_summary` to display uploaded shop logos.
