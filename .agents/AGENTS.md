# Workspace Agent Rules

## Supabase Database Schema Rule (Token Optimization)
- **Primary Schema Reference**: ALWAYS inspect `web/src/types/database.types.ts` FIRST when looking for active tables, columns, relations, views, or enums.
- **Do NOT Scan Migrations**: Do NOT read through all files in `supabase/migrations/*.sql` to determine active database state. Parsing migration history files wastes tokens and causes confusion.
- **New Migrations Only**: Only inspect or edit `supabase/migrations/*.sql` files when writing a new migration script.
