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
3. **No Shadow Accounting Ledgers**: Margins and P&L are derived dynamically from live operational line-item cost snapshots and stamped landed costs (`landed_cost_bdt`).
4. **The One-Wallet Principle**: Every entity on the platform (Tenant, Vendor, Courier, Merchant, Customer, Cargo Agent, Investor) has exactly one immutable double-entry ledger wallet (`universal_wallet_ledger`).

---

## 2. Technology Stack & Architectural Standards

| Layer | Technology | Architectural Standard |
| :--- | :--- | :--- |
| **Frontend Framework** | Vue 3 + Quasar Framework (Options API & Composition API) | Compact list toolbar design system, sticky table headers, zero in-page `<h1>` headers. |
| **Server State & Caching** | TanStack Query (`@tanstack/vue-query`) | Query key factories, `staleTime` optimization, optimistic mutations, zero redundant refetches. |
| **Backend & Database** | Supabase (PostgreSQL 15+, Row-Level Security, RPCs) | Atomic PostgreSQL RPCs for multi-table transactions; `schemas/` directory modularization. |
| **Mobile Client** | Capacitor (Android) | Specialized mobile barcode scanning and inventory audit companion. |

---

## 3. Canonical Module Index (`doc_v2/`)

All domain specifications, page matrices, and engine algorithms are maintained across these 17 canonical documents:

### Core Governance & Infrastructure
* [`doc_v2/tenant_auth/TENANT_AUTH.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc_v2/tenant_auth/TENANT_AUTH.md): Multi-tenancy, 4 application scopes (`app`, `shop`, `investor`, `superadmin`), OAuth lifecycle, and RBAC action permissions.
* [`doc_v2/global_reference/GLOBAL_REFERENCE.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc_v2/global_reference/GLOBAL_REFERENCE.md): Platform currencies, markets, payment methods, units of measure, and country registries.
* [`doc_v2/tag/TAG.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc_v2/tag/TAG.md): Universal taxonomy dictionary, stock grading presets, color swatches, and classification rules.
* [`doc_v2/trash/TRASH.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc_v2/trash/TRASH.md): Tenant-scoped soft-deletion, `trash_entries` directory index, 30-day retention policies.
* [`doc_v2/dashboard/DASHBOARD.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc_v2/dashboard/DASHBOARD.md): Decentralized widget slot registry, permission-gated home surfaces, and shop glance KPI panels.

### Procurement & Warehouse Operations
* [`doc_v2/procurement_stock/PROCUREMENT_STOCK.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc_v2/procurement_stock/PROCUREMENT_STOCK.md): International shipment intake, 4-tier bin location hierarchy, stock movements, and Landed Cost Engine (`shipment_engine`).
* [`doc_v2/products/PRODUCTS.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc_v2/products/PRODUCTS.md): Master merchandise catalog, brand/category taxonomies, and the Price Check (PC) Excel bulk import pipeline.
* [`doc_v2/product_based_costing/PBC_COSTING.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc_v2/product_based_costing/PBC_COSTING.md): Pre-order costing files, customer demand backlog auto-suggest drawer, and parent shipment handoff.

### Commercial Sales & Customer Desks
* [`doc_v2/sales_invoice/SALES_INVOICE.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc_v2/sales_invoice/SALES_INVOICE.md): Wholesale POS invoicing desk, FIFO stock allocation search engine, and return restocking calculations.
* [`doc_v2/customer/CUSTOMER.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc_v2/customer/CUSTOMER.md): Customer billing profiles, credit limits, delivery addresses, and customer group membership.
* [`doc_v2/shop_order/SHOP_ORDER.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc_v2/shop_order/SHOP_ORDER.md): B2B storefront commerce (`shop` scope) and Dropship Reseller Desk (`app` scope) with the 3-step Dropship Finance Hub.

### Financial Management & Capital
* [`doc_v2/wallet/WALLET.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc_v2/wallet/WALLET.md): Universal multi-currency double-entry ledger, entity wallet statements, and atomic transfers.
* [`doc_v2/reporting_treasury/REPORTING_TREASURY.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc_v2/reporting_treasury/REPORTING_TREASURY.md): Read-side invoice gross margins, shipment P&L shrinkage audits, AR allocations, and Courier Bulk Remittance reconciliation.
* [`doc_v2/investor_capital/INVESTOR_CAPITAL.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc_v2/investor_capital/INVESTOR_CAPITAL.md): External partner capital pools, shipment batch cost-sharing allocations, and read-side yield calculation.

### Specialized Verticals & Collaboration
* [`doc_v2/thrift/THRIFT.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc_v2/thrift/THRIFT.md): Complete second-hand vertical: consignment shipments, thermal barcode generation, garment measurements, POS desk, and returns.
* [`doc_v2/koba/KOBA.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc_v2/koba/KOBA.md): Cross-border UK catalog scraping, custom retail markups, commission sharing, and customer address CRM.
* [`doc_v2/tasks/TASKS.md`](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc_v2/tasks/TASKS.md): Internal task tracking, subtask nesting, assignee multi-casting, comments, and audit logs.
