# BrandWala / TradeFlow BD — Master Plan

Platform for **parent company + sister-concern** multi-tenant operations across wholesale, retail, commerce, and (later) thrift. This document is the **single combined reference** for architecture, entities, phases, UI rules, **feature matrix**, **permissions**, **redesign model**, and **all module catalog**.

**Quick navigation:** §1–§13 architecture | **§14** feature matrix | **§15** global permissions | **§16** redesign schemas | **§17** modules (should/current/improve) | **§18** flows

---

## 1. Platform vision

One system manages:

- **Procurement** — child orders and product-based costing feed **parent shipments**
- **Stock** — parent-owned inventory with optional **child display allocations**
- **Sales** — parent or child invoices; commerce sells from **parent stock**
- **Accounting** — consolidated ledger at parent; operating tenant = sister concern
- **Capital** — investors, cost-share per shipment, parent cash-in-circulation

Business lines share the same **global entity model** (`global_stocks`, `global_invoices`, `global_accounting_ledger`). Thrift remains a separate vertical in phase 1.

---

## 2. Tech stack

| Layer | Choice |
|-------|--------|
| Frontend | Quasar (Vue 3) + Pinia |
| Mobile | Capacitor (Android); Thrift-app is a separate mobile client |
| Backend | Supabase (Postgres, RLS, RPCs) |
| Hosting | Cloudflare Pages |
| IDs | `bigint` (int) everywhere |

**Scopes:**

| Scope | Route | Users |
|-------|-------|-------|
| Platform | `/platform` | Superadmin |
| App | `/:tenantSlug/app` | Internal membership (admin, staff, viewer) |
| Shop | `/:tenantSlug/shop` | Customer group members |
| Investor | `/:tenantSlug/investor` | Investor accounts (`investor_portal` module) |

Redirect rules, route guards, and access-control layers: [doc/APP_SCOPES_AND_ACCESS.md](APP_SCOPES_AND_ACCESS.md).

---

## 3. Tenant model

### 3.1 Parent company vs sister concern (one layer)

| Role | `tenants.parent_id` | Responsibility |
|------|---------------------|----------------|
| **Parent company** | `NULL` | Shipments, stock, investors, consolidated accounting, cash dashboard |
| **Child (sister concern)** | `= parent.id` | Customer groups, orders, costing, commerce, own invoices |
| **Standalone** | `NULL`, no children | Same global tables; `parent_tenant_id := tenant_id` |

**Constraint:** Only one hierarchy level — a child cannot have children.

Tenant types, resolution, modules, and data ownership: [TENANT_MODEL_AND_ACCESS.md](TENANT_MODEL_AND_ACCESS.md).

### 3.2 Modules (feature flags)

Global capabilities are **separate module features** in the `modules` catalog — same pattern as `shipment`, `invoice`, `accounting`, `thrift_stock`, etc.

- Superadmin enables per tenant via **`tenant_modules`** (manual, no inheritance).
- Each global feature needs:
  1. **DB seeder** — idempotent `insert into public.modules ... on conflict (key) do update` migration
  2. **Frontend registry** — `MODULE_REGISTRY` in `web/src/modules/navigation/moduleRegistry.ts`
  3. **Permissions** — `modulePermissions.ts` role matrix
  4. **Routes** — guarded with `createAccessGuard({ requiredModule: '<key>' })`
  5. **Bootstrap** — `get_active_module_keys_for_tenant` returns key when `tenant_modules.is_active`

Legacy modules (`inventory`, `invoice`, `accounting`, `shipment`, `investor`) **remain** for existing tenants until cutover. Global modules are **additive keys** — not renames.

#### Global module catalog seeder (B1 migration)

Migration file: `supabase/migrations/YYYYMMDD_seed_global_modules.sql`

```sql
insert into public.modules (key, name, description, is_active)
values
  ('global_stock', 'Global Stock', 'Parent-owned stock with child allocation bridge across sister concerns.', true),
  ('global_invoice', 'Global Invoice', 'Unified invoice model for retail and wholesale; parent or child issuer.', true),
  ('global_accounting_ledger', 'Global Accounting Ledger', 'Parent consolidated ledger across all sister concerns.', true),
  ('global_shipment_accounting', 'Global Shipment Accounting', 'Shipment buy/sell cost and profit summary for parent company.', true),
  ('global_invoice_accounting', 'Global Invoice Accounting', 'Invoice rollup including COD, packing, print and other charges.', true),
  ('global_investor', 'Global Investor', 'Parent-managed investor profiles and balances.', true),
  ('global_investor_shipment', 'Global Investor Shipment', 'Investor cost-share and profit allocation per shipment.', true),
  ('investor_portal', 'Investor Portal', 'External investor login and portfolio summary.', true)
on conflict (key) do update
set name = excluded.name,
    description = excluded.description,
    is_active = excluded.is_active;
```

| `module_key` | Feature | Typical tenant |
|--------------|---------|----------------|
| `global_stock` | `global_stocks`, allocations | Parent (full), child (bridge) |
| `global_invoice` | `global_invoices`, parties, returns | Parent optional, child yes |
| `global_accounting_ledger` | `global_accounting_ledger` | Parent |
| `global_shipment_accounting` | `global_shipment_accounting` | Parent |
| `global_invoice_accounting` | `global_invoice_accounting`, charges | Parent |
| `global_investor` | `investors`, balances | Parent |
| `global_investor_shipment` | `shipment_investments` cost-share | Parent |
| `investor_portal` | `investor_accounts`, portfolio RPC | Parent (investor users) |

**Note:** `shipment`, `invoice`, `accounting` are existing legacy module keys for operational modules. Global keys gate the **new parent/child consolidated UI and RPCs**. A parent tenant may have both `shipment` + `global_shipment_accounting` enabled during transition.

#### Frontend registry (F1 / per-module frontend stage)

Each global key must be added to `ModuleKey` union and `MODULE_REGISTRY` with `routeSegment`, icon, and nav caption before its UI ships.

### 3.3 Membership & customer groups

| System | Scope | Change in phase 1 |
|--------|-------|-------------------|
| `memberships` | Internal users per tenant | **No schema change** — parent admin on parent tenant only |
| `customer_groups` | Child tenant only | Optional `parent_tenant_id`; child-only CHECK |
| `customer_group_members` | Shop auth | **No change** |

Parent consolidated access uses RPCs + `parent_tenant_id`, not cross-tenant membership rows.

---

## 4. End-to-end business flow

```
Child: orders / product costing  →  Parent: shipment (local or international)
  →  Parent: global_stocks  →  Parent: child_tenant_stock_allocations (optional)
  →  Child or parent: invoice  →  global_accounting_ledger
  →  Parent: cash circulation + investor profit share
```

**Commerce** does **not** create inbound shipments. It **sells from parent `global_stocks`** (same path as wholesale child invoice).

**Product based costing** stays **costing → parent shipment** (no mandatory order in between). Optional later: "Convert to order".

---

## 5. Shipment types

| Type | `shipment_type` | Currency | Cost input |
|------|-----------------|----------|------------|
| **Local** | `local` | BDT | Direct `cost_bdt` on lines |
| **International** | `international` | GBP | `price_gbp` + rates → computed `cost_bdt` |

Maps from legacy `is_gbp` (`false` → local, `true` → international). Costing formulas unchanged (`recalculate_shipment_transaction_rate`, etc.).

All stored costs in accounting use **BDT**.

---

## 6. Global entities (write target)

**Rule: global tables are the only write target.** No dual-write. Legacy `inventory_items`, `invoices`, `inventory_accounting_entries` are migrated (stock/ledger) or replaced (invoices **fresh insert**), then dropped.

### 6.1 `global_stocks`

Parent `tenant_id` only.

| Field | Notes |
|-------|-------|
| `id` | PK |
| `tenant_id` | Parent |
| `name`, `cost`, `shipment_id`, `image_url`, `product_code`, `barcode`, `product_id` | |
| `shipment_type` | `local` \| `international` |
| `source_module` | `wholesale` \| `retail` \| `commerce` |
| `source_type`, `source_id` | Legacy trace |

