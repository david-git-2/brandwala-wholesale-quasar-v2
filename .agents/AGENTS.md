# Workspace Agent Rules

## Supabase Database Schema Rule (Token Optimization)
- **Current SQL**: `supabase/schemas/` (`public.sql` until a module is split). How-to: `doc/SUPABASE_SCHEMA.md`. Split one domain: `doc/SUPABASE_SCHEMA_SPLIT.md` (user says `split schema <domain>`).
- **TypeScript shapes**: `web/src/types/database.types.ts` (tables, columns, enums, RPC signatures — not function bodies or RLS).
- **Do NOT Scan Migrations**: Do NOT read through all files in `supabase/migrations/*.sql` to determine active database state.
- **New Migrations Only**: Only inspect or edit `supabase/migrations/*.sql` when writing/reviewing a generated or DML migration.
- **Migration Source of Truth**: When creating new RPC migrations, **ALWAYS** copy the function body from the active declarative schema in `supabase/schemas/<domain>/03_rpcs.sql`, NEVER from historical migration files in `supabase/migrations/` (to prevent resurrecting deprecated enum values like `'posted'`).

## Procurement module — `doc/procurement_stock/IMPLEMENTATION_ORDER.md`
Shipment track (7A–14B) and warehouse W1–W9 are complete.
When a phase adds SQL migrations:
- **Read** the migration files you add or replace.
- **Run** `pnpm run backend:reset` and `pnpm run backend:types` before marking done.
- Treat **`database.types.ts` as generated output**, not proof migrations are reset-safe.
- **Never** ship stub RPCs (count-only loops, fake `wallet_posted: true` without `record_ledger_transaction`).

## API & Network Optimization Rules
- **Avoid Redundant Calls**: Never make redundant API calls if the data is already available or can be derived from existing state.
- **Use RPCs for Multiple Operations**: If an action requires multiple database operations (e.g., inserts/updates across multiple tables), create and use a Supabase RPC (Stored Procedure) to handle it in a single network request.
- **Cache-First Mutations**: For edit or delete operations, DO NOT refetch the entire list afterwards. Instead, manually update the local cache (e.g., Vue Query / React Query cache) with the new data or remove the deleted item.
- **Partial Payload for Edits (PATCH style)**: When editing a record, only send the fields that were actually modified in the payload. Do not send the entire object back to the server.
- **Optimistic Updates**: Provide immediate UI feedback by optimistically updating the local state before the API call completes, rolling back if it fails.
- **Debounce Input-Driven Requests**: For search inputs or rapid toggles, debounce the API calls to prevent spamming the backend.
- **Batch Operations**: When performing the same action on multiple items (e.g., bulk delete), use a single bulk API call rather than iterating and sending individual requests.

## List Table UI & Layout Design System Rule
- **Canonical Design Rule**: Follow `.agents/rules/table_list_design_system.md` for all list table pages.
- **Zero In-Page Headers**: Never render redundant in-page `<h1>` or `text-overline` header banners. Global breadcrumbs in the top header provide page title and hierarchy. Move primary action buttons and search controls directly into the compact table toolbar.
- **Non-Scrolling Page Container**: Lock `q-page` height to `calc(100vh - 55px)` with `overflow: hidden`.
- **Internal Table Scroll**: Use sticky headers (`thead tr th`) and let table middle scroll internally (`.q-table__middle { overflow-y: auto }`).
- **Status Row Hues**: Apply soft status background hues and inset left accent borders (`boxShadow: inset 3px 0 0 ...`).
- **Flat table surfaces**: Ops list tables use global flat `.q-table__container` styling — not heavy `.floating-surface.shadow-1` stacks (see `docs/UI_CONSISTENCY.md` elevation rules).
- **Rounded Square Buttons**: Primary action buttons MUST use rounded square corners (`border-radius: 8px`), NOT pill shapes.
- **Outlined Search Input**: Search inputs MUST use `outlined rounded dense`.
- **Neutral Avatars**: Entity/vendor avatars MUST use neutral grey tones (`color="grey-3" text-color="grey-9"`).
