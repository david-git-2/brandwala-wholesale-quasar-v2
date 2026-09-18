# Supabase Schema & Domain Split Guide

This document is the operational developer guide for managing declarative database schemas in `supabase/schemas/` and tracking modular domain extractions.

---

## 📁 Declarative Schema Structure

Live declarative SQL definitions reside in `supabase/schemas/`:

* `_extensions.sql`: Database extensions (`uuid-ossp`, `pgcrypto`, etc.).
* `public.sql`: Master active declarative public schema for un-split modules.
* **Modular Domain Folders** (`supabase/schemas/<domain>/`):
  * `01_types.sql`: Custom Postgres ENUMs and composite types.
  * `02_tables.sql`: Table DDL, column defaults, constraints, foreign keys, and indexes.
  * `03_rpcs.sql`: Stored procedures, business logic functions, and transactional RPCs.
  * `04_rls.sql`: Row Level Security policies.

---

## 🗺️ Domain Schema Split Tracker

Move one domain per change; delete moved objects from `public.sql` in the same change. Always run `pnpm run backend:schema:diff` before merge.

| Domain | Schema Folder | Status | Included Objects / Notes |
| :--- | :--- | :--- | :--- |
| **procurement** | `supabase/schemas/procurement/` | **Split** | Shipments, items, suppliers, purchase tracking |
| **shop_order** | `supabase/schemas/shop_order/` | **Split** | Shop orders, dropship order items, catalog orders |
| **notifications** | `supabase/schemas/notifications/` | **Split** | Inbox, preferences, push (`03_rls.sql`, `04_rpcs.sql`) |
| **tenants** | `supabase/schemas/tenants/` | Stub | Move from `public.sql` when changing that domain |
| **permissions** | `supabase/schemas/permissions/` | Stub | Grants / `has_module_action` |
| **shop** | `supabase/schemas/shop/` | Stub | Shop config tables still overlapping shop_order split |
| **tag** | `supabase/schemas/tag/` | Stub | Taxonomy |
| **sales_invoice** | `supabase/schemas/sales_invoice/` | **Split** | Sales invoices, line items, billing RPCs |
| **wallet** | `supabase/schemas/wallet/` | Pending | `universal_wallet_ledger`, customer/vendor balance books |
| **customer** | `supabase/schemas/customer/` | Pending | Customer accounts, addresses, credit profiles |
| **products** | `supabase/schemas/products/` | Pending | Products catalog, variations, tags, categories |
| **reporting** | `supabase/schemas/reporting/` | Pending | Treasury, profit reports, COD reconciliation RPCs |
| **thrift** | `supabase/schemas/thrift/` | Pending | Thrift vertical lots, processing, items |
| **investor** | `supabase/schemas/investor/` | Pending | Investor portal, capital accounts, profit payouts |
| **global_reference** | `supabase/schemas/global_reference/` | Pending | App settings, courier configs, soft-delete recovery |

---

## ⚡ Core Rules for Schema Changes

1. **Declarative Source of Truth**: Always modify `supabase/schemas/` first, then generate migrations using:
   ```bash
   pnpm exec supabase db diff -f <migration_name>
   ```
2. **RPC Migrations**: When creating RPC migrations in `supabase/migrations/`, **ALWAYS** copy the function body directly from `supabase/schemas/<domain>/03_rpcs.sql`, never from older historical migrations.
3. **Double-Entry Ledger Integrity**: Every financial transaction must be posted through `record_ledger_transaction(...)`. Never manipulate ledger balance rows directly.
4. **Local Verification**:
   ```bash
   pnpm run backend:local
   pnpm run backend:types:local
   ```

---

## Related docs
- [Documentation index](../docs/README.md)
- [How to write docs](../docs/STRUCTURE.md)
- [Database conventions](../docs/architecture/database.md)
