# Feature Blueprint: Shop Scope Visual Redesign

**Status:** Planned (not implemented)  
**Type:** Visual identity + hierarchy. **Not** a new IA, routing map, or page layout.  
**Surfaces:** Logged-in `shop` scope (`theme-shop`, `ShopLayout` → `WorkspaceShell`).  
**Related:** [`SHOP_ORDER.md`](../shop_order/SHOP_ORDER.md) · [`UI_FLOW.md`](../shop_order/UI_FLOW.md) · [`docs/UI_CONSISTENCY.md`](../../docs/UI_CONSISTENCY.md)

---

## 1. User Story & Core Logic

A wholesale customer logs into `/:slug/shop/*` to browse stock, price, cart, and orders. Today the screen looks like the merchant **app** desk with a blue Search button. They should feel they entered a **commerce catalog**, while still using the same pages and buttons.

**Locked product choice:** keep the current layout. Search stays on top. Product grid stays a grid. Cart stays in the header. Drawer / breadcrumbs / bottom nav stay. Modernization is tokens, type, photo treatment, and chrome mood.

**Why it feels dull today**

| Cause | What the user sees |
| :--- | :--- |
| All four scopes share `--bw-neutral-canvas` `#fbfaf7` | Same cream ops paper |
| Shop only swaps `--bw-theme-primary` to `#3d52b0` at **8%** soft | Accent is almost invisible |
| Cool indigo on warm parchment | 2016 corporate, not trade catalog |
| `WorkspaceShell` chrome identical to app | Staff tool, not store |
| Cards: 160px `contain` image, 12px name, `text-grey-*` | Inventory tiles, not products |
| “Shop rhythm” = extra padding only | Density tweak, not identity |

**Success:** a buyer can tell shop from app in one glance (canvas + accent + photo cards), without learning a new page map.

**Non-goals in one line:** no public anonymous storefront, no new routes, no RPC/schema work.

---

## 2. Data Modeling & Database Schema

N/A — no tables, columns, enums, or RLS. Appearance stays CSS tokens + Vue classes. Tenant logo / shop name already exist; do not add a shop theme picker in this pass.

---

## 3. AuthN, AuthZ, & Permissions

N/A — same Google OAuth shop scope, same grants (`shop_storefront`, `shop_cart`, `shop_order_mgmt`). Do not change `createShopAccessGuard` or price/qty permission chips on cards.

Staff preview (`/:slug/app/shop/shops/:id/preview`) must inherit the same `.theme-shop` tokens so preview matches the customer catalog.

---

## 4. API Surface & Contracts (Per Page/Module)

N/A — no payload or RPC changes. Catalog still uses existing list / detail / cart queries. TanStack Query keys stay as in `SHOP_ORDER.md`.

If a component currently hardcodes `text-grey-6` for muted copy, switch to `--bw-theme-muted` / `.bw-text-muted`. That is CSS only.

---

## 5. UI & Responsive Design Strategy

### 5.1 What stays (layout lock)

- `ShopLayout.vue` + `WorkspaceShell` (`theme="shop"`)
- Routes in `web/src/modules/shop_order/routes/shopRoutes.ts` and shop dashboard
- Storefront stack: toolbar → infinite grid → filters drawer
- Card actions: qty stepper, add/remove cart, admin toggles when staff preview
- Mobile bottom nav on `xs`
- `q-page` max-width `1200px` unless a later phase explicitly widens catalog only

### 5.2 What changes (skin + hierarchy)

**A. Shop token set** — `.theme-shop` / `body.theme-shop` in `web/src/css/app.scss`

Give shop its **own canvas and surface**, not only primary. Keep TradeFlow BD family (ink, muted, 8px buttons).

| Token | Current | Target (light) | Job |
| :--- | :--- | :--- | :--- |
| `--bw-theme-base` | shared cream `#fbfaf7` | Cool catalog paper `#f4f6fb` | Photos sit on a clean stage |
| `--bw-theme-surface` | `#ffffff` | `#ffffff` | Cards stay white |
| `--bw-theme-border` | warm `#e7e1d8` | Cool stone `#dbe1ea` | Matches cool canvas |
| `--bw-theme-ink` | `#171412` | Near-navy `#141824` | Sharper product names |
| `--bw-theme-muted` | `#736a61` | `#5c6575` | Captions, not Material grey |
| `--bw-theme-primary` | `#3d52b0` indigo | **Shipped:** commerce copper `#c45c26` | Cart, Search, active nav |
| `--bw-theme-primary-soft` | `rgb(61 82 176 / 0.08)` | **16%** (`0.16`) | Nav/pills actually read as shop |
| `--bw-theme-shadow` | 12% indigo wash | Slightly deeper indigo (`0.16`) | Card hover |

