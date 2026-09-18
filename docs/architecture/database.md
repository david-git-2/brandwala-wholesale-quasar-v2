# Architecture: Database Conventions & Schema Structure

All database definitions, stored procedures, RLS policies, and migrations follow modular live SQL in `supabase/schemas/`. Tracker: [doc/supabase-schema.md](../../doc/supabase-schema.md).

---

## Directory structure (source of truth)

```text
supabase/
├── config.toml
├── migrations/                 # What production runs (history)
└── schemas/                    # Current public schema to edit
    ├── _extensions.sql
    ├── public.sql              # Unsplit modules
    └── <domain>/
        ├── 01_types.sql        # Enums / composites
        ├── 02_tables.sql       # Tables, FKs, indexes
        ├── 03_rpcs.sql         # Functions
        └── 04_rls.sql          # Policies
```

**Exception:** `notifications/` uses `03_rls.sql` then `04_rpcs.sql`. Follow files on disk for that folder.

Stub folders (`wallet/`, `thrift/`, `tenants/`, …) may exist before objects are moved out of `public.sql`. Check [doc/supabase-schema.md](../../doc/supabase-schema.md).

---

## Rules

1. **RPC body for a new migration** comes from `supabase/schemas/<domain>/03_rpcs.sql` (or `04_rpcs.sql` in notifications). Never copy from old `migrations/` files.
2. **Tenant isolation:** business rows carry tenant FK(s). RLS on. Access is membership + `has_module_action()`, not a `tenant_users` table name in the web app.
3. **Ledger:** post only via `record_ledger_transaction`. No direct balance writes. No stub RPCs that skip the ledger.
4. After changing SQL on an existing local DB (prod snapshot already loaded):

```bash
pnpm run backend:local
pnpm run backend:types:local
```

Empty-DB replay (`backend:reset`) only when proving migration order or the user asks.
