# BrandWala / TradeFlow BD — Master Plan

Platform for **parent company + sister-concern** multi-tenant operations across wholesale, retail, commerce, and (later) thrift.

**This document is the index and cross-cutting reference** — vision, locked decisions, implementation phases, feature matrix, permissions, and module catalog. **Domain detail** (schemas, routes, RPCs, UI) lives in linked domain docs; read those when implementing a specific area.

**Quick navigation:** §1–§5 vision & flow | §6–§7 entity summary | §8–§11 decisions & phases | **§12** doc map | **§14** feature matrix | **§15** permissions | **§16** schema index | **§17** module index | **§18** flows

---

## 1. Platform vision

One system manages:

- **Procurement** — child orders and product-based costing feed **parent shipments** → [PROCUREMENT_STOCK.md](PROCUREMENT_STOCK.md)
- **Stock** — parent-owned inventory with optional **child display allocations** → [PROCUREMENT_STOCK.md](PROCUREMENT_STOCK.md)
- **Sales** — parent or child invoices; commerce sells from **parent stock** → [SALES_INVOICE.md](SALES_INVOICE.md)
- **Reports & treasury** — margin reports and payment settlement (read-side P&L) → [REPORTING_TREASURY.md](REPORTING_TREASURY.md)
- **Capital** — investors, cost-share per shipment, investor portal → [INVESTOR_CAPITAL.md](INVESTOR_CAPITAL.md)

Business lines share the same **global entity model** (`global_stocks`, `global_invoices`, …). Thrift remains a separate vertical in phase 1.

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
| Investor | `/:tenantSlug/investor` | Investor (`investor_portal` module) |

Full scope rules, guards, and redirects: [APP_SCOPES_AND_ACCESS.md](APP_SCOPES_AND_ACCESS.md).

---

## 3. Tenant model (summary)

| Role | `tenants.parent_id` | Responsibility |
|------|---------------------|----------------|
| **Parent company** | `NULL` | Shipments, stock, investors, consolidated reports, cash dashboard |
| **Child (sister concern)** | `= parent.id` | Customer groups, orders, costing, commerce, own invoices |
| **Standalone** | `NULL`, no children | Same global tables; `parent_tenant_id := tenant_id` |

**Constraint:** Only one hierarchy level — a child cannot have children.

**Modules (feature flags):** Superadmin enables per tenant via `tenant_modules` (no inheritance). Each feature needs: DB seeder, `MODULE_REGISTRY`, `modulePermissions.ts`, guarded routes, bootstrap inclusion.

Legacy modules (`inventory`, `invoice`, `accounting`, `shipment`, `investor`) **remain** for existing tenants until cutover. New parent-module families (`procurement_stock`, `sales_invoice`, `reporting_treasury`, `investor_capital`, `global_reference`) are **additive keys**.

**Full detail:** [TENANT_MODEL_AND_ACCESS.md](TENANT_MODEL_AND_ACCESS.md) — resolution, membership, investor actors, module assignment, RLS.

---

## 4. End-to-end business flow

```
Child: orders / product costing  →  Parent: shipment (local or international)
  →  Parent: global_stocks  →  child_tenant_stock_allocations (optional)
  →  Child: global_invoice  →  payments / invoice_payments
  →  reporting_treasury: margin reports (read)  →  investor profit share
```

**Commerce** does **not** create inbound shipments. It **sells from parent `global_stocks`**.

**Product based costing** stays **costing → parent shipment** (no mandatory order in between).

---

## 5. Shipment types

| Type | `shipment_type` | Currency | Cost input |
|------|-----------------|----------|------------|
| **Local** | `local` | BDT | Direct `cost_bdt` on lines |
| **International** | `international` | GBP | `price_gbp` + rates → computed `cost_bdt` |

All stored costs in accounting use **BDT**. Landed-cost formulas: [PROCUREMENT_STOCK.md](PROCUREMENT_STOCK.md).

---

## 6. Global entities (summary)

**Rule: global tables are the only write target for operational data.** No dual-write. Legacy tables are migrated then dropped (§9).

