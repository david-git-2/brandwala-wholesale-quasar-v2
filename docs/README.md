# TradeFlow BD — Project Documentation & Engineering Codex

Welcome to the engineering documentation for **TradeFlow BD**. This repository serves as the single source of truth for architectural decisions, feature specifications, database conventions, API contracts, and design system rules.

---

## 📚 Documentation Index

### 1. 🏗️ Architecture & Engineering Standards
- [**Feature Development & Documentation Lifecycle**](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/docs/architecture/feature-development-process.md) — The UI-First development workflow, phase progression (`01-prd`, `02-data-model`, `03-api-contract`, `04-tdd`, `05-page-to-api-matrix`, `stubs.ts`).
- [**Database Conventions & Schema Structure**](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/docs/architecture/database-conventions.md) — Supabase modular schemas (`supabase/schemas/<domain>/`), RPC patterns, RLS policies, migrations ordering, and Ledger conventions.
- [**State Management & Data Fetching**](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/docs/architecture/state-management.md) — Server state synchronization with **TanStack Vue Query (v5)**, client state with **Pinia**, and direct Supabase client guidelines.
- [**UI Layout & Design System**](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/docs/architecture/ui-design-system.md) — Ops table layouts, non-scrolling page containers, internal scrollbars, status hues, and Quasar component rules.

### 2. 📦 Core Modules & Feature Specifications
- [**Feature Blueprint Template**](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/docs/features/template/01-prd.md) — Boilerplate template for drafting new modules.
- **Procurement & Stock** — Multi-phase shipment track, warehouse ops, stock search engine.
- **Sales Invoices & Billing** — Invoice numbering engine, payload RPCs, wholesale issue flows.
- **Shop Orders & Dropship** — Catalog negotiation, demand buckets, dropship fulfillment.
- **Universal Wallet & Ledger** — Entity balance books, ledger transaction posting, cash flow tracking.
- **Customer & Tenant Management** — Customer account summaries, tenant isolation, and permissions.
- **Reporting & Treasury** — Invoice profits, courier COD tracking, monthly cash snapshot, and ledger audits.

---

## 🚀 Quick Reference Commands

| Task | Command |
| :--- | :--- |
| **Start Web App** | `pnpm --dir web dev` |
| **Type Check Web App** | `pnpm --dir web type-check` |
| **Lint Web App** | `pnpm --dir web lint` |
| **Local Supabase Start** | `pnpm run backend:local` |
| **Regenerate Supabase Types** | `pnpm run backend:types:local` |
| **Open Documentation Codex** | `http://localhost:9000/dev/document` |
| **Explore Design System** | `http://localhost:9000/dev/designsystem` |