### 6.2 `global_stock_quantities`

| Field | Notes |
|-------|-------|
| `stock_id` | FK |
| `quantity` | >= 0 |
| `status` | `excellent`, `box_less`, `box_damage`, `expired`, `stolen`, `reserved` |

### 6.3 `child_tenant_stock_allocations` (Tenant Stock)

Virtual allocation layer — **not** duplicate physical stock. Sum of child allocations + parent unallocated pool reconciles to `global_stock_quantities`.

| Field | Notes |
|-------|-------|
| `parent_tenant_id`, `child_tenant_id`, `stock_id` | |
| `quantity`, `status` | Sum <= parent quantity per status |

**Stock network RPC:** `search_stock_network(context_tenant_id, mode)` — modes:
- `page` — list (parent: full pool; child: allocations only)
- `search` — header search (own tenant first, then network per product)
- `invoice` — cross-tenant pick when own allocation empty

**UI:** Global Stock (`/app/global/stock`), Tenant Stock (`/app/stock`), shared `NetworkStockSearchPanel`.

**Sidebar nav separation (do not violate):**

| Sidebar link | Module key | Route |
|---|---|---|
| **Global Stock** | `global_stock` | `/app/global/stock` |
| **Tenant Stock** | `inventory` | `/app/stock` |
| **Allocate Stock** | `global_stock` | `/app/global/stock/allocate` |

Each feature module is its own sidebar entry. Do **not** nest modules under a shared parent menu (no "Global" group). Domain groups (Invoices, Commerce, …) only group routes from the same module family.

### 6.4 `business_parties`

Ordered-by / recipient for invoices (child-owned).

### 6.5 `global_invoices` / `global_invoice_items` / `global_return_items`

Unified **Sales Invoices** desk model (module `global_invoice`). Shop order invoices remain on `commerce_invoices` until convergence (Step 9+).

| Field | Notes |
|-------|-------|
| `tenant_id` | Issuing sister concern (parent cannot self-issue via UI) |
| `parent_tenant_id` | Rollup parent |
| `billing_profile_id` | Required; wholesale/retail bill-to; dropship middle man |
| `invoice_type` | `wholesale` \| `retail` \| `dropship` |
| `recipient_name`, `recipient_phone`, `recipient_address` | Snapshots; wholesale = billing profile |
| `collection_source` | `billing_profile` (wholesale/retail) or `recipient` (dropship COD) |
| `face_subtotal_amount`, `accounting_subtotal_amount` | Dropship dual totals |
| `middle_man_payout_amount`, `middle_man_payout_status` | Dropship settlement |

**Type rules:**

| Type | Billing profile | Recipient | Charges | Collection |
|------|-----------------|-----------|---------|------------|
| Wholesale | Bill-to = recipient | Same as profile | None | Billing profile |
| Retail | Bill-to | Separate delivery party | COD, delivery, print, wrapping | Billing profile |
| Dropship | Middle man | End customer (required) | Same as retail | Recipient; payout to middle man |

Items reference parent `global_stock_id`. Line fields: `sell_price_amount` (accounting), `recipient_price_amount` (dropship face). Returns: `return_face_amount`, `return_accounting_amount`, optional `return_charge_amount`.

**UI:** Sales Invoices (`global/invoices`), shared print preview (`invoice_shared`), billing profiles (`global/invoices/billing-profiles`). Commerce shop invoices labeled **Shop Invoices**.

### 6.6 `invoice_charge_lines`

`cod`, `packing`, `print`, `delivery`, `other` — posts to ledger when `posted_to_ledger = true`.

### 6.7 `global_accounting_ledger`

| Field | Notes |
|-------|-------|
| `parent_tenant_id` | Parent filter |
| `tenant_id` | Operating sister concern |
| `entry_type` | `sale`, `return`, `charge`, `payment`, `adjustment` |
| amounts, `shipment_id`, `invoice_id`, `global_stock_id` | |
| `is_charge`, `charge_type` | |

### 6.8 Rollups

- `global_shipment_accounting` — buy/sell summary per shipment
- `global_invoice_accounting` — per-invoice rollup incl. charges
- `parent_cash_circulation` — investor capital, AR, stock cost, profit, payouts (RPC/view)

### 6.9 Investors

- `investors`, `investor_transactions`, `shipment_investments` — parent `tenant_id`
- `shipment_investments.cost_share_pct`, `allocated_cost`, `computed_profit`
- If sum(cost_share_pct) < 100%, **parent company bears remainder**
- `investor_accounts` + `get_investor_portfolio_summary` — backend in **B6**; UI in **F6** (this implementation)

---

## 7. Procurement into parent shipment

Sources for `add_child_line_to_parent_shipment`:

| Source | Child table |
|--------|-------------|
| `order_item` | `order_items` |
| `costing_item` | `product_based_costing_items` |

**Not** commerce — commerce is outbound from stock.

`shipment_items` metadata: `source_child_tenant_id`, `source_type`, `source_id`.

---

## 8. Locked decisions

| Topic | Decision |
|-------|----------|
| Write model | Global tables only; no dual-write |
| Commerce | Sell from parent stock; ledger `tenant_id` = child |
| Thrift | No phase 1 changes |
| Standalone tenant | `parent_tenant_id = tenant_id` |
| Investor remainder | Parent company |
| Invoices | Fresh insert on `global_invoices` |
| Costing → order | Not required; optional convert later |

---

## 9. Deprecation (post-migration)

**Drop:** `inventory_items`, `inventory_stocks`, `invoices`, `invoice_items`, `inventory_accounting_entries`, `shipment_inventory_accounting`, `v_shipment_accounting_ledger`, `shipments.is_gbp`.

**Keep:** `orders`, `shipments`, `shipment_items`, `product_based_costing_*`, `commerce_*`, `payments`, `customer_groups`, `investors`, `thrift_*`.

---

## 10. Implementation stages

### Backend stages

| Stage | Deliverables |
|-------|----------------|
| **B1 — Foundation** | One-layer `parent_id` constraint; `shipment_type`; helper functions; **`seed_global_modules.sql`**; sync `MODULE_REGISTRY` + `modulePermissions` stubs |
| **B2 — Stock** | `global_stocks`, `global_stock_quantities`, `child_tenant_stock_allocations`, `business_parties`; shipment receive → write global stock; RLS |
| **B3 — Procurement** | `shipment_items` source columns; `list_child_procurement_lines`; `add_child_line_to_parent_shipment`; `orders.parent_tenant_id` |
| **B4 — Invoice & charges** | `global_invoices`, items, returns, `invoice_charge_lines`; fresh-insert RPCs; retail/wholesale |
| **B5 — Accounting** | `global_accounting_ledger`, `global_shipment_accounting`, `global_invoice_accounting`; rewrite invoice/stock RPCs to global; one-time stock migration |
| **B6 — Capital** | `shipment_investments` extensions; `refresh_shipment_investor_profits`; `parent_cash_circulation`; `investor_accounts`; **`get_investor_portfolio_summary`** RPC; investor-scope auth bootstrap |
| **B7 — Cleanup** | Drop legacy inventory/invoice/ledger tables; regenerate `supabase.ts`; grants |

### Frontend stages

All new/updated pages **must** follow [doc/frontend style guilde.md](doc/frontend%20style%20guilde.md).

| Stage | Deliverables | UI reference |
|-------|----------------|--------------|
| **F1 — Shared UI** | Extract/reuse `floating-surface`, `hero-surface`, `pill-btn`, `soft-input`, status chips; align `AppPageHeader` with costing pattern | Style guide §1–16 |
| **F2 — Parent shipment** | Pull child procurement lines; build parent shipment (local/intl); costing file details pattern | `ProductBasedCostingFileDetailsPage` |
| **F3 — Global stock** | Parent full stock list; tenant stock page + allocation manager; `search_stock_network` RPC; shared network search UI | Inventory + costing list patterns |
| **F4 — Sales invoice** | Wholesale / retail / dropship create; billing profile; charges; shared print preview (`invoice_shared`) | Commerce invoice layout |
| **F5 — Parent accounting** | Consolidated ledger, shipment accounting, invoice accounting, cash circulation dashboard | Accounting pages + table column selector |
| **F6 — Investor (admin + portal)** | See **§10.1 Investor portal** below | Style guide + Thrift `AppPageHeader` |
| **F7 — Commerce retarget** | Commerce assign/sell `global_stock_id`; child sell flow | Existing commerce shop + style guide mobile cards §15–16 |