| Entity family | Primary tables | Detail document |
|---------------|----------------|-----------------|
| Stock & allocations | `global_stocks`, `global_stock_quantities`, `child_tenant_stock_allocations` | [PROCUREMENT_STOCK.md](PROCUREMENT_STOCK.md) |
| Shipments | `global_shipments`, `global_shipment_items` | [PROCUREMENT_STOCK.md](PROCUREMENT_STOCK.md) |
| Invoices | `global_invoices`, `global_invoice_items`, `global_return_items`, `invoice_charge_lines` | [SALES_INVOICE.md](SALES_INVOICE.md) |
| Profiles | `billing_profiles`, `recipient_profiles` | [SALES_INVOICE.md](SALES_INVOICE.md) |
| Payments | `global_payments`, `invoice_payments` | [REPORTING_TREASURY.md](REPORTING_TREASURY.md) |
| Margin reports | Read-side from invoice lines + shipment batches | [REPORTING_TREASURY.md](REPORTING_TREASURY.md) |
| Investors | `investors`, `investor_transactions`, `shipment_investments` | [INVESTOR_CAPITAL.md](INVESTOR_CAPITAL.md) |
| Reference data | `global_currencies`, `markets`, `payment_methods`, `units_of_measure` | [GLOBAL_REFERENCE_DATA.md](GLOBAL_REFERENCE_DATA.md) |

**Target direction:** Retire `global_accounting_ledger` writes in favour of read-side margin ([REPORTING_TREASURY.md](REPORTING_TREASURY.md) §1). Legacy rollups (`global_shipment_accounting`, `global_invoice_accounting`) are replaced by report queries during transition.

**Stock network RPC:** `search_stock_network(context_tenant_id, mode)` — modes: `page`, `search`, `invoice`.

---

## 7. Procurement into parent shipment

Sources for `add_child_line_to_parent_shipment`: `order_items`, `product_based_costing_items`. **Not** commerce.

**Full detail:** [PROCUREMENT_STOCK.md](PROCUREMENT_STOCK.md) §procurement lines.

---

## 8. Locked decisions

| Topic | Decision |
|-------|----------|
| Write model | Global tables only; no dual-write (D1) |
| Commerce | Sell from parent stock; operating `tenant_id` = child (D2–D3) |
| Thrift | No phase 1 global integration (D12) |
| Standalone tenant | `parent_tenant_id = tenant_id` (D5) |
| Investor remainder | Parent company bears cost-share gap below 100% (D10) |
| Invoices | Fresh insert on `global_invoices` |
| Cost at sale | `unit_cost_price` immutable snapshot from landed cost (D7) |
| Costing → order | Not required; optional convert later (D11) |
| Module enablement | `tenant_modules` per tenant; no inheritance (D13) |
| Margin / P&L | Computed on read — no shadow ledger (see REPORTING_TREASURY) |

Full decision log: §14.3.

---

## 9. Deprecation (post-migration)

**Drop:** `inventory_items`, `inventory_stocks`, `invoices`, `invoice_items`, `inventory_accounting_entries`, `shipment_inventory_accounting`, `v_shipment_accounting_ledger`, `shipments.is_gbp`.

**Keep:** `orders`, `shipments`, `shipment_items`, `product_based_costing_*`, `commerce_*`, `payments`, `customer_groups`, `investors`, `thrift_*`.

---

## 10. Implementation stages

### Backend stages

| Stage | Deliverables | Domain doc |
|-------|--------------|------------|
| **B1 — Foundation** | Hierarchy constraint; `seed_global_modules.sql`; registry + permissions stubs | [TENANT_MODEL_AND_ACCESS.md](TENANT_MODEL_AND_ACCESS.md) |
| **B2 — Stock** | `global_stocks`, quantities, allocations; receive → stock; RLS | [PROCUREMENT_STOCK.md](PROCUREMENT_STOCK.md) |
| **B3 — Procurement** | Child line pull; `add_child_line_to_parent_shipment` | [PROCUREMENT_STOCK.md](PROCUREMENT_STOCK.md) |
| **B4 — Invoice & charges** | `global_invoices`, items, returns, charges; fresh-insert RPCs | [SALES_INVOICE.md](SALES_INVOICE.md) |
| **B5 — Reports & treasury** | Payment tables; margin report RPCs; retire ledger writes | [REPORTING_TREASURY.md](REPORTING_TREASURY.md) |
| **B6 — Capital** | `investor_capital` module; shipment investments; portal bootstrap | [INVESTOR_CAPITAL.md](INVESTOR_CAPITAL.md) |
| **B7 — Cleanup** | Drop legacy tables; regenerate `supabase.ts` | — |

