# Supabase Schema Guide

## Overview

The declarative database schema is located in `supabase/schemas/`:
* `_extensions.sql`: Database extensions.
* `public.sql`: Master active declarative public schema for un-split modules (including `universal_wallet_ledger`, `get_tenant_cash_in_report`, `global_payments`, etc.).
* Split domain modules:
  * `procurement/`: `01_types.sql`, `02_tables.sql`, `03_rpcs.sql`, `04_rls.sql`
  * `shop_order/`: `01_types.sql`, `02_tables.sql`, `03_rpcs.sql`, `04_rls.sql`

## Reports & Treasury Schema References

* **Cash In Report RPC**: `get_tenant_cash_in_report(p_tenant_id, p_start_date, p_end_date)`
  * **Source**: `supabase/schemas/public.sql`
  * **Migration**: `supabase/migrations/20270831000220_get_tenant_cash_in_report.sql`
  * **TypeScript types**: `web/src/types/database.types.ts`
  * **Documentation**: [`doc/reporting_treasury/CASH_IN.md`](./reporting_treasury/CASH_IN.md)

## Useful Commands

* **Deploy changes**: `pnpm run deploy:backend` (pushes migrations and updates TypeScript types).
* **Reset local DB**: `pnpm run backend:reset`
* **Generate types only**: `pnpm run backend:types`