### 10.1 Investor portal frontend (in scope — this implementation)

Fourth app scope for external investors. Ships in **F6** after **B6**.

| Item | Detail |
|------|--------|
| **Module key** | `investor_portal` (seeded in B1) |
| **Route prefix** | `/:tenantSlug/investor` (parent company slug) |
| **Auth** | Google OAuth; resolve via `investor_accounts.email` — separate from `memberships` and `customer_group_members` |
| **Layout** | `InvestorLayout.vue` — minimal shell, theme scope `investor` or `app` variant |
| **Pages** | `InvestorLoginPage`, `InvestorPortfolioPage` (balances + active investments), `InvestorShipmentInvestmentsPage` (per-shipment cost-share + `computed_profit`) |
| **Module folder** | `web/src/modules/investor_portal/` — `pages/`, `routes/`, `repositories/`, `stores/`, `types/` |
| **Parent admin (same F6)** | Cost-share editor on shipment details (`global_investor_shipment` module) — existing `investor` module pages extended or new global shipment investment UI |
| **UI** | [doc/frontend style guilde.md](doc/frontend%20style%20guilde.md): `floating-surface`, `hero-surface`, `pill-btn`, minimal header (no page back button), mobile card layout §15 |
| **Borrow from Thrift** | `AppPageHeader`, `PageInitialLoader`, brand CSS tokens |

**Router:** register `investor` scope in `routes.ts` alongside `platform` / `app` / `shop`; guard checks `investor_portal` module + `investor_accounts` link.

**Bootstrap RPC:** `get_investor_bootstrap_context(p_tenant_id)` — returns investor profile, balances, module access (mirror shop bootstrap pattern).

### Thrift-app design borrowings (optional)

Use where they improve UX without breaking the style guide:

| Thrift pattern | Use in wholesale app |
|----------------|----------------------|
| `AppPageHeader` (title + action slot) | Global module list/detail pages |
| CSS tokens (`--bw-brand-*`, `--app-radius-*`, shadows) | Already aligned in Thrift; port tokens if missing in web |
| Mobile horizontal card row (§15 style guide) | Stock list on xs |
| `PageInitialLoader` | Heavy global RPC pages |
| Barcode scan overlay | Stock lookup (if mobile/Capacitor later) |

Do **not** copy Thrift composable architecture into web — web keeps module/repository/store pattern.

---

## 11. Module assignment guide

| Module | Parent | Child |
|--------|--------|-------|
| `shipment`, legacy `inventory` (Tenant Stock UI) | Yes | Yes (allocated view) |
| `global_stock` | Full pool | Search + invoice network pick |
| `order_management`, `product_based_costing` | No | Yes |
| `commerce_*` | No | Yes |
| `global_invoice` / `invoice` | Optional | Yes (desk sales) |
| `global_accounting_ledger`, `global_shipment_accounting` | Yes | No |
| `global_invoice_accounting` | Yes | Own invoices optional |
| `global_investor`, `global_investor_shipment` | Yes | No |
| `investor_portal` | — | Investors |

---

## 12. Related documentation

| Doc | Purpose |
|-----|---------|
| **§14–§18 below (this file)** | **Combined:** feature matrix, permissions, redesign entities, all module catalog |
| [doc/frontend style guilde.md](doc/frontend%20style%20guilde.md) | **Mandatory** UI pattern for all frontend work |
| [doc/APP_SCOPES_AND_ACCESS.md](APP_SCOPES_AND_ACCESS.md) | Application scopes, redirects, and access control |
| [doc/TENANT_MODEL_AND_ACCESS.md](TENANT_MODEL_AND_ACCESS.md) | Tenant types, hierarchy, resolution, modules, and data ownership |
| [LOGIN_NAV_PERMISSION_FLOW.md](../LOGIN_NAV_PERMISSION_FLOW.md) | Auth and permission implementation |
| [doc/accounting.md](doc/accounting.md) | Ledger math (unchanged formulas) |
| [doc/shipment.md](doc/shipment.md) | Shipment accounting metrics |
| [doc/investor.md](doc/investor.md) | Investor module notes |

---

## 13. Out of scope (later)

- Thrift parent/child global integration
- Multi-level tenant hierarchy
- Mandatory costing → order conversion
- `is_display_only = false` child sale bridge
- Merge `invoice_accounting_payments` with `payments`

---

## 14. High-Level Feature & Decision Matrix

> **How to read:** Scan §14 matrix first. Per-module detail in **§17** (should do / current / improve + schema + permissions). Redesign field lists in §16.

### 14.1 Module scan matrix

