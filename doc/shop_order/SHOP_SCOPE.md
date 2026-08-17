# Shop scope — customer portal

Canon for the **shop login** (`/:slug/shop/*`): customer-group members buying from child-tenant storefronts.

Staff Shops / Orders / Shipping stay in [SHOP_ORDER.md](SHOP_ORDER.md). Dropship ops stay in [SHOP_ORDER_DROPSHIP.md](SHOP_ORDER_DROPSHIP.md). Tenant **app** home uses the widget registry in [dashboard/README.md](../dashboard/README.md) — **do not** reuse that pattern here.

**Job of shop home:** after login, the buyer answers “where do I buy, and does anything need me?”

> [!IMPORTANT]
> **Session rule (D-SC1 / D-SC2):** the shop session is `(user, tenant_id, customer_group_id)` and `tenant_id` comes from the URL `:tenantSlug` — never from app-workspace storage. Every customer RPC takes a **required** `p_tenant_id`; null means **deny**, never “all tenants”. Isolation work and the legacy drop live in [fix/SHOP_SCOPE_TENANT_ISOLATION.md](../fix/SHOP_SCOPE_TENANT_ISOLATION.md).

Related: [APP_SCOPES_AND_ACCESS.md](../APP_SCOPES_AND_ACCESS.md), [LOGIN_NAV_PERMISSION_FLOW.md](../LOGIN_NAV_PERMISSION_FLOW.md), [fix/SHOP_SCOPE_TENANT_ISOLATION.md](../fix/SHOP_SCOPE_TENANT_ISOLATION.md), [docs/UI_CONSISTENCY.md](../../docs/UI_CONSISTENCY.md), [docs/PAGE_LAYOUT_AND_LOADERS.md](../../docs/PAGE_LAYOUT_AND_LOADERS.md), [docs/TANSTACK_QUERY_GUIDE.md](../../docs/TANSTACK_QUERY_GUIDE.md).

---

## 1. User story & core logic

**As a** customer-group member (`customer_admin` / `customer_negotiator` / `customer_staff`),  
**I want** a home that shows shops I can use and orders that need me,  
**So that** I open a catalog or confirm an order in one step — without hunting shortcut tiles or waiting on extra API waves.

Happy path:

1. Land on `/:slug/shop/dashboard`.
2. Greeting by time of day. Then a **status strip** (Needs you · In progress · Done) if the group has any orders. Hide the strip when the count is zero. No Chart.js.
3. Resume last shop (and cart line if that shop has items) + product search.
4. Shop cards only when the group has **more than one** shop. One shop → resume card is the shop.
5. Recent orders only when there is at least one order (max 3, waiting first). Waiting rows use a verb (`Confirm price` / `Reply`).
6. Cart badge in the header only. Sidebar: **Home · Catalog · Orders**. No Help Center.

---

## 2. Remaining gaps (S0–S0c / S1 landed)

Home is greeting + status strip + resume + shops + 3 recent orders. Do **not** restore KPI tiles, Chart.js, or the attention banner.

| Friction | Why it hurts |
|----------|----------------|
| **Same email in two sister tenants sees the other tenant's orders / carts** | **T0–T1: tenant is not the session boundary — [fix/SHOP_SCOPE_TENANT_ISOLATION.md](../fix/SHOP_SCOPE_TENANT_ISOLATION.md)** |
| Orders list has no “needs you” filter | S3: strip click should land on that filter |
| Orders page shows `Merchant wallet` + `Browse Wholesale Shops` | S3 / T3: violates §5b nav words; wallet is not a customer primary |
| Search is one-shop `?q=` | S5: cross-shop RPC |
| Shop type chip uses staff labels | Customer should see Catalog / Shop / Dropship |

Fetch (target shape):

| Wave | Request | Keep? |
|------|---------|--------|
| 1 | `list_customer_shops(p_tenant_id)` | Yes — first paint; carries `sell_currency_symbol` |
| 1 | `list_customer_active_carts(p_tenant_id)` | Layout cart badge; home reuses cache |
| 2 | `list_customer_shop_orders(p_tenant_id, limit 20)` | **One call for all shops** — glance + 3 recent rows; do not block shops |

Do not fetch `shop_categories`, `global_currencies`, or `shops?select=sell_currency_id` on this page. Do not call one order RPC per shop.

---

## 3. AuthZ & permissions

Existing shop dashboard guard. No new grants.

