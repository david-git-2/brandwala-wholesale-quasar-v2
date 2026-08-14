# Workspace Agent Rules

## Supabase Database Schema Rule (Token Optimization)
- **Primary Schema Reference**: ALWAYS inspect `web/src/types/database.types.ts` FIRST when looking for active tables, columns, relations, views, or enums.
- **Do NOT Scan Migrations**: Do NOT read through all files in `supabase/migrations/*.sql` to determine active database state. Parsing migration history files wastes tokens and causes confusion.
- **New Migrations Only**: Only inspect or edit `supabase/migrations/*.sql` files when writing a new migration script.

## Procurement module — `doc/procurement_stock/IMPLEMENTATION_ORDER.md`
Shipment track (7A–14B) is complete. Warehouse work (**W1+**) is next — one row per session.
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