| # | Domain | Module | module_key | Status | Scope | Tenant | Purpose | Does NOT | Tables | Upstream | Downstream | Key decision | Redesign delta | Necessary fix | Priority |
|---|--------|--------|------------|--------|-------|--------|---------|----------|--------|----------|------------|--------------|----------------|---------------|----------|
| 1 | Platform & Access | Platform & Tenancy | — | STABLE | platform | Platform | Manage tenants, markets, superadmin membership | Does not run business operations | tenants, memberships, markets | — | all modules | One hierarchy level only | None | — | — |
| 2 | Platform & Access | Permission & Module System | modules / tenant_modules | STABLE | platform+all | All | Feature flags per tenant | Does not define role abilities (code matrix does) | modules, tenant_modules | platform | every guarded route | No inheritance on tenant_modules | None | Expand ModuleAction beyond view | P1 |
| 3 | Currency | Global Currency | thrift_currency → global_currency | REDESIGN | app | All (read) | Central multi-currency registry for UI and shipment rates | Does not store exchange rates history or auto-fetch FX | global_currencies | platform seed | global_shipments | Shared across tenants; is_active gates availability | Rename module key to global_currency | Platform CRUD for currencies | P0 |
| 4 | Catalog & Supply | Products | products | STABLE | app | Parent+Child | Product catalog master data | Does not track warehouse qty (stock modules do) | products, product_brands, product_categories, product_sync_snapshots | vendors, markets | orders, shipments, invoices | Tenant-scoped catalog | None | — | — |
| 5 | Catalog & Supply | Vendors | vendor | STABLE | app | Parent+Child | Supplier records for procurement | Does not manage shipments directly | vendors | — | products, global_shipments (target) | Linked to products via vendor_id | FK on global_shipments.vendor_id | Wire vendor to shipment redesign | P0 |
| 6 | Procurement Inputs | Order Management | order_management | STABLE | app+shop | Child | B2B purchase intent and negotiation before parent procures | No stock receive, shipment, invoice, or payment | orders, order_items | stores, carts | shipments via add_child_line | Optional negotiate flow with offer fields | None | Update FK when shipments renamed | P1 |
| 7 | Procurement Inputs | Costing File (Pre-order) | costing_file | STABLE | app+shop | Child | Internal/customer pre-order costing references | Not parent shipment; not product_based_costing batch | costing_files, costing_file_items, costing_file_viewers | products | shop visibility | Viewer grants per file | None | — | — |
| 8 | Procurement Inputs | Product Based Costing | product_based_costing | STABLE | app | Child | Batch costing that feeds parent shipment lines | Not mandatory order step; not commerce | product_based_costing_files, product_based_costing_items | products | shipment_items | costing → shipment without order | None | — | — |
| 9 | Procurement & Stock | Global Shipment | global_shipment | CURRENT→REDESIGN | app | Parent | Group purchases under customs/cargo batch; capture FX rates | No sales, child allocation, or ledger posting alone | shipments→global_shipments, shipment_items→global_shipment_items, shipment_orders | order_items, costing_items | global_stocks | Domestic forces rate 1.0 | Rename tables; currency FKs; calculated_landed_cost | Implement global_shipments schema | P0 |
| 10 | Procurement & Stock | Global Stock | global_stock | CURRENT→REDESIGN | app | Parent (+child read) | Parent-owned sellable inventory pools | Not duplicate physical stock per child | global_stocks, global_stock_quantities | shipment receive | invoices, commerce | Quantities split by status enum today | stock_type_id + is_usable ledger model | Align with global_stock_types | P0 |
| 11 | Procurement & Stock | Global Stock Type | global_stock_type | REDESIGN | app | Parent | Classify stock behaviour (sellable, damaged, quarantine) | Not a quantity ledger | global_stock_types (new) | — | global_stocks | is_sellable gates invoice pick | New table | Create config table + seed defaults | P0 |
| 12 | Procurement & Stock | Tenant Stock | inventory | STABLE | app | Child (+parent allocate) | Virtual child allocation slices of parent stock | Not separate physical inventory | child_tenant_stock_allocations | global_stocks | child invoice pick | Sum allocations ≤ parent qty | None | — | — |
| 13 | Profile & CRM | Billing Profile | billing_profile (in global_invoice) | STABLE | app | Child | Financial account: buyer, reseller, or dropship middle man | Not delivery address for dropship end customer | billing_profiles | customer_groups | global_invoices, payments | Required on desk invoices | Dedicated module key | Extract module key billing_profile | P1 |
| 14 | Profile & CRM | Recipient Profile | recipient_profile | REDESIGN | app | Child | Delivery endpoint separate from billing | Not the paying entity | recipient_profiles (new); business_parties (current) | — | global_invoices (dropship/retail) | Dropship collection from recipient | New table replaces inline snapshots | Create recipient_profiles + FK | P0 |
| 15 | Sales & Invoice | Sales Invoice (Desk) | global_invoice | CURRENT→REDESIGN | app | Child | Wholesale, retail, dropship desk sales with margin snapshot | Not commerce shop invoices | global_invoices, global_invoice_items, global_return_items, invoice_charge_lines | global_stocks, billing_profiles | payments, ledger | unit_cost_price snapshot at sale | Inline shipping_charge, cod_charge, courier_collected_amount; shipment_item_id on lines | Add redesign fields | P0 |
| 16 | Sales & Invoice | Shop Invoice (Commerce) | commerce_invoice | STABLE | app | Child | Invoices generated from commerce shop orders | Not desk global_invoice | commerce_invoices, commerce_invoice_boxes | commerce_orders | commerce_accounting, payments | Separate until convergence | None | — | — |
| 17 | Sales & Invoice | Legacy Invoice | invoice | LEGACY | app | Child | Deprecated invoice module key | Use global_invoice | (dropped legacy tables) | — | — | Redirects to global_invoice | Remove key post-cutover | Complete B7 cleanup | P1 |
| 18 | Ledger & Treasury | Global Payments | global_payments | CURRENT→REDESIGN | app | Child+Parent | Bulk cash-in with manual allocation to invoices | Not auto-matched bank feed | payments→global_payments, payment_allocations→invoice_payments | billing_profile or courier remittance | invoice balances | unallocated_amount floats until manual slice | Rename; reference_no; payer nullable for bulk remittance | Implement unallocated balance UX | P0 |
| 19 | Ledger & Treasury | Accounting (Legacy UI) | accounting | STABLE | app | Child | Tenant shipment/invoice accounting views and customer payments UI | Not parent consolidated ledger | uses global + legacy rollups | invoices, shipments | payments | Customer payments route here | None | — | — |
| 20 | Ledger & Treasury | Global Accounting Ledger | global_accounting_ledger | CURRENT | app | Parent | Consolidated ledger across sister concerns | Not commerce-isolated ledger | global_accounting_ledger | invoice posts, charges | reporting | parent_tenant_id filter | None | — | — |
| 21 | Ledger & Treasury | Shipment / Invoice Accounting | global_shipment_accounting, global_invoice_accounting | CURRENT | app | Parent | P&L rollups per shipment and invoice | Not line-level ledger | global_shipment_accounting, global_invoice_accounting | ledger refresh RPCs | dashboards | Refreshed via RPC not trigger | None | — | — |
| 22 | Shop & B2B | Store | store | STABLE | app+shop | Child | Storefront config and customer-group access | Not commerce shop (separate module) | stores, store_access, store_product_prices | customer_groups | carts, orders | Price visibility per group | None | — | — |
| 23 | Shop & B2B | Cart | cart | STABLE | shop | Child | B2B shop cart before order placement | Not commerce_cart | carts, cart_items | stores | orders | Separate from commerce cart | None | — | — |
| 24 | Commerce | Commerce Shop | commerce_shop | STABLE | app+shop | Child | Isolated commerce storefront, pricing, inventory summary | Does not create inbound shipments | commerce_inventory_product_summaries, store linkage | global_stocks (F7) | commerce_orders | Sells from parent stock | None | — | — |
| 25 | Commerce | Commerce Order | commerce_order | STABLE | app+shop | Child | Commerce order placement with charges | Not B2B negotiate orders | commerce_orders, commerce_order_items, commerce_order_settings | commerce_cart | commerce_invoices | COD/delivery charges on order | None | — | — |
| 26 | Commerce | Commerce Cart | commerce_cart | STABLE | shop | Child | Commerce-specific cart | Not B2B cart | commerce_cart | commerce shop | commerce_orders | Isolated from B2B cart | None | — | — |
| 27 | Commerce | Commerce Accounting | commerce_accounting | STABLE | app | Child | Commerce ledger and invoice/shipment accounting views | Not global parent ledger | commerce_accounting | commerce_invoices | reports | Dedicated commerce ledger | None | — | — |
| 28 | Capital | Investor (Legacy UI) | investor | STABLE | app | Parent | Legacy investor profile and transaction pages | Use global_investor for new work | investors, investor_transactions, shipment_investments | shipments | balances | Parent bears remainder if cost_share < 100% | None | — | — |
| 29 | Capital | Global Investor | global_investor | CURRENT | app | Parent | Parent-managed investor capital | Not investor portal login | investors, investor_balances | — | shipment_investments | Parent tenant only | None | — | — |
| 30 | Capital | Global Investor Shipment | global_investor_shipment | CURRENT | app | Parent | Cost-share and profit per shipment | Not treasury payments | shipment_investments | shipments, global_shipment_accounting | investor_balances | refresh_shipment_investor_profits RPC | None | — | — |
| 31 | Capital | Investor Portal | investor_portal | STABLE | investor | Investors | External investor portfolio login | Not internal membership | investor_accounts | investors | portfolio RPC | Separate auth from memberships | None | — | — |
| 32 | Verticals | Thrift | thrift_* (9 keys) | STABLE | app | Per tenant | Separate thrift warehouse vertical | Not integrated with global parent/child model | thrift_* (14 tables) | — | — | No phase 1 global integration | None | — | — |
| 33 | Verticals | Koba | koba_retail, koba_wholesale | STABLE | app+shop | Per tenant | Scraped catalog retail/wholesale orders | Not global stock path | koba_* (9 tables) | python sync | koba_orders | Isolated from wholesale global flow | None | — | — |
| 34 | Verticals | Tasks | tasks | STABLE | app | Per tenant | Internal project/task hierarchy | Not business operations data | items, tags, comments, item_permissions, activity_logs | — | — | item_permissions separate from tenant_modules | None | — | — |


### 14.2 Domain bundle summary

| Domain | Modules | Redesign scope | Parent/child rule |
|--------|---------|----------------|-------------------|
| Platform & Access | 01–02 | None | Platform superadmin |
| Currency | 03 | global_currency key + platform CRUD | All tenants read |
| Catalog & Supply | 04–05 | vendor FK on shipments | Both tenants |
| Procurement Inputs | 06–08 | None (STABLE) | Child only |
| Procurement & Stock | 09–12 | Shipments, stock, stock types | Parent owns; child allocates |
| Profile & CRM | 13–14 | recipient_profiles table | Child |
| Sales & Invoice | 15–17 | Desk invoice field additions | Child issues; parent reports |
| Ledger & Treasury | 18–21 | global_payments unallocated | Parent ledger; child payments |
| Shop & B2B | 22–23 | None | Child |
| Commerce | 24–27 | None (sells parent stock) | Child |
| Capital | 28–31 | None | Parent |
| Verticals | 32–34 | None (isolated) | Per tenant |