### Frontend stages

All new/updated pages **must** follow [doc/frontend style guilde.md](doc/frontend%20style%20guilde.md) and [UI_CONSISTENCY_GUIDE.md](../web/UI_CONSISTENCY_GUIDE.md).

| Stage | Deliverables | Domain doc |
|-------|--------------|------------|
| **F1 — Shared UI** | `floating-surface`, `AppPageHeader`, tokens | Style guides |
| **F2 — Parent shipment** | Procurement lines → parent shipment UI | [PROCUREMENT_STOCK.md](PROCUREMENT_STOCK.md) |
| **F3 — Global stock** | Stock list, allocation manager, network search | [PROCUREMENT_STOCK.md](PROCUREMENT_STOCK.md) |
| **F4 — Sales invoice** | Wholesale / retail / dropship; billing profiles | [SALES_INVOICE.md](SALES_INVOICE.md) |
| **F5 — Finance reports** | Margin reports, payments, balances | [REPORTING_TREASURY.md](REPORTING_TREASURY.md) |
| **F6 — Investor capital** | Admin `/app/capital/*` + investor portal | [INVESTOR_CAPITAL.md](INVESTOR_CAPITAL.md) |
| **F7 — Commerce retarget** | Commerce sells `global_stock_id` | §14 row 24–27 |

**Investor portal:** See [INVESTOR_CAPITAL.md](INVESTOR_CAPITAL.md) — admin capital management + read-only investor reports at `/:slug/investor/*`.

**Thrift borrowings (optional):** `AppPageHeader`, `PageInitialLoader`, mobile card rows. Do **not** copy Thrift composable architecture — web keeps module/repository/store pattern.

---

## 11. Module assignment guide

| Module family | Parent | Child | Detail |
|---------------|--------|-------|--------|
| `procurement_stock` (shipment, stock) | Yes | Allocated view | [PROCUREMENT_STOCK.md](PROCUREMENT_STOCK.md) |
| `order_management`, `product_based_costing` | No | Yes | §17 |
| `commerce_*` | No | Yes | §17 |
| `sales_invoice` | Optional | Yes | [SALES_INVOICE.md](SALES_INVOICE.md) |
| `reporting_treasury` | Varies | Child: payments + invoice reports | [REPORTING_TREASURY.md](REPORTING_TREASURY.md) |
| `investor_capital` | Yes | No | [INVESTOR_CAPITAL.md](INVESTOR_CAPITAL.md) |
| `global_reference` | Platform CRUD | App read-only | [GLOBAL_REFERENCE_DATA.md](GLOBAL_REFERENCE_DATA.md) |

Per-tenant assignment table: §15.5 and domain docs.

---

## 12. Documentation map

| Doc | Read when you need… |
|-----|---------------------|
| **MASTER_PLAN.md (this file)** | Vision, phases, feature matrix, permissions, module index, flows |
| [APP_SCOPES_AND_ACCESS.md](APP_SCOPES_AND_ACCESS.md) | Platform / App / Shop / Investor scopes, guards, redirects |
| [TENANT_MODEL_AND_ACCESS.md](TENANT_MODEL_AND_ACCESS.md) | Tenant types, hierarchy, modules, data ownership, investor membership |
| [LOGIN_NAV_PERMISSION_FLOW.md](LOGIN_NAV_PERMISSION_FLOW.md) | Login → bootstrap → nav implementation |
| [GLOBAL_REFERENCE_DATA.md](GLOBAL_REFERENCE_DATA.md) | Currencies, markets, payment methods, units |
| [PROCUREMENT_STOCK.md](PROCUREMENT_STOCK.md) | Shipments, stock, allocations, landed cost |
| [SALES_INVOICE.md](SALES_INVOICE.md) | Desk invoices, billing/recipient profiles, dropship |
| [REPORTING_TREASURY.md](REPORTING_TREASURY.md) | Margin reports, payments, balances, batch P&L |
| [INVESTOR_CAPITAL.md](INVESTOR_CAPITAL.md) | Investor profiles, capital ledger, portal, cost-share |
| [doc/frontend style guilde.md](doc/frontend%20style%20guilde.md) | Mandatory UI patterns for new pages |
| [web/UI_CONSISTENCY_GUIDE.md](../web/UI_CONSISTENCY_GUIDE.md) | `bw-page`, tables, cards |

