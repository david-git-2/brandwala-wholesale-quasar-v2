# BrandWala / TradeFlow BD — Master Plan

Platform for **parent company + sister-concern** multi-tenant operations across wholesale, retail, commerce, and (later) thrift. This document is the source of truth for architecture, entities, phases, and UI rules.

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

---

## 3. Tenant model

### 3.1 Parent company vs sister concern (one layer)

| Role | `tenants.parent_id` | Responsibility |
|------|---------------------|----------------|
| **Parent company** | `NULL` | Shipments, stock, investors, consolidated accounting, cash dashboard |
| **Child (sister concern)** | `= parent.id` | Customer groups, orders, costing, commerce, own invoices |
| **Standalone** | `NULL`, no children | Same global tables; `parent_tenant_id := tenant_id` |

**Constraint:** Only one hierarchy level — a child cannot have children.

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
| [doc/frontend style guilde.md](doc/frontend%20style%20guilde.md) | **Mandatory** UI pattern for all frontend work |
| [doc/core-app-feature-documentation.md](doc/core-app-feature-documentation.md) | Scopes, membership, customer groups |
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
