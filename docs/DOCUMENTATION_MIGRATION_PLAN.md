# Documentation Migration & Modernization Plan

This document outlines the systematic strategy to transition the codebase from unstructured/legacy documents in `doc/` to the standardized UI-first 6-phase architecture in `docs/features/`.

---

## 🎯 Target Standard Architecture

Each module in `docs/features/<domain>/` will strictly contain:

```text
docs/features/<domain>/
├── 01-prd.md                  # Product Requirements, User Stories, UX & Layout Wireframe
├── 02-data-model.md           # Declarative SQL Tables, Enums, Types, Constraints & RLS
├── 03-api-contract.md         # Supabase RPC Signatures, Request/Response Payloads & Errors
├── 04-tdd.md                  # Technical Design Document, Vue Query Hooks, Pinia Stores & Tree
├── 05-page-to-api-matrix.md   # Control-to-RPC / Field-to-Endpoint Mapping Table
└── stubs.ts                   # Typed Mock Data & Client Handlers for UI Testing
```

---

## 🗺️ Module Inventory & Migration Roadmap

### 📦 Phase 1: Core Financial & Operational Engines — ✅ COMPLETED
*These modules form the transactional backbone of TradeFlow BD. All 5 modules now have standardized 6-file suites in `docs/features/` and legacy `doc/` files have been cleaned up.*

| Module | Target Path | Status |
| :--- | :--- | :--- |
| **1. Procurement & Stock** | `docs/features/procurement_stock/` | ✅ Complete (6 files: PRD, Data Model, API, TDD, Matrix, Stubs) |
| **2. Sales Invoice** | `docs/features/sales_invoice/` | ✅ Complete (6 files: PRD, Data Model, API, TDD, Matrix, Stubs) |
| **3. Shop Order & Dropship** | `docs/features/shop_order/` | ✅ Complete (6 files: PRD, Data Model, API, TDD, Matrix, Stubs) |
| **4. Universal Wallet & Ledger** | `docs/features/wallet/` | ✅ Complete (6 files: PRD, Data Model, API, TDD, Matrix, Stubs) |
| **5. Reporting & Treasury** | `docs/features/reporting_treasury/` | ✅ Complete (6 files: PRD, Data Model, API, TDD, Matrix, Stubs) |

---

### 🛍️ Phase 2: Customer, Costing, Catalog & Identity — ✅ COMPLETED
*Modules managing core business relationships, product definitions, and tenant access. All 5 modules now have standardized 6-file suites in `docs/features/` and legacy `doc/` files have been cleaned up.*

| Module | Target Path | Status |
| :--- | :--- | :--- |
| **6. Customer Hub** | `docs/features/customer/` | ✅ Complete (6 files: PRD, Data Model, API, TDD, Matrix, Stubs) |
| **7. After-Sales & Returns** | `docs/features/after_sales/` | ✅ Complete (6 files: PRD, Data Model, API, TDD, Matrix, Stubs) |
| **8. Product-Based Costing (PBC)** | `docs/features/product_based_costing/` | ✅ Complete (6 files: PRD, Data Model, API, TDD, Matrix, Stubs) |
| **9. Products & Tag Catalog** | `docs/features/products/` | ✅ Complete (6 files: PRD, Data Model, API, TDD, Matrix, Stubs) |
| **10. Tenant Auth & Access Control** | `docs/features/tenant_auth/` | ✅ Complete (6 files: PRD, Data Model, API, TDD, Matrix, Stubs) |

---

### ⚙️ Phase 3: Specialized Extensions & UI Modules — ✅ COMPLETED
*Specialized verticals, portals, dashboard widgets, notification queues, global references, and central soft-delete recovery. All 5 modules now have standardized 6-file suites in `docs/features/` and legacy `doc/` files have been cleaned up.*

| Module | Target Path | Status |
| :--- | :--- | :--- |
| **11. Thrift Vertical** | `docs/features/thrift/` | ✅ Complete (6 files: PRD, Data Model, API, TDD, Matrix, Stubs) |
| **12. Investor Portal & Capital** | `docs/features/investor_capital/` | ✅ Complete (6 files: PRD, Data Model, API, TDD, Matrix, Stubs) |
| **13. Dashboard & Insights** | `docs/features/dashboard/` | ✅ Complete (6 files: PRD, Data Model, API, TDD, Matrix, Stubs) |
| **14. Tasks & Notifications** | `docs/features/notifications/` | ✅ Complete (6 files: PRD, Data Model, API, TDD, Matrix, Stubs) |
| **15. Global Reference & Koba** | `docs/features/global_reference/` | ✅ Complete (6 files: PRD, Data Model, API, TDD, Matrix, Stubs) |

---

## 🔄 Migration Execution Protocol (Per Module)

For each module, the migration follows a 4-step sequence:

1. **Information Extraction**: Read all legacy notes in `doc/`, active database schemas in `supabase/schemas/<domain>/`, and active Vue components in `web/src/modules/<domain>/`.
2. **Standard 6-File Authoring**: Generate `01-prd.md`, `02-data-model.md`, `03-api-contract.md`, `04-tdd.md`, `05-page-to-api-matrix.md`, and `stubs.ts` in `docs/features/<domain>/`.
3. **Legacy Clean-Up**: Discard and remove superseded notes from `doc/<domain>/`.
4. **Codex Indexing**: Verify that `/dev/document` instantly picks up the new feature documentation tree with live search, tags, and table of contents.
