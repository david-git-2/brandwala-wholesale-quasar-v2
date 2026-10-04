# Architecture: Database Conventions & Schema Structure

All database definitions, stored procedures, RLS policies, and migrations follow modular live SQL in `supabase/schemas/`. Tracker: [doc/supabase-schema.md](../../doc/supabase-schema.md).

`supabase/migrations/` is apply history for prod and local replay. It is not the live schema. Do not list or read that folder to learn tables or RPCs. Grep `supabase/schemas/`. Open one migration file only when you are adding or fixing that file.

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

1. Feature `spec.md` / PRD must not paste full `CREATE` or RPC bodies — link `supabase/schemas/<domain>/` instead.
2. **RPC body for a new migration** comes from `supabase/schemas/<domain>/03_rpcs.sql` (or `04_rpcs.sql` in notifications). Never copy from old `migrations/` files.
3. **Tenant isolation:** business rows carry tenant FK(s). RLS on. Access is membership + `has_module_action()`, not a `tenant_users` table name in the web app.
4. **Ledger:** post only via `record_ledger_transaction`. No direct balance writes. No stub RPCs that skip the ledger.
5. After changing SQL on an existing local DB (prod snapshot already loaded):

```bash
pnpm run backend:local
pnpm run backend:types:local
```

Empty-DB replay (`backend:reset`) only when proving migration order or the user asks.