**Hierarchy:** This file = index + cross-cutting rules. Domain docs = detailed design per area. Implementation how-to = LOGIN_NAV_PERMISSION_FLOW.

---

## 13. Out of scope (later)

- Thrift parent/child global integration
- Multi-level tenant hierarchy
- Mandatory costing → order conversion
- `is_display_only = false` child sale bridge
- Merge `invoice_accounting_payments` with `payments`
- Investor withdrawal request flow (v1 is display-only — see INVESTOR_CAPITAL)

---

## 14. High-Level Feature & Decision Matrix

> **How to read:** Scan §14.1 for all modules at a glance. Open the **Detail doc** from §17 for implementation. Permissions: §15. Target schemas: domain docs (§16 index).

### 14.1 Module scan matrix

| # | Domain | Module | module_key | Status | Scope | Tenant | Purpose | Priority |
|---|--------|--------|------------|--------|-------|--------|---------|----------|
| 1 | Platform & Access | Platform & Tenancy | — | STABLE | platform | Platform | Manage tenants, markets, superadmin | — |
| 2 | Platform & Access | Permission & Module System | modules / tenant_modules | STABLE | all | All | Feature flags per tenant | P1 |
| 3 | Currency | Global Reference | global_reference | CURRENT | app | All (read) | Currencies, markets, payment methods, units | P0 |
| 4 | Catalog & Supply | Products | products | STABLE | app | Parent+Child | Product catalog | — |
| 5 | Catalog & Supply | Vendors | vendor | STABLE | app | Parent+Child | Supplier records | P0 |
| 6 | Procurement Inputs | Order Management | order_management | STABLE | app+shop | Child | B2B purchase intent | P1 |
| 7 | Procurement Inputs | Costing File | costing_file | STABLE | app+shop | Child | Pre-order costing references | — |
| 8 | Procurement Inputs | Product Based Costing | product_based_costing | STABLE | app | Child | Batch costing → shipment lines | — |
| 9 | Procurement & Stock | Global Shipment | global_shipment | CURRENT | app | Parent | Inbound shipment batches | P0 |
| 10 | Procurement & Stock | Global Stock | global_stock | CURRENT | app | Parent | Parent-owned inventory | P0 |
| 11 | Procurement & Stock | Global Stock Type | global_stock_type | REDESIGN | app | Parent | Stock behaviour classes | P0 |
| 12 | Procurement & Stock | Tenant Stock | inventory | STABLE | app | Child | Child allocation slices | — |
| 13 | Profile & CRM | Billing Profile | billing_profile | STABLE | app | Child | Buyer / middle-man account | P1 |
| 14 | Profile & CRM | Recipient Profile | recipient_profile | REDESIGN | app | Child | Delivery endpoint (dropship) | P0 |
| 15 | Sales & Invoice | Sales Invoice (Desk) | global_invoice | CURRENT | app | Child | Wholesale, retail, dropship | P0 |
| 16 | Sales & Invoice | Shop Invoice | commerce_invoice | STABLE | app | Child | Commerce-generated invoices | — |
| 17 | Sales & Invoice | Legacy Invoice | invoice | LEGACY | app | Child | Deprecated — use global_invoice | P1 |
| 18 | Ledger & Treasury | Payments | payments | CURRENT | app | Child+Parent | Cash collection + allocation | P0 |
| 19 | Ledger & Treasury | Accounting (Legacy UI) | accounting | STABLE | app | Child | Legacy tenant accounting views | — |
| 20 | Ledger & Treasury | Reports & Treasury | reporting_treasury | CURRENT | app | Varies | Margin reports, balances, dashboard | P0 |
| 21 | Ledger & Treasury | Legacy ledger keys | global_accounting_ledger, global_*_accounting | LEGACY | app | Parent | Being retired — use reporting_treasury | P1 |
| 22 | Shop & B2B | Store | store | STABLE | app+shop | Child | Storefront config | — |
| 23 | Shop & B2B | Cart | cart | STABLE | shop | Child | B2B shop cart | — |
| 24 | Commerce | Commerce Shop | commerce_shop | STABLE | app+shop | Child | Commerce storefront | — |
| 25 | Commerce | Commerce Order | commerce_order | STABLE | app+shop | Child | Commerce orders | — |
| 26 | Commerce | Commerce Cart | commerce_cart | STABLE | shop | Child | Commerce cart | — |
| 27 | Commerce | Commerce Accounting | commerce_accounting | STABLE | app | Child | Commerce ledger (isolated) | — |
| 28 | Capital | Investor (Legacy UI) | investor | LEGACY | app | Parent | Legacy — use investor_capital | — |
| 29 | Capital | Investor Capital | investor_capital | CURRENT | app+investor | Parent | Profiles, ledger, allocations, portal | P0 |
| 30 | Capital | Legacy capital keys | global_investor, global_investor_shipment, investor_portal | LEGACY | — | Parent | Subsumed by investor_capital parent module | — |
| 31 | Verticals | Thrift | thrift_* (9 keys) | STABLE | app | Per tenant | Isolated thrift vertical | — |
| 32 | Verticals | Koba | koba_retail, koba_wholesale | STABLE | app+shop | Per tenant | Scraped catalog orders | — |
| 33 | Verticals | Tasks | tasks | STABLE | app | Per tenant | Internal task hierarchy | — |

