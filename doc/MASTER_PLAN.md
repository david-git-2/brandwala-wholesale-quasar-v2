# BrandWala / TradeFlow BD — Master Architectural Plan

BrandWala is an enterprise multi-tenant ERP and commerce platform designed for parent companies and sister concerns operating wholesale distribution, warehouse fulfillment, dropship networks, and specialized retail verticals.

---

## 1. Platform Vision & End-to-End Business Flow

```mermaid
flowchart LR
    A["1. Pre-Order Costing<br/>(Child PBC Backlog)"] --> B["2. Inbound Intake<br/>(Parent Shipment & Customs)"]
    B --> C["3. Warehouse Pooling<br/>(Parent global_stocks)"]
    C --> D["4. Multi-Desk Selling<br/>(Wholesale / Storefront / Dropship)"]
    D --> E["5. Universal Wallet<br/>(Ledger Cash Settlement)"]
    E --> F["6. Reporting & Treasury<br/>(Read-side P&L & Investor Yield)"]
```

### Core Tenets of the Platform
1. **Single Physical Stock Pool**: Physical inventory is owned exclusively at the **Parent** tenant level (`global_stocks`). Child sister concerns consume stock via virtual allocations without duplicating physical stock rows.
2. **Atomic Single-Invoice Ownership**: Sales invoices (`global_invoices`) are owned by the parent company for consolidated ledger auditing, with `issued_by_tenant_id` preserving child sister-concern branding and customer relationships.
3. **No Shadow Accounting Ledgers**: Margins and P&L are derived dynamically from operational data — invoice lines snapshot `unit_cost_price` at issue time; shipment batch analytics use live `landed_cost_bdt` (via `calculate_landed_unit_cost`) until `costs_locked`.
4. **The One-Wallet Principle**: Every entity has one ledger wallet keyed by `(parent_tenant_id, entity_type, entity_id)` on the **parent books**; `operating_tenant_id` records which child desk ran the transaction. See [`doc/wallet/WALLET.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/wallet/WALLET.md) and migration plan [`WALLET_PARENT_BOOKS_IMPLEMENTATION.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/wallet/WALLET_PARENT_BOOKS_IMPLEMENTATION.md).

---

## 2. Technology Stack & Architectural Standards

| Layer | Technology | Architectural Standard |
| :--- | :--- | :--- |
| **Frontend Framework** | Vue 3 + Quasar Framework (Options API & Composition API) | Compact list toolbar design system, sticky table headers, zero in-page `<h1>` headers. |
| **Server State & Caching** | TanStack Query (`@tanstack/vue-query`) | Query key factories, `staleTime` optimization, optimistic mutations, zero redundant refetches. |
| **Backend & Database** | Supabase (PostgreSQL 15+, Row-Level Security, RPCs) | Atomic PostgreSQL RPCs for multi-table transactions; `schemas/` directory modularization. |
| **Mobile Client** | Capacitor (Android) | Specialized mobile barcode scanning and inventory audit companion. |

---

## 3. Canonical Module Index (`doc/`)

All domain specifications, page matrices, and engine algorithms are maintained across these 17 canonical documents:

### Core Governance & Infrastructure
* [`doc/tenant_auth/TENANT_AUTH.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/tenant_auth/TENANT_AUTH.md): Multi-tenancy, 4 application scopes (`app`, `shop`, `investor`, `superadmin`), OAuth lifecycle, and RBAC action permissions.
* [`doc/tenant_auth/TENANT_OPERATIONAL_DATA_RESET.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/tenant_auth/TENANT_OPERATIONAL_DATA_RESET.md): Clean slate engine, transactional data wipe (stocks, orders, shipments, invoices, ledgers), safety guardrails, and audit logging.
* [`doc/global_reference/GLOBAL_REFERENCE.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/global_reference/GLOBAL_REFERENCE.md): Platform currencies, markets, payment methods, units of measure, and country registries.
* [`doc/tag/TAG.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/tag/TAG.md): Universal taxonomy dictionary, stock grading presets, color swatches, and classification rules.
* [`doc/trash/TRASH.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/trash/TRASH.md): Tenant-scoped soft-deletion, `trash_entries` directory index, 30-day retention policies.
* [`doc/dashboard/DASHBOARD.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/dashboard/DASHBOARD.md): Decentralized widget slot registry, permission-gated home surfaces, and shop glance KPI panels.