Dark mode (`body.body--dark .theme-shop`): copper `#e08a4f`; cool slate base/surface/border, not the shared warm dark stone.

**B. Chrome mood (same slots, quieter desk)**

Files: `ShopLayout.vue`, `WorkspaceShell.vue` shop branches only.

- Header: opaque cool surface (no `backdrop-filter`). Cart icon remains the loudest chrome control (`color="primary"`).
- Do not add a header color badge or drawer accent rail (still forbidden in `UI_CONSISTENCY.md`) unless this doc is later amended.
- Active nav + shop bottom nav: filled pill using the new 16% `--bw-theme-primary-soft`.
- Hide or de-emphasize ops-only chrome on **catalog / product / cart / checkout** only: compact-density toggle is irrelevant to buyers; do not surface it in the shop header menu if it is only useful for tables. Orders/wallet pages may keep table density.

**C. Product cards (same grid, new hierarchy)**

File: `StorefrontProductCard.vue` (+ admin reuse on Shop Settings storefront tab).

| Now | Target |
| :--- | :--- |
| Image box 160px, `object-fit: contain`, 8px inner pad | Taller stage (~200px desktop / ~168px mobile), still `contain` so packshots are not cropped; **cool tint behind image** (`color-mix` 6% primary into surface), **edge-to-edge** (no 8px pad) |
| Name 12px / 3-line clamp | Name `0.875rem` / weight 600 / 2-line clamp |
| Price 13px grey-adjacent | Price **hero**: `1rem` / 700 / `--bw-theme-ink` + `.bw-tabular` |
| Brand `text-uppercase` caption | Brand `--bw-theme-muted`, not `text-grey-*` |
| Qty / avail as green-red caption | Keep permission gates; use `--bw-success` / `--bw-error`, not Quasar `text-positive` if it fights tokens |
| Hover `translateY(-4px)` | Keep lift; shadow uses shop `--bw-theme-shadow` |
| Border `q-card flat bordered` radius 16px | Keep radius 16px; border `--bw-theme-border` |

Admin-only rows (listing toggle, calculate sell price) stay below the commerce block so buyers never see them; staff preview may look slightly denser — acceptable.

**D. Toolbar**

`StorefrontSearchToolbar.vue`: keep one row. Search stays `.soft-input`. Primary Search button stays unelevated primary. Shop switcher outline primary. Replace `text-grey-9` shop name with `--bw-theme-ink`.

**E. Product detail, cart, checkout, dashboard**

Same tokens. Detail title already `1.125rem / 600` under `body.theme-shop` — bump price to tabular hero like the card. Cart line thumbs keep `.shop-product-thumb` contain rules. `CustomerDashboard.vue` hero/status strip uses shop canvas + primary, not app teal leftovers.

**F. Breakpoints**

- `xs`: bottom nav unchanged; image stage shorter; qty + add-to-cart stay full width under price.
- `sm+`: 2–4 column grid unchanged (`col-sm-6 col-md-4 col-lg-3`).

**G. Page headers & skeletons**

- **Catalog / detail / cart:** commerce surfaces. Do **not** copy PBC list golden header (`text-overline` + `h1.text-h5` + pill CTA). Keep existing storefront chrome. Skeletons: `StorefrontSkeletonGrid` must match new card image height and radius.
- **Orders / order detail / wallet:** still ops-like. Follow [`PAGE_LAYOUT_AND_LOADERS.md`](../../docs/PAGE_LAYOUT_AND_LOADERS.md) as today. Only inherit shop tokens (canvas/primary), not catalog card rules.

---

## 6. State Management & Routing

N/A for data stores. No new Pinia. No route moves.

Theme application remains `WorkspaceShell` `applyBodyThemeClass('shop')` + page class `theme-shop`. After token change, confirm `body.theme-shop` and nested `.theme-shop` both resolve the new variables (drawers/quick view already add `theme-shop`).

Koba routes that reuse `ShopLayout` inherit tokens automatically. Do not special-case Koba in this pass.

---

## 7. Style Guidelines & Accessibility

- Tokens only: `--bw-theme-*`, `--bw-success|warning|error|info`. Ban new hex on components except the token block in `app.scss`.
- Replace Quasar `text-grey-5`…`text-grey-9` on shop catalog components with theme ink/muted.
- Contrast: indigo on white buttons must stay WCAG AA for the Search / Add to cart labels.
- Focus: keep existing 3px `--bw-theme-primary-soft` ring on `.soft-input`.
- Motion: hover lift ≤ 4px; respect `prefers-reduced-motion` (disable transform if that media query is already used globally; add on cards if missing).
- Radius: buttons 8px, cards 16px (hero-class), chips 4px / pills 999px as today.
- No `backdrop-filter` on header/toolbar.
- `data-test` on shop switcher stays.