### 14.2 Domain bundle summary

| Domain | Modules | Detail doc |
|--------|---------|------------|
| Platform & Access | 01–02 | [TENANT_MODEL_AND_ACCESS.md](TENANT_MODEL_AND_ACCESS.md), [APP_SCOPES_AND_ACCESS.md](APP_SCOPES_AND_ACCESS.md) |
| Currency / Reference | 03 | [GLOBAL_REFERENCE_DATA.md](GLOBAL_REFERENCE_DATA.md) |
| Catalog & Supply | 04–05 | §17 (no domain doc yet) |
| Procurement Inputs | 06–08 | §17 |
| Procurement & Stock | 09–12 | [PROCUREMENT_STOCK.md](PROCUREMENT_STOCK.md) |
| Profile & CRM | 13–14 | [SALES_INVOICE.md](SALES_INVOICE.md) |
| Sales & Invoice | 15–17 | [SALES_INVOICE.md](SALES_INVOICE.md) |
| Ledger & Treasury | 18–21 | [REPORTING_TREASURY.md](REPORTING_TREASURY.md) |
| Shop & B2B | 22–23 | §17 |
| Commerce | 24–27 | §17 |
| Capital | 28–30 | [INVESTOR_CAPITAL.md](INVESTOR_CAPITAL.md) |
| Verticals | 31–33 | §17 |

### 14.3 Decision log (locked)

| # | Topic | Decision |
|---|-------|----------|
| D1 | Write model | Global tables only; no dual-write |
| D2 | Commerce inbound | Commerce does **not** create shipments |
| D3 | Commerce outbound | Sells from parent `global_stocks` |
| D4 | Tenant hierarchy | One level only |
| D5 | Standalone tenant | `parent_tenant_id := tenant_id` |
| D6 | Domestic shipment | Conversion rates forced to 1.0 |
| D7 | Landed cost | Snapshot to `unit_cost_price` at sale |
| D8 | Bulk payments | `global_payments` + manual `invoice_payments` slices |
| D9 | Billing vs recipient | Separate profiles — essential for dropship |
| D10 | Investor remainder | Parent bears cost-share gap below 100% |
| D11 | Costing → order | Not required; optional later |
| D12 | Thrift | No phase 1 global integration |
| D13 | Module enablement | `tenant_modules` per tenant; no inheritance |
| D14 | Role abilities | Code matrix in `modulePermissions.ts`; today only `view` |
| D15 | Margin / P&L | Read-side from transactions — no shadow ledger |

---

## 15. Permission schema & role matrix

### 15.1 Four-layer model

| Layer | Source | Controls |
|-------|--------|----------|
| 1 — Scope | Route prefix | Actor table (memberships / customer_group_members) |
| 2 — Tenant modules | `tenant_modules` + bootstrap RPC | Feature on/off per tenant |
| 3 — Role matrix | `modulePermissions.ts` | Role × `module_key` × `ModuleAction` |
| 4 — Row access | RLS + security-definer RPCs | Tenant / parent isolation |