- Scope: `shop`
- Roles: `customer_admin`, `customer_negotiator`, `customer_staff`
- Actor: `customer_group_member` with `customerGroupId`
- Page modules: home has no extra module key; Catalog = `shop_storefront` (`/shop/browse`); Orders = `shop_order_mgmt`; Cart = `shop_cart` (header icon, not sidebar). No Help Center on shop login.

### 3.1 Tenant boundary (locked)

Two independent checks are required on every customer read. RLS answers *may this person read the row*; it does **not** answer *does the row belong to the tenant in the URL*.

| Layer | Rule |
|-------|------|
| URL | `tenant_id` resolves from `:tenantSlug`. `x-selected-tenant-id` for a `shop` session comes from the shop auth snapshot — **never** from the app workspace key |
| Guard | Shop routes compare `to.params.tenantSlug` with `authStore.tenantSlug`; mismatch → shop login for that slug |
| RPC | `p_tenant_id` **required**. Resolve the group with `current_customer_group_id(p_tenant_id)`; null group → empty result |
| Row | `row.tenant_id = p_tenant_id` **and** `row.customer_group_id = <resolved group>` |
| Shop identity | `(p_tenant_id, slug)` or a `shop_id` verified against `p_tenant_id`. `shops.slug` is unique per `(tenant_id, slug)` only — slug alone is not an identity |
| Switching | Another sister's slug is a **context switch**: re-resolve the group and purge the `['shopOrder']` query cache. No tenant switcher in the header |

---

## 4. API surface (dashboard = S0)

No new tables. No fat `get_customer_dashboard` RPC. Every call below takes a **required** `p_tenant_id` (§3.1).

| Call | When |
|------|------|
| `list_customer_shops(p_tenant_id)` | First paint. Embedded `categories` + `sell_currency_id` / `sell_currency_code` / `sell_currency_symbol`. Do **not** fetch `shop_categories` |
| `list_customer_shop_orders(p_tenant_id, p_limit, p_offset, p_status_bucket)` | **One call for all shops.** Cap **20** for glance counts; home lists **3** rows. Carries `shop_name`, `shop_slug`, `currency_symbol` — do **not** follow with `shops?select=sell_currency_id` or a currency list |
| `list_customer_active_carts(p_tenant_id)` | `ShopLayout` badge. Home **reuses the same query cache** for the resume cart line — no second fetch |
| `get_customer_shop_order(p_tenant_id, p_order_id)` | Order detail. Raises when the order's tenant differs. Customer paths never use `select('*')` on `shop_orders` |
| `browse_shop_catalog_for_customer(p_tenant_id, p_shop_slug, …)` | Storefront. Resolves the shop by `(tenant_id, slug)` from the argument, not from the request header |

Search in S0: prefer `router.push` to browse with `?q=` (one hop). Do not add a cross-shop search RPC until S5.

Optional later (not S0 / not Home):

- `get_customer_order_glance` — counts/sparkline for Orders or Reports, not Home

`list_shop_orders_for_staff` is staff-only. Do not reuse it on shop login.

**Retired (do not call):** `list_shops_for_customer`, `list_shop_orders_for_customer`, `list_active_shop_carts`, `browse_shop_catalog(p_shop_slug, …)` — all tenant-optional or header-resolved. Drop plan: [fix/SHOP_SCOPE_TENANT_ISOLATION.md](../fix/SHOP_SCOPE_TENANT_ISOLATION.md) §6.

---

## 5. UI — target home (S0, attention-first)

B2B buying desk, not a lifestyle storefront. The page should feel like it already knows the buyer.

```
Header (existing): tenant · cart badge · nav: Home · Catalog · Orders

Good evening, Karim
┌ Your orders                                              ┐  ← omit when zero orders
│ Needs you 2   In progress 1   Done 4                     │
│ ████████░░░░░░░░░░░░░░░░                                 │  CSS bar, not Chart.js
└──────────────────────────────────────────────────────────┘
┌ Resume                      ┐  ┌ Find a product              ┐
│ Open “Dhaka Wholesale”      │  │ Search…              Search │
│ 3 items in cart             │  │                             │
└─────────────────────────────┘  └─────────────────────────────┘

Your shops                    ← omit when shops.length === 1
┌ Shop name     Open → ┐  ┌ Shop name     Open → ┐
│ Fixed price          │  │ Dropship · Last opened│
│ Knit · Woven         │  │                       │
└──────────────────────┘  └───────────────────────┘

Recent                        ← omit when zero orders; 3 rows, waiting first
  SO-104  Confirm price    ৳12,400  →
  SO-101  Confirmed        ৳8,200   →
```