### 14.3 Decision log (locked)

| # | Topic | Decision |
|---|-------|----------|
| D1 | Write model | Global tables only; no dual-write |
| D2 | Commerce inbound | Commerce does **not** create shipments |
| D3 | Commerce outbound | Sells from parent `global_stocks` |
| D4 | Tenant hierarchy | One level only — child cannot have children |
| D5 | Standalone tenant | `parent_tenant_id := tenant_id` |
| D6 | Domestic shipment | `product_conversion_rate` and `cargo_conversion_rate` forced to 1.0 |
| D7 | Landed cost | Stored on shipment item; copied to invoice line as `unit_cost_price` at sale |
| D8 | Bulk payments | `global_payments` with manual `invoice_payments` allocation slices |
| D9 | Billing vs recipient | Separate profiles — essential for dropship |
| D10 | Investor remainder | Parent company bears cost share gap below 100% |
| D11 | Costing → order | Not required; optional convert later |
| D12 | Thrift | No phase 1 parent/child global integration |
| D13 | Module enablement | `tenant_modules` per tenant; no inheritance |
| D14 | Role abilities | Code matrix in `modulePermissions.ts`; today only `view` |

---

## 15. Permission schema & role matrix

### 15.1 Four-layer model

| Layer | Source | Controls |
|-------|--------|----------|
| 1 — Scope | Route prefix (`/platform`, `/app`, `/shop`, `/investor`) | Actor table (memberships / customer_group_members / investor_accounts) |
| 2 — Tenant modules | `tenant_modules` + `get_active_module_keys_for_tenant` | Feature on/off per tenant |
| 3 — Role matrix | `web/src/modules/navigation/modulePermissions.ts` | Role × `module_key` × `ModuleAction` |
| 4 — Row access | RLS + security-definer RPCs | Tenant/parent isolation |

### 15.2 Actor roles

| Scope | Roles | Auth table |
|-------|-------|------------|
| platform | superadmin | memberships (tenant_id null) |
| app | admin, staff, viewer | memberships |
| shop | customer_admin, customer_negotiator, customer_staff | customer_group_members |
| investor | investor_portal | investor_accounts |

### 15.3 Full role × module matrix (as implemented today)

Legend: **view** = access granted | **—** = no access


| module_key | superadmin | admin | staff | viewer | customer_admin | customer_negotiator | customer_staff | investor_portal |
|---|---|---|---|---|---|---|---|---|
| `order_management` | view | view | view | — | view | view | view | — |
| `shipment` | — | — | — | — | — | — | — | — |
| `inventory` | view | view | view | — | — | — | — | — |
| `commerce_shop` | — | view | view | — | view | view | view | — |
| `commerce_order` | — | view | view | — | view | view | view | — |
| `commerce_invoice` | — | view | view | — | — | — | — | — |
| `commerce_accounting` | view | view | — | — | — | — | — | — |
| `commerce_cart` | — | — | — | — | view | view | view | — |
| `investor` | view | view | view | — | — | — | — | — |
| `vendor` | view | view | view | — | — | — | — | — |
| `products` | view | view | view | — | — | — | — | — |
| `product_based_costing` | — | view | view | — | — | — | — | — |
| `costing_file` | view | view | view | view | view | view | view | — |
| `store` | — | view | — | — | view | view | view | — |
| `cart` | — | — | — | — | view | view | view | — |
| `accounting` | view | view | — | — | — | — | — | — |
| `invoice` | view | view | view | — | view | view | view | — |
| `koba_retail` | view | view | view | — | view | view | view | — |
| `koba_wholesale` | view | view | view | — | — | — | — | — |
| `tasks` | view | view | view | view | — | — | — | — |
| `thrift_stock` | view | view | view | — | — | — | — | — |
| `thrift_shipment` | view | view | view | — | — | — | — | — |
| `thrift_box` | view | view | view | — | — | — | — | — |
| `thrift_shelf` | view | view | view | — | — | — | — | — |
| `thrift_barcode` | view | view | view | — | — | — | — | — |
| `thrift_category` | view | view | view | — | — | — | — | — |
| `thrift_type` | view | view | view | — | — | — | — | — |
| `thrift_settings` | view | view | view | — | — | — | — | — |
| `thrift_currency` | view | view | view | — | — | — | — | — |
| `global_shipment` | view | view | view | — | — | — | — | — |
| `global_stock` | view | view | view | — | — | — | — | — |
| `global_invoice` | view | view | view | — | — | — | — | — |
| `global_accounting_ledger` | view | view | — | — | — | — | — | — |
| `global_shipment_accounting` | view | view | — | — | — | — | — | — |
| `global_invoice_accounting` | view | view | — | — | — | — | — | — |
| `global_investor` | view | view | — | — | — | — | — | — |
| `global_investor_shipment` | view | view | — | — | — | — | — | — |
| `investor_portal` | — | — | — | — | — | — | — | view |


### 15.4 Target actions (redesign — not yet in code)

`view` | `create` | `edit` | `delete` | `receive` | `allocate` | `sell` | `return` | `collect_payment` | `allocate_payment` | `configure`

### 15.5 Tenant assignment (all modules)

| module_key | Parent | Child | Standalone | Notes |
|------------|--------|-------|------------|-------|
| order_management, product_based_costing, costing_file | — | Yes | Yes | Procurement inputs |
| global_shipment, global_stock, global_stock_type | Yes | — | Yes | Parent owns stock |
| inventory (Tenant Stock) | Yes | Yes | Yes | Child allocation view |
| global_invoice, billing_profile, recipient_profile | Optional | Yes | Yes | Child issues desk sales |
| commerce_* | — | Yes | Yes | Child commerce |
| global_accounting_ledger, global_shipment_accounting | Yes | — | Yes | Parent consolidated |
| global_invoice_accounting | Yes | Optional | Yes | Own invoices rollup |
| global_investor, global_investor_shipment | Yes | — | Yes | Capital |
| investor_portal | — | — | — | External investors on parent slug |
| thrift_*, koba_*, tasks | Per tenant | Per tenant | Per tenant | Verticals |
| global_currency | Read all | Read all | Read all | Platform configures |

---

## 16. Redesign entity model

> **Current implementation** remains in §6. This section is the **target** schema from the backend/frontend redesign.

### 16.1 Global Currency — `global_currencies` [exists today]

| Field | Type | Notes |
|-------|------|-------|
| id | bigint PK | |
| name | text | e.g. US Dollar |
| country | text | Country of origin |
| code | text | ISO code e.g. USD, BDT |
| symbol | text | e.g. $, ৳ |
| is_active | boolean | Toggle across child tenants |

### 16.2 Global Shipment — `global_shipments` [target rename of shipments]

| Field | Type | Notes |
|-------|------|-------|
| id | bigint PK | |
| parent_tenant_id | bigint FK | Master tenant |
| vendor_id | bigint FK | Supplier |
| name | text | Batch identifier |
| shipment_purchase_currency_id | bigint FK | Currency goods bought in |
| shipment_cost_currency_id | bigint FK | Currency freight paid in |
| product_conversion_rate | numeric | 1.0 if domestic |
| cargo_conversion_rate | numeric | 1.0 if domestic |
| cargo_rate | numeric | Freight per weight unit |
| received_weight | numeric | Confirmed at warehouse |
| type | enum | domestic | international |

### 16.3 Global Shipment Items — `global_shipment_items`

| Field | Type | Notes |
|-------|------|-------|
| id | bigint PK | |
| shipment_id | bigint FK | |
| product_id | bigint FK | Catalog |
| name | text | Snapshot at purchase |
| ordered_quantity | int | |
| image_url | text | |
| add_method | enum | order | costing | manual |
| purchase_price | numeric | In purchase currency |
| product_weight | numeric | Dead weight per unit |
| package_weight | numeric | With packaging |
| calculated_landed_cost | numeric | **Final unit cost in local currency** |
| barcode | text | |
| product_code | text | SKU |

