# Workspace Agent Rules

## Docs first — no guess
- Map: `docs/README.md`. New docs: `docs/STRUCTURE.md`. Models: `docs/architecture/business-models.md`. Rule: `.cursor/rules/docs-first.mdc`.
- If a needed fact is missing or two docs disagree: **stop**, emit `DOC_GAP`, wait for the human to edit the named doc. Do not invent RPCs, statuses, permissions, or stock models.

## Supabase Database Schema Rule (Token Optimization)
- **Current SQL**: `supabase/schemas/` (`public.sql` until a module is split). How-to & tracker: `doc/supabase-schema.md` (user says `split schema <domain>`). Module map: `docs/README.md`.
- **Never full-read** `web/src/types/database.types.ts` or `supabase/schemas/public.sql`. Grep one symbol; targeted read only. UI list pages: `.agents/skills/quasar/SKILL.md` + `docs/guides/ui-standards.md`.
- **TypeScript shapes**: `database.types.ts` (tables, columns, enums, RPC signatures — not bodies or RLS).
- **Do NOT Scan Migrations**: Do not glob, list, or bulk-read `supabase/migrations/`. Active state is `supabase/schemas/` only.
- **New Migrations Only**: Open `supabase/migrations/*.sql` only when writing/reviewing **that** generated or DML file, or when a reset error names the file.
- **Migration Source of Truth**: Copy RPC bodies from `supabase/schemas/<domain>/03_rpcs.sql` (or `04_rpcs.sql` in notifications), never from old migrations.
- **Local backend**: `.cursor/rules/supabase-local-backend.mdc`. Default after migration: `pnpm run backend:local` + `backend:types:local`.
- **Migration order / fresh reset**: `.agents/skills/supabase-migration-order/SKILL.md`. `backend:reset` only when user asks or proving empty-DB replay.

## Feature docs — `docs/features/<module>/`
Load **`spec.md` + `00-gaps.md` only**. Tables/RPCs/UI: grep `supabase/schemas/` and `web/src/modules/<module>/`.

## Procurement — `docs/features/procurement_stock/`
When a phase adds SQL migrations: read those files; run `backend:local` + `backend:types:local` before done. Never ship stub RPCs (fake `wallet_posted` without `record_ledger_transaction`).
