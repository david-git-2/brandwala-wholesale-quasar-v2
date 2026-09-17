# Architecture: Feature Development & Documentation Lifecycle

To maintain clean code quality, auditability, and clear separation of concerns across TradeFlow BD, all new features and major architectural refactors must adhere to the **UI-First 6-Phase Specification Process**.

---

## 🎯 The 6-Phase Feature Specification Lifecycle

Every feature module inside `docs/features/<feature-name>/` consists of 5 markdown documents and 1 stubs file:

```text
docs/features/<feature-name>/
├── 01-prd.md                  # Product Requirements Document & UX Specifications
├── 02-data-model.md           # Declarative SQL Tables, Enums, Types & RLS Policies
├── 03-api-contract.md         # Supabase RPC Function Signatures, Payloads & Responses
├── 04-tdd.md                  # Technical Design Document, Component Tree & Cache Hooks
├── 05-page-to-api-matrix.md   # Action-to-RPC / Field-to-Endpoint Mapping Table
└── stubs.ts                   # Mock Data & Client Stubs for Zero-Backend UI Prototyping
```

---

## 📋 Detailed Phase Breakdown

### Phase 1: Product Requirements Document (`01-prd.md`)
- **Purpose**: Defines what the feature is, the business problem it solves, user roles involved, and exact UX workflow.
- **Key Sections**:
  - Executive Summary & Goals
  - User Personas & Permissions (`admin`, `staff`, `viewer`, `customer`)
  - User Stories & Acceptance Criteria
  - Operational Edge Cases & Validation Rules
  - UI Layout Wireframes / ASCII Diagrams

### Phase 2: Data Model & Schema (`02-data-model.md`)
- **Purpose**: Establishes the authoritative Postgres database structure before writing any SQL migrations.
- **Key Sections**:
  - Entity Relationship Diagrams (ERD)
  - Declarative Tables (`CREATE TABLE`) with types, defaults, and foreign keys
  - Postgres Custom Enums & Constraints
  - Performance Indexes (B-tree, GIN on JSONB)
  - Row Level Security (RLS) policies for multi-tenant isolation
  - Generated TypeScript Types interface definition

### Phase 3: API Contract & RPC Signatures (`03-api-contract.md`)
- **Purpose**: Defines every backend endpoint and Supabase RPC function before writing implementation logic.
- **Key Sections**:
  - RPC Function Signatures: `function_name(params) RETURNS jsonb`
  - Input JSON payload validation schemas
  - Success return structures with realistic response examples
  - Error codes, exception triggers, and HTTP status mappings
  - Stored procedure transactions and lock acquisition details

### Phase 4: Technical Design Document (`04-tdd.md`)
- **Purpose**: Explains how the client-side Vue/Quasar application integrates the UI, stores, and backend.
- **Key Sections**:
  - Component Architecture Tree (Pages, Dialogs, Tables, Atoms)
  - Vue Query Cache Strategy (query keys, stale time, optimistic mutations)
  - Pinia Stores (ephemeral UI state, filter bars, selection tracking)
  - Performance considerations, debounce intervals, and batch operations
  - Step-by-step implementation plan with checklist

### Phase 5: Page-to-API Matrix (`05-page-to-api-matrix.md`)
- **Purpose**: A comprehensive matrix linking every visual UI element (button, form field, modal submit, search filter) to its corresponding API contract and query key.
- **Key Sections**:
  - Route / Modal Name
  - UI Action / Control (e.g., "Approve Invoice Button", "Vendor Filter Dropdown")
  - Triggered Mutation / Query (`useApproveInvoiceMutation()`, `useVendorsQuery()`)
  - Backend RPC / Table Operation (`approve_sales_invoice()`)
  - Cache Invalidation / Optimistic Cache Updates

### Phase 6: Mock Stubs & Prototypes (`stubs.ts`)
- **Purpose**: Provides fully-typed mock data sets and simulated async RPC handlers so frontend developers can build and test pixel-perfect UI screens before backend migrations are merged.

---

## ⚙️ Development Workflow Rules

1. **Specs Precede Code**: Never write UI components or Supabase RPCs without an approved specification set in `docs/features/`.
2. **Token & Query Efficiency**: Always prefer single-call RPCs over multiple sequential queries.
3. **Optimistic UI Updates**: Follow the cache-first mutation rule specified in the API & Network guidelines.