**Greeting:** one line, time of day + name (`Good morning` / `afternoon` / `evening`). No tenant overline (already in the shell). No decorative storefront icon. No marketing subtitle.

**Status strip (S0c):** three clickable counts + a CSS stacked bar. Replaces the attention banner — do not show both. Hide the strip when glance `total === 0`. Click any cell → `/shop/orders` (no query filter until S3). Counts come from the latest **20** orders per shop (skip `draft`). Not Chart.js. Not fake ৳ totals.

Buckets:

| Bucket | Statuses |
|--------|----------|
| **Needs you** | `priced`, `negotiating`, `countered`, `final_offered` |
| **Done** | `fulfilled`, `delivered`, `payment_received`, `cancelled`, `returned` |
| **In progress** | everything else except `draft` |

Highlight the Needs you count when it is > 0. The strip skeleton lives with the orders query — do not block shops.

**Resume + search (one row on `md+`):**
- Resume card when `continueShop` exists (last opened, or the only shop). Primary CTA **Open** on this card only.
- Cart caption on resume if that shop’s active cart `item_count > 0` — tap goes to `/shop/cart` (same query as the shell badge).
- Search on the page surface (not inside a gradient). Enter / Search → `browse/{slug}?q=` on continue shop or first shop.

**Shop cards:** destinations, not mini-apps. Name, type chip, up to 3 **text** category tags (from `list_shops_for_customer.categories` — no extra fetch), footer “Open”. Last-opened left inset accent. Do **not** use a 2×2 icon grid (looks filterable, opens the same shop). Skip the grid when there is only one shop.

**Orders:** hide the block when not loading and length is 0 (first visit is a catalog home, not an empty inbox). Waiting rows: filled chip + verb (`Confirm price` for `priced` / `final_offered`; `Reply` for `negotiating` / `countered`). Other statuses: outline + human label.

**Empty shops:** icon + “No shops assigned to your group yet. Ask your supplier.” No Browse CTA.

**CTA rule:** one `unelevated` primary — resume **Open** when a continue shop exists. Shop-card Open is `flat`. Status-strip cells are text buttons, not a second primary. Never a second primary in empty orders.

**Do not bring back:** KPI tiles, Chart.js on Home, shortcut hub, attention banner (strip replaced it), `/app/docs`, nested category mini-tiles, **Browse** as a nav label, Cart as a sidebar item.

Theme: `.theme-shop`. Layout: `q-page` + `q-gutter-y-md`. Follow [PAGE_LAYOUT_AND_LOADERS.md](../../docs/PAGE_LAYOUT_AND_LOADERS.md) and frictionless UI.

---

## 5b. Shop nav (S1)

Customer shell is three destinations. Cart is the header icon with a badge.

| Label | Route | Module | Caption |
|-------|--------|--------|---------|
| **Home** | `/shop/dashboard` | (base) | Shops and orders that need you |
| **Catalog** | `/shop/browse` | `shop_storefront` | Browse products and order |
| **Orders** | `/shop/orders` | `shop_order_mgmt` | Track and reply |

Do **not** use **Browse** (mall verb) or **Dashboard** (staff word) or **Shops** (collides with staff setup nav + captions). Do **not** put Cart in the sidebar. `/shop/help` redirects to Home. Koba, if enabled, stays a grouped extra — not part of the default three.

Mobile (`xs`): same three in the bottom bar; cart stays in the top bar.

---

## 5c. Catalog (S2)

**Shop** = a storefront the group can buy from (Home cards, catalog header switcher). **Catalog** = products in the current shop. Staff **Shops** stays app setup.

`/shop/browse` is a resolver, never a picker:

1. Last visited shop **for this tenant** still in `list_customer_shops` → `/browse/{slug}`
2. Else first accessible shop → `/browse/{slug}`
3. Zero shops → Home

Forward `?q=` onto the resolved shop. Product page overline is **Catalog**; H1 is the shop name. Two or more shops: shop-name dropdown on that header. Back goes Home.

Do **not** restore `ShopPickerPage` or labels `Shop Scope` / `Select … Shop` / `Wholesale Storefront`.

---

## 6. State management & routing