Update [`docs/UI_CONSISTENCY.md`](../../docs/UI_CONSISTENCY.md) **when this ships**: shop row in the scope table + “Shop rhythm” section to match target tokens (not only padding).

---

## 8. Network Handling & Loading Strategy

No new fetches. Keep TanStack Query as in `SHOP_ORDER.md`.

| State | Treatment |
| :--- | :--- |
| First catalog paint | `StorefrontSkeletonGrid` sized to new card geometry |
| Load more | Existing `q-infinite-scroll` |
| Cart mutation | Existing button `loading` on that card |
| Empty / denied / not found | Existing empty/error blocks; restyle copy color to tokens only |

GlobalAjaxBar unchanged.

---

## 9. Component Specifications

| File | Change |
| :--- | :--- |
| `web/src/css/app.scss` | `.theme-shop` light + dark token block; `body.theme-shop` rhythm (padding may stay) |
| `web/src/layouts/ShopLayout.vue` | Cart stays primary; no layout restructure |
| `web/src/components/WorkspaceShell.vue` | Shop-only header/nav fill using stronger primary-soft; optional hide compact toggle on commerce routes |
| `web/src/modules/shop_order/components/StorefrontProductCard.vue` | Image stage, type scale, price hero, no grey utilities |
| `web/src/modules/shop_order/components/StorefrontSearchToolbar.vue` | Ink/muted tokens |
| `web/src/modules/shop_order/components/StorefrontSkeletonGrid.vue` | Match card image height |
| `web/src/modules/shop_order/pages/StorefrontPage.vue` | Class hooks only if needed (`storefront-page` already exists) |
| `web/src/modules/shop_order/pages/StorefrontProductDetailPage.vue` | Price/title hierarchy |
| `web/src/modules/shop_order/components/ProductQuickView.vue` | Inherits `theme-shop` |
| `web/src/modules/dashboard/pages/CustomerDashboard.vue` | Token-aligned hero/strip |
| `docs/UI_CONSISTENCY.md` | After implement: lock new shop tokens |

**App-scope Shop Settings storefront tab** uses the same card component inside `.theme-shop` preview — it should look like the catalog, not like the surrounding emerald app chrome (already wrapped).

---

## 10. Explicit Out of Scope

1. New page map, new shell, or removing `WorkspaceShell` / breadcrumbs / drawer.
2. Public unauthenticated storefront, custom domain marketing site, or tenant-branded theme editor.
3. Schema, RPC, price permission, or cart engine changes.
4. Rewriting order list / dropship finance as a “shop look” (those stay ops tables).
5. Koba-specific merchandising, Thrift POS, or platform/app token changes.
6. Illustration packs, hero banners, or editorial homepages.
7. Changing `q-page` max-width globally.

---

## 11. Testing Strategy

- Manual: browse catalog → detail → add to cart → checkout header cart count; staff preview vs customer must match tokens.
- Dark mode: shop canvas stays cool; primary `#e08a4f` still AA on buttons.
- `xs` and `md` viewports: grid columns and bottom nav.
- Permission variants: hidden price / hidden qty must not leave empty grey holes.
- No new unit tests required unless card class names are asserted (they are not today).
- Do not run full `vue-tsc` for token CSS; spot-check changed Vue for leftover `text-grey-*`.

---

## 12. Definition of Done

- [ ] `.theme-shop` light tokens: own base, border, ink, muted, primary-soft **16%**
- [ ] Dark shop tokens: cool surfaces, not shared warm stone
- [ ] Product card: taller image stage, price is the loudest number, no `text-grey-*` on catalog card
- [ ] Skeleton grid matches card geometry
- [ ] Search toolbar + dashboard + detail use shop ink/muted
- [ ] Layout/routes/RPCs unchanged
- [ ] `docs/UI_CONSISTENCY.md` shop table + Shop rhythm updated to shipped values
- [ ] Browser check: catalog, detail, cart icon, mobile bottom nav, staff preview

---

## Implementation phases (for a later Agent pass)

**Phase 1 — Tokens**  
`app.scss` `.theme-shop` / dark / `body.theme-shop`. No Vue structure edits.

**Phase 2 — Catalog card + skeleton + toolbar**  
The three storefront components above. Highest visual payoff.

**Phase 3 — Chrome + remaining shop pages**  
WorkspaceShell shop nav fill; detail/dashboard/quick view token cleanup; UI_CONSISTENCY lock.

---

## Clarification (resolved in conversation)

Shop **layout is locked**. If product later wants a public-store shell, that is a separate blueprint.