### Procurement & Warehouse Operations
* [`doc/procurement_stock/PROCUREMENT_STOCK.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/procurement_stock/PROCUREMENT_STOCK.md): International shipment intake, 4-tier bin location hierarchy, stock movements, and Landed Cost Engine (`shipment_engine`).
* [`doc/products/PRODUCTS.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/products/PRODUCTS.md): Master merchandise catalog, brand/category taxonomies, and the Price Check (PC) Excel bulk import pipeline.
* [`doc/product_based_costing/PBC_COSTING.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/product_based_costing/PBC_COSTING.md): Pre-order costing files, customer demand backlog auto-suggest drawer, and parent shipment handoff.

### Commercial Sales & Customer Desks
* [`doc/sales_invoice/SALES_INVOICE.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/sales_invoice/SALES_INVOICE.md): Wholesale POS invoicing desk, FIFO stock allocation search engine, and return restocking calculations.
* [`doc/customer/CUSTOMER.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/customer/CUSTOMER.md): Customer groups, billing profiles, storefront members (`admin` / `manager` / `staff`), wallets, and recipient addresses. Shop hub Customer Groups opens this module.
* [`doc/shop_order/SHOP_ORDER.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/shop_order/SHOP_ORDER.md): Shop setup hub (`shop_config`), B2B storefront commerce (`shop` scope), and Dropship Reseller Desk (`app` scope) with the 3-step Dropship Finance Hub. UI flows: [`UI_FLOW.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/shop_order/UI_FLOW.md). Catalog negotiation: [`CATALOG_NEGOTIATION.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/shop_order/CATALOG_NEGOTIATION.md). Demand bucket: [`DEMAND_BUCKET.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/shop_order/DEMAND_BUCKET.md). Procurement demand list: [`PROCUREMENT_DEMAND_LIST.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/shop_order/PROCUREMENT_DEMAND_LIST.md). Customer groups: [`CUSTOMER.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/customer/CUSTOMER.md).

### Financial Management & Capital
* [`doc/wallet/WALLET.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/wallet/WALLET.md): Universal multi-currency double-entry ledger, entity wallet statements, Cash in (`get_tenant_cash_in_report`), and atomic transfers. **Migration:** [`WALLET_PARENT_BOOKS_IMPLEMENTATION.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/wallet/WALLET_PARENT_BOOKS_IMPLEMENTATION.md).
* [`doc/reporting_treasury/REPORTING_TREASURY.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/reporting_treasury/REPORTING_TREASURY.md): Payments collection, Cash in report, and remaining finance routes. Eight-report list: [`REPORTS_PLAN.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/REPORTS_PLAN.md). Cash in spec: [`doc/reporting_treasury/CASH_IN.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/reporting_treasury/CASH_IN.md). Customer dues spec: [`doc/reporting_treasury/CUSTOMER_DUES.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/reporting_treasury/CUSTOMER_DUES.md).
* [`doc/investor_capital/INVESTOR_CAPITAL.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/investor_capital/INVESTOR_CAPITAL.md): External partner capital pools, shipment batch cost-sharing allocations, and read-side yield calculation.

### Specialized Verticals & Collaboration
* [`doc/thrift/THRIFT.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/thrift/THRIFT.md): Complete second-hand vertical: consignment shipments, thermal barcode generation, garment measurements, POS desk, and returns.
* [`doc/koba/KOBA.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/koba/KOBA.md): Cross-border UK catalog scraping, custom retail markups, commission sharing, and customer address CRM.
* [`doc/tasks/TASKS.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/tasks/TASKS.md): Internal task tracking, subtask nesting, assignee multi-casting, comments, and audit logs.