| Item | Value |
|------|--------|
| Route | `customer-dashboard` — `/:tenantSlug/shop/dashboard` |
| Queries | TanStack Query; shops `staleTime` ≥ 2 min. **Every customer query key includes `tenantId`** |
| `loading` | **shops only** |
| Orders | Own skeleton in the status strip + orders block; do not hide shops |
| Last shop | `localStorage`, **tenant-scoped**: `shop:{tenantId}:lastShopId` / `:lastShopSlug`. Global `last_visited_shop_*` keys are retired (they leaked another tenant's shop) |
| Context switch | On shop login / logout / slug change: `queryClient.removeQueries({ queryKey: ['shopOrder'] })` |

Drop from `CustomerDashboard.vue`: `useShopCategoryListQuery`, `useShopCurrenciesMapQuery`, `useThriftCurrenciesQuery`.

Do **not** register shop home widgets in `dashboardSlotRegistry.ts`.

---

## 7. Style & accessibility

- Tokens: `var(--bw-theme-*)`, Quasar `color="primary"`
- Greeting and shop/order rows keyboard-activatable
- Icon-only cart stays in `ShopLayout` with badge; resume cart line is extra context, not a second nav item
- Waiting = verb, not raw enum
- EN + BN for every new string
- Shop-card initial letter instead of repeating the same storefront icon on every card

---

## 8. Loading strategy

- Full-page skeleton until shops resolve: greeting + status strip + resume/search + shop cards
- Status strip + orders: own skeleton from the orders query; do not hide shops
- Cart line may appear after layout cache; do not block shops on carts
- Search is a route hop — no modal, no extra catalog RPCs on home

---

## 9. Component map (S0)

| File | Role |
|------|------|
| `CustomerDashboard.vue` | Compose: greeting → status strip → resume/search → shops → orders |
| `CustomerDashboardHero.vue` | Time-of-day greeting only |
| `CustomerDashboardStatusStrip.vue` | Needs you / In progress / Done + CSS bar; omit when zero |
| `CustomerDashboardResumeRow.vue` | Resume card + search |
| `CustomerDashboardShopsGrid.vue` | Destination cards (type chip + text tags); hidden when 1 shop |
| `CustomerDashboardRecentOrders.vue` | List or loading; omit when empty; 3 rows |
| `CustomerDashboardSkeleton.vue` | Match greeting + strip + resume layout |

Deleted (do not restore): `CustomerDashboardStatCards.vue`, `CustomerDashboardActionHub.vue`, `CustomerSearchResultsModal.vue`.

---

## 10. Explicit out of scope

- Admin / thrift dashboard widget registry
- New dashboard snapshot RPC (`get_customer_dashboard` / `get_customer_order_glance`)
- Chart.js, sparklines, or amount series on Home
- Wallet on Home or as an Orders-page primary (dropship groups reach it from the order — see [fix/SHOP_SCOPE_TENANT_ISOLATION.md](../fix/SHOP_SCOPE_TENANT_ISOLATION.md) D-SC8), Koba retail, costing-on-shop
- Category-filtered storefront (optional query param in S2)
- Changing staff `SHOP_ORDER` P11–P15, including staff `select('*')` cleanup
- Separate retail / wholesale / dropship order tables — the `shop_type` × `order_mode` matrix covers it
- A tenant switcher in the shop header (strict URL-per-tenant)
- Cross-shop search RPC (S5)
- Orders-list bucket query param (S3 / T3)

---

## 11. Testing (S0)

Manual:

- 0 shops, 1 shop, many shops
- 0 orders → no status strip; `priced` / `negotiating` → Needs you > 0
- Click strip → `/shop/orders`
- EN and BN
- Cart badge still loads (`list_customer_active_carts` on layout)
- No Help Center or `?` drawer on shop login
- First paint does not wait on categories or currencies
- Catalog nav opens products (last/first shop), never a picker; 0 shops → Home
- Catalog header overline is Catalog; shop-name switcher when more than one shop

Tenant isolation (T0–T1), with one email in two sister tenants:

- `/a/shop/*` never shows tenant B shops, orders, or cart items — and the reverse
- `/a/shop/orders/{id-owned-by-B}` is rejected, not rendered
- Switching A → B without a reload shows no stale A rows; resume shop is a B shop
- Each customer RPC called with `p_tenant_id => null` returns empty, not every tenant

---

## 12. Definition of done (S0)

- [x] First paint = the customer shops call only
- [x] No `/app/docs` from shop home
- [x] One primary CTA (resume Open)
- [x] Empty shops explained
- [x] Orders do not block shops
- [x] i18n EN + BN updated; dead onboarding strings removed or used
- [x] This file is canon; [SHOP_ORDER.md](SHOP_ORDER.md) §12 lists Customer home
- [x] Greeting is time + name; no decorative hero icon / tenant overline
- [x] Status strip (Needs you / In progress / Done) from the latest 20 orders; hidden at zero; no Chart.js; no attention banner
- [x] Resume + search row; cart line from the cached active-carts query
- [x] Shop grid omitted for a single shop; category **tags** not mini-tiles
- [x] Orders block omitted when empty; waiting rows use verbs

---

## Phase tracker

Update status in this table when a phase completes. Execute **S0 first**.

| Phase | Surface | Status | Outcome |
|-------|---------|--------|---------|
| **S0** | `/:slug/shop/dashboard` | done | Fetch cut + shops-first home |
| **S0b** | Same | done | Attention-first visual: greeting, resume+search, destination shop cards, order verbs (§5) |
| **S0c** | Same | done | Status strip (Needs you / In progress / Done). CSS bar. No Chart.js. No glance RPC |
| **S1** | Shop nav | done | Home / Catalog / Orders. Cart icon only. No Help Center. |
| **S2** | Catalog | done | `/shop/browse` resolves to last/first shop. Header switcher when many shops. No picker page |
| **S3** | Orders list/detail | done | Bucket filter (`?bucket=`) from strip click; drop `Merchant wallet` / `Browse Wholesale Shops`; Catalog empty-state CTA. Runs as **T3** |
| **S4** | Cart / checkout | done | Unchanged checkout rules. Home resume cart + last shop open `?shopId=`. Cart CTA typed by shop. |
| **S5** | Search | pending | One cross-shop search RPC. Until then: `browse?q=` |

### Isolation track (blocks S3–S5)

Detail + legacy drop: [fix/SHOP_SCOPE_TENANT_ISOLATION.md](../fix/SHOP_SCOPE_TENANT_ISOLATION.md).

| Phase | Scope | Status |
|-------|-------|--------|
| **T0** | Tenant session boundary: header source, slug guard, `tenantId` in query keys, tenant-scoped last-shop | done |
| **T1** | Additive tenant-scoped customer RPCs (`current_customer_group_id`, `list_customer_shops`, `list_customer_active_carts`, `list_customer_shop_orders`, `get_customer_shop_order`, `browse_shop_catalog_for_customer`) | done |
| **T2** | Lean customer DTOs; one orders call; no `select('*')`; drop currency-map fetches | done |
| **T3** | Orders page chrome (= S3) | done |
| **T4** | Drop the retired RPCs and dead frontend | done |

Staff TanStack cleanup remains [SHOP_ORDER_PHASES.md](SHOP_ORDER_PHASES.md) **P15** (order list/detail). It does not include this home.

---

## Code map

| Path | Role |
|------|------|
| `web/src/modules/dashboard/pages/CustomerDashboard.vue` | Shop home |
| `web/src/modules/dashboard/components/CustomerDashboard*.vue` | Home pieces (incl. `CustomerDashboardStatusStrip.vue`) |
| `web/src/modules/dashboard/utils/customerDashboardStatus.ts` | Waiting verbs + glance buckets |
| `web/src/modules/dashboard/routes/index.ts` | `customer-dashboard` |
| `web/src/layouts/ShopLayout.vue` | Shell + cart badge |
| `web/src/modules/navigation/useWorkspaceNavigation.ts` | Shop base link: Home; `shop_cart` omitted from sidebar |
| `web/src/modules/navigation/moduleRegistry.ts` | Catalog (`browse`) + Orders shop routes; Cart not a shop nav item |
| `web/src/modules/shop_order/pages/CatalogEntryPage.vue` | `/shop/browse` resolver → last/first shop or Home |
| `web/src/modules/shop_order/utils/catalogShop.ts` | Last-shop keys (**tenant-scoped**) + resolve/remember helpers |
| `web/src/modules/shop_order/components/StorefrontHeader.vue` | Catalog overline + shop switcher |
| `web/src/modules/shop_order/composables/useShopQuery.ts` | `useCustomerShopsQuery` |
| `web/src/modules/shop_order/composables/useCustomerOrdersQuery.ts` | Customer orders (one tenant-scoped call) |
| `web/src/boot/supabase.ts` | `x-selected-tenant-id`: shop scope reads the shop auth snapshot, never the app workspace key |
| `web/src/modules/auth/guards/validateShopTenantSlug.ts` | URL slug must equal the session tenant |
| `web/src/modules/shop_order/shared/queryKeys/shopOrderQueryKeys.ts` | Single key factory; customer keys carry `tenantId` |