**Landed cost formula:**
- **Domestic:** `purchase_price` + weight-proportional cargo share (rates = 1.0)
- **International:** `(purchase_price × product_conversion_rate)` + `(product_weight / received_weight × cargo_rate × cargo_conversion_rate)`

### 16.4 Global Stock — `global_stocks` [target shape]

| Field | Type | Notes |
|-------|------|-------|
| id | bigint PK | |
| shipment_item_id | bigint FK | Trace to batch |
| quantity | int | Pool count |
| stock_type_id | bigint FK | Behaviour class |
| is_usable | boolean | Damaged vs ready |

### 16.5 Global Stock Type — `global_stock_types` [new]

| Field | Type | Notes |
|-------|------|-------|
| id | bigint PK | |
| is_sellable | boolean | Gates invoice/commerce pick |
| description | text | e.g. Standard Sellable, Damaged in Transit |

### 16.6 Billing Profile — `billing_profiles` [exists]

| Field | Type | Notes |
|-------|------|-------|
| id | bigint PK | |
| name | text | |
| phone | text | |
| email | text | |
| address | text | |
| customer_group_id | bigint FK | Pricing tier |
| tenant_id | bigint FK | |

### 16.7 Recipient Profile — `recipient_profiles` [new]

| Field | Type | Notes |
|-------|------|-------|
| id | bigint PK | |
| name | text | End consumer |
| address | text | Delivery address |
| phone | text | Driver coordination |

### 16.8 Global Invoice — `global_invoices` [target additions]

| Field | Type | Notes |
|-------|------|-------|
| id | bigint PK | |
| invoice_tenant_id | bigint FK | Issuing child tenant |
| invoice_code | text | e.g. INV-2026-001 |
| type | enum | wholesale | retail | dropship |
| billing_profile_id | bigint FK | |
| recipient_profile_id | bigint FK | |
| status | enum | unpaid | partially_paid | paid | cancelled |
| wrapping_charge | numeric | |
| shipping_charge | numeric | **New** |
| cod_charge | numeric | **New** |
| courier_collected_amount | numeric | **New** |
| discount_amount | numeric | |
| invoice_date | timestamptz | |

### 16.9 Invoice Item — `global_invoice_items` [target additions]

| Field | Type | Notes |
|-------|------|-------|
| id | bigint PK | |
| invoice_id | bigint FK | |
| shipment_item_id | bigint FK | Batch traceability |
| quantity | numeric | |
| return_quantity | numeric | |
| unit_sell_price | numeric | |
| unit_cost_price | numeric | **Snapshot of calculated_landed_cost** |
| line_discount | numeric | |
| notes | text | |

### 16.10 Global Payments — `global_payments` [target]

| Field | Type | Notes |
|-------|------|-------|
| id | bigint PK | |
| tenant_id | bigint FK | |
| payer_billing_profile_id | bigint FK nullable | Blank for bulk courier remittance |
| payment_method | enum | cash | bank_transfer | mfs | courier_remittance |
| reference_no | text | Bank txn / manifest code |
| total_amount_received | numeric | |
| unallocated_amount | numeric | **Floating balance** |

### 16.11 Invoice Payment — `invoice_payments` [target rename of payment_allocations]

| Field | Type | Notes |
|-------|------|-------|
| id | bigint PK | |
| invoice_id | bigint FK | |
| payment_id | bigint FK | |
| amount_allocated | numeric | |
| allocated_at | timestamptz | |

**Balance rule:** `unallocated_amount = total_amount_received − Σ amount_allocated`

### 16.12 Current vs target mapping

| Entity today | Target | Action |
|--------------|--------|--------|
| `shipments` | `global_shipments` | Rename + add currency/vendor FKs |
| `shipment_items` | `global_shipment_items` | Add landed cost, add_method |
| `global_stocks` + `global_stock_quantities` | Simplified `global_stocks` + `global_stock_types` | Redesign ledger |
| `business_parties` / inline recipient | `recipient_profiles` | New table |
| `invoice_charge_lines` | Inline on `global_invoices` | shipping/cod/courier fields |
| `payments` | `global_payments` | unallocated_amount |
| `payment_allocations` | `invoice_payments` | Rename + allocated_at |
| `orders`, `commerce_*`, `thrift_*`, `koba_*` | No change | STABLE |

---

## 17. Module reference

> **Per module:** Name → Submodule suggestion → Description (should do / current / improve) → Data schema → Permission control & data model.

### 1. Platform & Tenancy

**Domain:** Platform & Access  
**`module_key`:** `—`

#### Submodule suggestion
None — platform routes: Tenants, Markets, Superadmins, Module assignment (`/platform/*`).

#### Description
- **What it should do:** Create and manage tenants (parent/child/standalone), markets, and superadmin memberships. Enforce one-level hierarchy.
- **Current set:** Tables `tenants`, `memberships`, `markets`. Routes `/platform/tenants`, `/platform/markets`, `/platform/modules`. RPCs `create_tenant_for_superadmin`, `list_tenants_for_superadmin`.
- **Improvement needed:** None required — stable foundation.

#### Data schema
| Table | Fields |
|-------|--------|
| `tenants` | `id`, `name`, `slug`, `parent_id`, `public_domain`, `is_active` |
| `memberships` | `id`, `email`, `tenant_id`, `role`, `is_active` |
| `markets` | `id`, `code`, `name`, `is_active` |

#### Permission control & data model
- **Tenant assignment:** Platform only (superadmin)
- **RLS / data model:** Superadmin membership (`tenant_id` null). Tenant reads via `user_can_access_tenant_fetch`.

Platform / catalog — no single `module_key`. Superadmin manages via `/platform/*`.

---

### 2. Permission & Module System

**Domain:** Platform & Access  
**`module_key`:** `modules / tenant_modules`

#### Submodule suggestion
None today. Optional future: `parent_module_key` on `modules` for nav bundling.

#### Description
- **What it should do:** Define global feature catalog and per-tenant enablement. Bootstrap returns active keys for navigation.
- **Current set:** `modules` + `tenant_modules`. RPC `get_active_module_keys_for_tenant`. No inheritance between parent/child tenants.
- **Improvement needed:** Expand `ModuleAction` beyond `view`. Consider submodule rows in catalog.

#### Data schema
| Table | Fields |
|-------|--------|
| `modules` | `id`, `key`, `name`, `description`, `is_active` |
| `tenant_modules` | `id`, `tenant_id`, `module_key`, `is_active` |

#### Permission control & data model
- **Tenant assignment:** All tenants (flags); platform manages catalog
- **RLS / data model:** Superadmin writes catalog; bootstrap RPC reads tenant flags.

Platform / catalog — no single `module_key`. Superadmin manages via `/platform/*`.

---

### 3. Global Currency

**Domain:** Currency  
**`module_key`:** `thrift_currency → global_currency`

#### Submodule suggestion
Single submodule: **Currency catalog** (list/manage).

#### Description
- **What it should do:** Central currency registry (name, country, code, symbol, is_active) for shipments and UI.
- **Current set:** Table `global_currencies` exists. Module key `thrift_currency` — read-only route `/thrift/currencies`.
- **Improvement needed:** **P0:** Add `global_currency` module key and platform CRUD. Wire FKs on redesigned shipments.

#### Data schema
| Table | Fields |
|-------|--------|
| `global_currencies` | `id`, `name`, `country`, `code`, `symbol`, `is_active` |

#### Permission control & data model
- **Tenant assignment:** All tenants read; platform configures
- **RLS / data model:** Authenticated read; platform write (target).

**`thrift_currency`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

---

### 4. Products

**Domain:** Catalog & Supply  
**`module_key`:** `products`

#### Submodule suggestion
**Products**, **Brands**, **Categories** (same key, separate routes).

#### Description
- **What it should do:** Tenant product catalog feeding orders, shipments, and invoices.
- **Current set:** `products`, `product_brands`, `product_categories`, `product_sync_snapshots`. Routes `/app/products/*`.
- **Improvement needed:** None — stable.

#### Data schema
| Table | Key fields |
|-------|------------|
| `products` | `tenant_id`, `name`, `product_code`, `barcode`, `price_gbp`, weights, `vendor_id` |
| `product_brands` | `tenant_id`, `name` |
| `product_categories` | `tenant_id`, `name` |