**Implementation:** [LOGIN_NAV_PERMISSION_FLOW.md](LOGIN_NAV_PERMISSION_FLOW.md). **Scope detail:** [APP_SCOPES_AND_ACCESS.md](APP_SCOPES_AND_ACCESS.md).

### 15.2 Actor roles

| Scope | Roles | Auth table |
|-------|-------|------------|
| platform | superadmin | memberships (tenant_id null) |
| app | admin, staff, viewer | memberships |
| shop | customer_admin, customer_negotiator, customer_staff | customer_group_members |
| investor | investor | memberships (`role = investor`, linked `investor_id`) |

### 15.3 Full role × module matrix (as implemented today)

Legend: **view** = access granted | **—** = no access

| module_key | superadmin | admin | staff | viewer | customer_admin | customer_negotiator | customer_staff | investor |
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

> **Note:** `investor_capital` parent module permissions will be added when seeded. Target submodules: `investor_profiles`, `investor_capital_ledger`, `investor_shipment_share`, `investor_portal` — see [INVESTOR_CAPITAL.md](INVESTOR_CAPITAL.md) §12.

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
| reporting_treasury submodules | Varies | Varies | Yes | See REPORTING_TREASURY §2 |
| investor_capital | Yes | — | Yes | Capital |
| thrift_*, koba_*, tasks | Per tenant | Per tenant | Per tenant | Verticals |
| global_reference | Read all | Read all | Read all | Platform configures |

---

## 16. Redesign entity model (index)

> **Target schemas live in domain docs.** This section is a quick index only. Current-vs-target table mapping is in §16.1.

| Entity | Target table(s) | Detail document |
|--------|-----------------|-----------------|
| Global currency | `global_currencies` | [GLOBAL_REFERENCE_DATA.md](GLOBAL_REFERENCE_DATA.md) |
| Global shipment | `global_shipments`, `global_shipment_items` | [PROCUREMENT_STOCK.md](PROCUREMENT_STOCK.md) |
| Global stock | `global_stocks`, `global_stock_types` | [PROCUREMENT_STOCK.md](PROCUREMENT_STOCK.md) |
| Billing / recipient | `billing_profiles`, `recipient_profiles` | [SALES_INVOICE.md](SALES_INVOICE.md) |
| Global invoice | `global_invoices`, `global_invoice_items` | [SALES_INVOICE.md](SALES_INVOICE.md) |
| Payments | `global_payments`, `invoice_payments` | [REPORTING_TREASURY.md](REPORTING_TREASURY.md) |
| Investors | `investors`, `investor_transactions`, `shipment_investments` | [INVESTOR_CAPITAL.md](INVESTOR_CAPITAL.md) |

### 16.1 Current vs target mapping

| Entity today | Target | Action |
|--------------|--------|--------|
| `shipments` | `global_shipments` | Rename + currency/vendor FKs |
| `shipment_items` | `global_shipment_items` | Add landed cost, add_method |
| `global_stocks` + `global_stock_quantities` | Simplified `global_stocks` + `global_stock_types` | Redesign |
| `business_parties` / inline recipient | `recipient_profiles` | New table |
| `invoice_charge_lines` | Inline on `global_invoices` or charge lines | Per SALES_INVOICE |
| `payments` | `global_payments` | `unallocated_amount` |
| `payment_allocations` | `invoice_payments` | Rename + `allocated_at` |
| `global_accounting_ledger` | Read-side margin queries | Retire writes |
| `orders`, `commerce_*`, `thrift_*`, `koba_*` | No change | STABLE |

---

## 17. Module index

> **Per-module detail** (routes, RPCs, UI, submodule trees) is in the domain doc column. Modules without a domain doc use §14.1 matrix row + codebase.

