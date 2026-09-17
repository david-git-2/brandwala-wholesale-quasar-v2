# Architecture: Database Conventions & Schema Structure

All database definitions, stored procedures, RLS policies, and migrations must follow strict modularity and auditability standards.

---

## 📁 Directory Structure & Source of Truth

Database code is organized under `supabase/`:

```text
supabase/
├── config.toml               # Local Supabase configuration
├── migrations/               # Versioned, chronological SQL migration files
└── schemas/                  # Declarative source-of-truth SQL definitions
    ├── <domain>/             # Modular domains (e.g., procurement, wallet, invoice)
    │   ├── 01_tables.sql     # Tables, enums, indexes, foreign keys
    │   ├── 02_rls.sql        # Row Level Security (RLS) policies
    │   └── 03_rpcs.sql       # Stored procedures & RPC functions
    └── public.sql            # Core shared schema (for unsplit modules)
```

---

## 🔒 Core Database Principles

### 1. RPC Migration Source of Truth
When creating new RPC migrations in `supabase/migrations/`, **ALWAYS** copy the function body directly from the active declarative schema in `supabase/schemas/<domain>/03_rpcs.sql`. Never copy from historical migrations.

### 2. Multi-Tenant & User Isolation
- Every business entity must include `tenant_id uuid references public.tenants(id)`.
- RLS must be enabled on all tables without exception.
- Standard tenant isolation policy checks: `auth.uid()` and user tenant memberships.

### 3. Ledger & Financial Integrity
- Universal ledger transactions must be recorded via `record_ledger_transaction`.
- Never update ledger balance rows directly; balances must be append-only or calculated through approved transactional RPCs.
- Never write stub RPCs that simulate ledger operations without writing actual double-entry records.

### 4. Reset & Migration Order
- Before adding migration files, ensure SQLSTATE compatibility (no duplicate types or missing foreign key tables).
- Default verification after a migration:
  ```bash
  pnpm run backend:local
  pnpm run backend:types:local
  ```