#### Permission control & data model
- **Tenant assignment:** Parent + child
- **RLS / data model:** `can_manage_products` / customer read RPCs.

**`products`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

---

### 5. Vendors

**Domain:** Catalog & Supply  
**`module_key`:** `vendor`

#### Submodule suggestion
None.

#### Description
- **What it should do:** Supplier master linked to products and global shipments.
- **Current set:** Table `vendors`. Route `/app/vendors`.
- **Improvement needed:** **P0:** Required on `global_shipments.vendor_id`.

#### Data schema
| Table | Key fields |
|-------|------------|
| `vendors` | `tenant_id`, `name`, `code`, contact fields |

#### Permission control & data model
- **Tenant assignment:** Parent + child
- **RLS / data model:** Tenant-scoped internal roles.

**`vendor`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

---

### 6. Order Management

**Domain:** Procurement Inputs  
**`module_key`:** `order_management`

#### Submodule suggestion
**Orders**, **Order items**, **Negotiation** (when `negotiate=true`).

#### Description
- **What it should do:** B2B purchase intent and optional negotiation; feed parent shipment procurement.
- **Current set:** `orders`, `order_items`. App + shop `/orders`. Offer fields, `parent_tenant_id`, `shipment_id` on lines.
- **Improvement needed:** **P1:** Update FK when shipments renamed. Optional parent order dashboard.

#### Data schema
| Table | Key fields |
|-------|------------|
| `orders` | `tenant_id`, `customer_group_id`, `store_id`, `status`, `negotiate`, `parent_tenant_id`, rates |
| `order_items` | quantities, offers, `price_gbp`, `cost_bdt`, `shipment_id` |

#### Permission control & data model
- **Tenant assignment:** Child (primary)
- **RLS / data model:** Tenant + customer_group on shop.

**`order_management`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | view |
| customer_negotiator | view |
| customer_staff | view |
| investor_portal | — |

---

### 7. Costing File (Pre-order)

**Domain:** Procurement Inputs  
**`module_key`:** `costing_file`

#### Submodule suggestion
**Files**, **Items**, **Viewers**.

#### Description
- **What it should do:** Pre-order costing worksheets with optional customer visibility.
- **Current set:** `costing_files`, `costing_file_items`, `costing_file_viewers`. Route `/costing`.
- **Improvement needed:** None — stable.

#### Data schema
| Table | Key fields |
|-------|------------|
| `costing_files` | header, status, pricing |
| `costing_file_items` | lines |
| `costing_file_viewers` | customer grants |

#### Permission control & data model
- **Tenant assignment:** Child
- **RLS / data model:** Admin manage; viewer grants for shop.

**`costing_file`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | view |
| customer_admin | view |
| customer_negotiator | view |
| customer_staff | view |
| investor_portal | — |

---

### 8. Product Based Costing

**Domain:** Procurement Inputs  
**`module_key`:** `product_based_costing`

#### Submodule suggestion
**Batch file**, **Batch items**.

#### Description
- **What it should do:** Child costing batches → parent shipment lines (no mandatory order).
- **Current set:** `product_based_costing_files`, `product_based_costing_items`. Route `/product-based-costing`.
- **Improvement needed:** None — stable.

#### Data schema
| Table | Key fields |
|-------|------------|
| `product_based_costing_files` | batch metadata |
| `product_based_costing_items` | product lines |

#### Permission control & data model
- **Tenant assignment:** Child
- **RLS / data model:** Tenant admin/staff.

**`product_based_costing`**

| Role | Access (today) |
|------|----------------|
| superadmin | — |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

---

### 9. Procurement & Stock

**Domain:** Procurement & Stock  
**`module_key`:** `global_shipment, global_stock, inventory`

#### Submodule suggestion
**Global Shipment** + items | **Global Stock** + quantities | **Stock type** (target) | **Tenant Stock** (allocations).

#### Description
- **What it should do:** Parent receive shipments, compute landed cost, stock pools; child view allocations; stock types gate sales.
- **Current set:** `shipments`, `shipment_items`, `global_stocks`, `global_stock_quantities`, `child_tenant_stock_allocations`. Keys: `global_shipment`, `global_stock`, `inventory`.
- **Improvement needed:** **P0:** `global_shipments`/`global_shipment_items`, `calculated_landed_cost`, currency FKs, `global_stock_types`. **P1:** Retire `shipment` key.

#### Data schema
**Current:** `shipments`, `shipment_items`, `global_stocks`, `global_stock_quantities`, `child_tenant_stock_allocations`

**Target:** see §16.2–16.5

#### Permission control & data model
- **Tenant assignment:** Parent owns; child gets allocation view
- **RLS / data model:** Parent tenant on shipment/stock; `search_stock_network` for cross-tenant pick.

**`global_shipment`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

**`global_stock`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

**`inventory`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

---

### 10. Profile & CRM

**Domain:** Profile & CRM  
**`module_key`:** `billing_profile, recipient_profile`

#### Submodule suggestion
**Billing profile** | **Recipient profile** (target dedicated table).

#### Description
- **What it should do:** Separate financial account from delivery endpoint (dropship/retail).
- **Current set:** `billing_profiles` stable. Recipient via invoice snapshots + `business_parties`.
- **Improvement needed:** **P0:** `recipient_profiles` table. **P1:** `billing_profile` module key.

#### Data schema
| Table | Key fields |
|-------|------------|
| `billing_profiles` | `tenant_id`, `name`, `phone`, `email`, `address`, `customer_group_id` |
| `recipient_profiles` *(target)* | `name`, `address`, `phone` |

#### Permission control & data model
- **Tenant assignment:** Child
- **RLS / data model:** Tenant-scoped profiles.

**`global_invoice`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

Billing UI today under `global_invoice` routes.

---

### 11. Sales & Invoice

**Domain:** Sales & Invoice  
**`module_key`:** `global_invoice, commerce_invoice`

#### Submodule suggestion
**Desk invoices** (wholesale/retail/dropship) | **Shop invoices** | **Items** | **Returns** | **Charges**.

#### Description
- **What it should do:** Sell from stock with immutable cost snapshot; COD/shipping charges; commerce order invoices separate.
- **Current set:** `global_invoices`, items, returns, `invoice_charge_lines`. `commerce_invoices`. Legacy `invoice` key.
- **Improvement needed:** **P0:** `unit_cost_price`, inline charges, `shipment_item_id`. **P1:** Remove `invoice` key.

#### Data schema
**Desk:** `global_invoices`, `global_invoice_items`, `global_return_items`, `invoice_charge_lines`
**Commerce:** `commerce_invoices`
**Target:** §16.8–16.9

#### Permission control & data model
- **Tenant assignment:** Child issues; parent rollup
- **RLS / data model:** Issuer `tenant_id`; parent via `parent_tenant_id`.

**`global_invoice`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

**`commerce_invoice`**

| Role | Access (today) |
|------|----------------|
| superadmin | — |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

---

### 12. Ledger & Treasury

**Domain:** Ledger & Treasury  
**`module_key`:** `accounting, global_accounting_ledger, global_payments`

#### Submodule suggestion
**Payments** | **Allocations** | **Customer payments UI** | **Global ledger** | **Rollups**.

#### Description
- **What it should do:** Bulk payments with unallocated balance; manual invoice allocation; parent consolidated ledger.
- **Current set:** `payments`, `payment_allocations`, `global_accounting_ledger`, rollups. Module `accounting`.
- **Improvement needed:** **P0:** `global_payments` / `invoice_payments` with `unallocated_amount`.

#### Data schema
**Current:** `payments`, `payment_allocations`, `global_accounting_ledger`, `global_shipment_accounting`, `global_invoice_accounting`
**Target:** §16.10–16.11

#### Permission control & data model
- **Tenant assignment:** Child payments; parent ledger
- **RLS / data model:** Tenant payments; parent filter on ledger.

**`accounting`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | — |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

**`global_accounting_ledger`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | — |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

**`global_shipment_accounting`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | — |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

