---
name: Shop Order Build
overview: Agent index only. Say "Implement SHOP_ORDER P{N}". Read doc/SHOP_ORDER_PHASES.md + doc/SHOP_ORDER.md § for that phase. Do not paste this whole file for every phase.
todos:
  - id: p0-products
    content: "P0: products multi-currency (done)"
    status: completed
  - id: p1-scaffold
    content: "P1: scaffold + shops + module seed (done)"
    status: completed
  - id: p2-shops
    content: "P2: shop CRUD RPCs + admin page (done)"
    status: completed
  - id: p3-perms
    content: "P3: permission tables/RPCs + admin UI (shop_permissions)"
    status: pending
  - id: p4-pricing
    content: "P4: shop_product_listings + pricing page (shop_pricing)"
    status: pending
  - id: p5-storefront
    content: "P5: browse_shop_catalog + storefront (shop_storefront)"
    status: pending
  - id: p6-cart
    content: "P6: cart tables/RPCs + cart pages (shop_cart)"
    status: pending
  - id: p7-orders
    content: "P7: order tables/RPCs + order pages (shop_order_mgmt)"
    status: pending
  - id: p8-fulfill
    content: "P8: fulfillment RPCs (shop_fulfillment; needs sales_invoice)"
    status: pending
  - id: p9-redirects
    content: "P9: legacy commerce route redirects"
    status: pending
isProject: false
---

# Shop Order — Agent Index

## How to run

**Do not** paste this file and say "implement all phases."

```
Implement SHOP_ORDER P{N} only.
1. Read doc/SHOP_ORDER_PHASES.md — confirm P{N} is next.
2. Read the P{N} deliverables in that file.
3. Read doc/SHOP_ORDER.md sections listed for P{N} in the phase index below.
4. Follow global rules below.
5. Stop when P{N} exit criteria pass. Mark P{N} done in doc/SHOP_ORDER_PHASES.md. Do not start P{N+1}.
```

**Progress tracker:** [doc/SHOP_ORDER_PHASES.md](../../doc/SHOP_ORDER_PHASES.md)  
**Canon (schema, permissions, UI):** [doc/SHOP_ORDER.md](../../doc/SHOP_ORDER.md)

---

## Global rules (every phase)

| Rule | Detail |
|------|--------|
| Canon | [doc/SHOP_ORDER.md](../../doc/SHOP_ORDER.md) — read **only** § listed for that phase |
| Pattern | [web/src/modules/procurement_stock/](../../web/src/modules/procurement_stock/) — repository → service → store → page |
| UI | `bw-page`, `AppPageHeader`, `q-card flat bordered` — [UI_CONSISTENCY_GUIDE.md](../../web/UI_CONSISTENCY_GUIDE.md) |
| New code | `web/src/modules/shop_order/` + `supabase/migrations/` only |
| Forbidden | `commerce_*`, legacy `store`, `cart`, `order` imports in **new** shop_order files |
| No legacy FK | No FK to `stores`, `carts`, `orders`, `commerce_*` (D-SH1) |
| Money | `*_amount numeric(12,4)` + `*_currency_id → global_currencies` (D-SH4) |
| Module seed | `public.modules` — copy [20260831000000_investor_capital_module_hierarchy.sql](../../supabase/migrations/20260831000000_investor_capital_module_hierarchy.sql) pattern |
| Migration name | `supabase/migrations/YYYYMMDD_shop_order_p{N}_<slug>.sql` |
| Max reads | 1 doc § + 1 pattern file + 1 legacy borrow file |
| On complete | Mark phase `done` in [doc/SHOP_ORDER_PHASES.md](../../doc/SHOP_ORDER_PHASES.md) |

---

## Module keys (seeded P1)

Parent: `shop_order`

| submodule_key | scope | route segment |
|---------------|-------|---------------|
| `shop_config` | app | `shop/shops` |
| `shop_permissions` | app | `shop/customer-groups` |
| `shop_pricing` | app | `shop/shops/:id/pricing` |
| `shop_storefront` | shop | `shop/browse/:shopSlug` |
| `shop_cart` | shop | `shop/cart` |
| `shop_order_mgmt` | app+shop | `shop/orders` |
| `shop_fulfillment` | app | `shop/orders/:id` |

---

## Target folder

```
web/src/modules/shop_order/
├── routes/adminRoutes.ts
├── routes/shopRoutes.ts
├── types/index.ts
├── repositories/shopRepository.ts
├── services/shopService.ts
├── stores/shopStore.ts
├── pages/admin/
├── pages/shop/
└── components/
```

Wire in: [router/routes.ts](../../web/src/router/routes.ts), [moduleRegistry.ts](../../web/src/modules/navigation/moduleRegistry.ts), [modulePermissions.ts](../../web/src/modules/navigation/modulePermissions.ts).

---

## Phase index

| Phase | Status | SHOP_ORDER § | Migration slug | Submodule |
|-------|--------|--------------|------------------|-----------|
| P0 | done | §6 | `p0_products_currency` | — |
| P1 | done | §2, §7.1, §11 | `p1_scaffold` | `shop_order` |
| P2 | done | §3, §7.1, §12 | `p2_rpcs` | `shop_config` |
| P3 | **next** | §5, §7.2–7.3, §12 | `p3_permissions` | `shop_permissions` |
| P4 | pending | §4, §7.4, §12 | `p4_listings` | `shop_pricing` |
| P5 | pending | §5.4, §12 | `p5_browse` | `shop_storefront` |
| P6 | pending | §7.5–7.6, §8.3, §12 | `p6_cart` | `shop_cart` |
| P7 | pending | §7.7, §8, §12 | `p7_orders` | `shop_order_mgmt` |
| P8 | pending | §8.3, §9, §12 | `p8_fulfillment` | `shop_fulfillment` |
| P9 | pending | §2, §13 | — (web only) | — |

**Per-phase deliverables, RPCs, routes, exit criteria:** [doc/SHOP_ORDER_PHASES.md](../../doc/SHOP_ORDER_PHASES.md)

**Unified permission system (separate track):** [doc/PERMISSION_SYSTEM.md](../../doc/PERMISSION_SYSTEM.md) §17 — PERM P1 (DB+RPC) → P2 (UI) → P3 (seeding + RLS cutover). Runs after shop_order P8 + B7 cleanup. Shop P3 covers Subsystem B only.