| # | module_key(s) | Status | Detail document |
|---|---------------|--------|-----------------|
| 1 | — (platform) | STABLE | [TENANT_MODEL_AND_ACCESS.md](TENANT_MODEL_AND_ACCESS.md) |
| 2 | modules / tenant_modules | STABLE | [LOGIN_NAV_PERMISSION_FLOW.md](LOGIN_NAV_PERMISSION_FLOW.md) |
| 3 | global_reference | CURRENT | [GLOBAL_REFERENCE_DATA.md](GLOBAL_REFERENCE_DATA.md) |
| 4 | products | STABLE | *(no domain doc — catalog CRUD)* |
| 5 | vendor | STABLE | *(no domain doc — vendor CRUD)* |
| 6 | order_management | STABLE | *(no domain doc — B2B orders)* |
| 7 | costing_file | STABLE | *(no domain doc)* |
| 8 | product_based_costing | STABLE | *(no domain doc)* |
| 9–12 | global_shipment, global_stock, global_stock_type, inventory | CURRENT | [PROCUREMENT_STOCK.md](PROCUREMENT_STOCK.md) |
| 13–14 | billing_profile, recipient_profile | STABLE / REDESIGN | [SALES_INVOICE.md](SALES_INVOICE.md) |
| 15–17 | global_invoice, commerce_invoice, invoice | CURRENT / LEGACY | [SALES_INVOICE.md](SALES_INVOICE.md) |
| 18–21 | payments, accounting, reporting_treasury, global_*_accounting | CURRENT / LEGACY | [REPORTING_TREASURY.md](REPORTING_TREASURY.md) |
| 22–23 | store, cart | STABLE | *(no domain doc — B2B shop)* |
| 24–27 | commerce_* | STABLE | *(no domain doc — isolated commerce)* |
| 28–30 | investor, investor_capital, global_investor* | LEGACY / CURRENT | [INVESTOR_CAPITAL.md](INVESTOR_CAPITAL.md) |
| 31 | thrift_* | STABLE | *(no domain doc — isolated vertical)* |
| 32 | koba_* | STABLE | *(no domain doc)* |
| 33 | tasks | STABLE | *(no domain doc)* |

---

## 18. End-to-end flows

```
Child: orders / product costing → Parent: shipment (local or international)
  → Parent: global_stocks → child_tenant_stock_allocations (optional)
  → Child: global_invoice → global_payments / invoice_payments
  → reporting_treasury: margin reports (read) → investor profit share
```

| Flow | Path | Status | Detail |
|------|------|--------|--------|
| B2B order | cart → order → negotiate → shipment pull | STABLE | §17 #6 |
| Costing | product_based_costing → shipment line | STABLE | [PROCUREMENT_STOCK.md](PROCUREMENT_STOCK.md) |
| Receive stock | shipment receive → global_stocks | CURRENT | [PROCUREMENT_STOCK.md](PROCUREMENT_STOCK.md) |
| Desk sale | global_stock → global_invoice → payment allocation | CURRENT | [SALES_INVOICE.md](SALES_INVOICE.md) |
| Margin report | invoice lines + shipment batch P&L (read) | CURRENT | [REPORTING_TREASURY.md](REPORTING_TREASURY.md) |
| Investor capital | cost-share → profit refresh → portal | PLANNED | [INVESTOR_CAPITAL.md](INVESTOR_CAPITAL.md) |
| Commerce | commerce_cart → order → invoice | STABLE | §17 #24–27 |
| Thrift | thrift_shipment → stock → invoice | STABLE | Isolated |

---

## 19. Related documentation

| Doc | Purpose |
|-----|---------|
| **This file (MASTER_PLAN.md)** | Index: vision, matrix, permissions, phases, flows |
| [APP_SCOPES_AND_ACCESS.md](APP_SCOPES_AND_ACCESS.md) | Scopes, guards, redirects |
| [TENANT_MODEL_AND_ACCESS.md](TENANT_MODEL_AND_ACCESS.md) | Tenant model and access |
| [LOGIN_NAV_PERMISSION_FLOW.md](LOGIN_NAV_PERMISSION_FLOW.md) | Auth bootstrap implementation |
| [GLOBAL_REFERENCE_DATA.md](GLOBAL_REFERENCE_DATA.md) | Reference catalogs |
| [PROCUREMENT_STOCK.md](PROCUREMENT_STOCK.md) | Procurement and stock |
| [SALES_INVOICE.md](SALES_INVOICE.md) | Sales and invoicing |
| [REPORTING_TREASURY.md](REPORTING_TREASURY.md) | Reports and treasury |
| [INVESTOR_CAPITAL.md](INVESTOR_CAPITAL.md) | Investor capital and portal |
| [doc/frontend style guilde.md](doc/frontend%20style%20guilde.md) | UI patterns |