**`global_invoice_accounting`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | — |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

---

### 13. Shop & B2B

**Domain:** Shop & B2B  
**`module_key`:** `store, cart`

#### Submodule suggestion
**Stores** | **Store access** | **Pricing** | **Cart**.

#### Description
- **What it should do:** B2B storefront per customer group; cart → order flow.
- **Current set:** `stores`, `store_access`, `store_product_prices`, `carts`, `cart_items`.
- **Improvement needed:** None — stable.

#### Data schema
| Table | Key fields |
|-------|------------|
| `stores` | `tenant_id`, `name` |
| `store_access` | group ↔ store |
| `carts` / `cart_items` | shop carts |

#### Permission control & data model
- **Tenant assignment:** Child
- **RLS / data model:** Customer group store access RPCs.

**`store`**

| Role | Access (today) |
|------|----------------|
| superadmin | — |
| admin | view |
| staff | — |
| viewer | — |
| customer_admin | view |
| customer_negotiator | view |
| customer_staff | view |
| investor_portal | — |

**`cart`**

| Role | Access (today) |
|------|----------------|
| superadmin | — |
| admin | — |
| staff | — |
| viewer | — |
| customer_admin | view |
| customer_negotiator | view |
| customer_staff | view |
| investor_portal | — |

---

### 14. Commerce

**Domain:** Commerce  
**`module_key`:** `commerce_shop, commerce_order, commerce_cart, commerce_accounting`

#### Submodule suggestion
**Shop** | **Cart** | **Orders** | **Invoices** | **Accounting** (five keys).

#### Description
- **What it should do:** Isolated commerce flow selling parent global stock; no inbound shipments.
- **Current set:** `commerce_*` tables. Five module keys. F7 global stock integration.
- **Improvement needed:** None — stable.

#### Data schema
| Table | Key fields |
|-------|------------|
| `commerce_orders` | COD, delivery, recipient fields |
| `commerce_invoices` | from orders |
| `commerce_accounting` | ledger |

#### Permission control & data model
- **Tenant assignment:** Child only
- **RLS / data model:** Tenant + customer group.

**`commerce_shop`**

| Role | Access (today) |
|------|----------------|
| superadmin | — |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | view |
| customer_negotiator | view |
| customer_staff | view |
| investor_portal | — |

**`commerce_order`**

| Role | Access (today) |
|------|----------------|
| superadmin | — |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | view |
| customer_negotiator | view |
| customer_staff | view |
| investor_portal | — |

**`commerce_cart`**

| Role | Access (today) |
|------|----------------|
| superadmin | — |
| admin | — |
| staff | — |
| viewer | — |
| customer_admin | view |
| customer_negotiator | view |
| customer_staff | view |
| investor_portal | — |

**`commerce_accounting`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | — |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

**`commerce_invoice`**

| Role | Access (today) |
|------|----------------|
| superadmin | — |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

---

### 15. Capital & Investors

**Domain:** Capital  
**`module_key`:** `investor, global_investor, global_investor_shipment, investor_portal`

#### Submodule suggestion
**Profiles** | **Transactions** | **Shipment investments** | **Portal**.

#### Description
- **What it should do:** Parent investor capital, cost-share per shipment, external portfolio login.
- **Current set:** `investors`, `shipment_investments`, `investor_accounts`. Legacy + global UI keys.
- **Improvement needed:** None — stable.

#### Data schema
| Table | Key fields |
|-------|------------|
| `investors` | parent tenant |
| `shipment_investments` | cost_share, profit |
| `investor_accounts` | portal email |

#### Permission control & data model
- **Tenant assignment:** Parent admin; external investors
- **RLS / data model:** Parent tenant; portal via `investor_accounts`.

**`investor`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

**`global_investor`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | — |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

**`global_investor_shipment`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | — |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

**`investor_portal`**

| Role | Access (today) |
|------|----------------|
| superadmin | — |
| admin | — |
| staff | — |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | view |

---

### 16. Thrift

**Domain:** Verticals  
**`module_key`:** `thrift_* (9 keys)`

#### Submodule suggestion
stock, shipment, box, shelf, barcode, category, type, settings, currency.

#### Description
- **What it should do:** Standalone thrift vertical — not global parent/child integration (phase 1).
- **Current set:** 14 `thrift_*` tables. Routes `/app/thrift/*`.
- **Improvement needed:** None per locked decision D12.

#### Data schema
`thrift_stocks`, `thrift_shipments`, `thrift_boxes`, `thrift_invoices`, etc.

#### Permission control & data model
- **Tenant assignment:** Per tenant
- **RLS / data model:** Tenant-scoped.

**`thrift_stock`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

**`thrift_shipment`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

**`thrift_box`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

**`thrift_shelf`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

**`thrift_barcode`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

**`thrift_category`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

**`thrift_type`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

**`thrift_settings`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

**`thrift_currency`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

---

### 17. Koba

**Domain:** Verticals  
**`module_key`:** `koba_retail, koba_wholesale`

#### Submodule suggestion
**Retail** (full flow) | **Wholesale** (catalog).

#### Description
- **What it should do:** Scraped catalog orders — isolated from global stock.
- **Current set:** `koba_*` tables. Python sync. Routes `/koba/*`.
- **Improvement needed:** None — stable.

#### Data schema
`koba_products`, `koba_orders`, `koba_carts`, `koba_retail_settings`

#### Permission control & data model
- **Tenant assignment:** Per tenant
- **RLS / data model:** Tenant-scoped koba RPCs.

**`koba_retail`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | view |
| customer_negotiator | view |
| customer_staff | view |
| investor_portal | — |

**`koba_wholesale`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | — |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

---

### 18. Tasks

**Domain:** Verticals  
**`module_key`:** `tasks`

#### Submodule suggestion
project → module → submodule → task/note/discussion hierarchy.

#### Description
- **What it should do:** Internal PM with `item_permissions` separate from business modules.
- **Current set:** `items`, `tags`, `comments`, `item_permissions`, `activity_logs`.
- **Improvement needed:** None — stable.

#### Data schema
| Table | Key fields |
|-------|------------|
| `items` | hierarchical type, parent_id |
| `item_permissions` | per-user ACL |

#### Permission control & data model
- **Tenant assignment:** Per tenant
- **RLS / data model:** `get_effective_item_role`.

**`tasks`**

| Role | Access (today) |
|------|----------------|
| superadmin | view |
| admin | view |
| staff | view |
| viewer | view |
| customer_admin | — |
| customer_negotiator | — |
| customer_staff | — |
| investor_portal | — |

---


## 18. End-to-end flows

```
Child: orders / product costing → Parent: shipment (local or international)
  → Parent: global_stocks → child_tenant_stock_allocations (optional)
  → Child: global_invoice → global_payments / invoice_payments
  → Parent: global_accounting_ledger + investor profit share
```

| Flow | Path | Status |
|------|------|--------|
| B2B order | cart → order → negotiate → shipment pull | STABLE |
| Costing | product_based_costing → shipment line | STABLE |
| Receive stock | shipment receive RPC → global_stocks | CURRENT |
| Desk sale | global_stock → global_invoice → payment allocation | CURRENT→REDESIGN |
| Commerce | commerce_cart → order → invoice → commerce_accounting | STABLE |
| Thrift | thrift_shipment → stock → invoice | STABLE (isolated) |

---

## 19. Updated related documentation

| Doc | Purpose |
|-----|---------|
| **This file (MASTER_PLAN.md)** | **Single combined reference:** vision, matrix, permissions, redesign, all modules |
| [doc/frontend style guilde.md](doc/frontend%20style%20guilde.md) | Mandatory UI patterns |
| [doc/APP_SCOPES_AND_ACCESS.md](APP_SCOPES_AND_ACCESS.md) | Application scopes, redirects, and access control |
| [doc/TENANT_MODEL_AND_ACCESS.md](TENANT_MODEL_AND_ACCESS.md) | Tenant types, hierarchy, resolution, modules, and data ownership |
| [LOGIN_NAV_PERMISSION_FLOW.md](../LOGIN_NAV_PERMISSION_FLOW.md) | Auth bootstrap implementation |
