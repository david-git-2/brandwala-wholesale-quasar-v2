# Wallet Lifecycle & Workflow Specification

This document details the step-by-step business flow and maps each lifecycle stage to its corresponding APIs and RPCs for the Universal Wallet system.

---

## Lifecycle Overview

```
[ STAGE 1: ACCOUNT INQUIRY & BALANCES ] ➔ [ STAGE 2: LEDGER TRANSACTION ] ➔ [ STAGE 3: BUCKET TRANSFERS ] ➔ [ STAGE 4: DASHBOARD & STATEMENTS ]
  • RPC: get_wallet_account_balances     • RPC: record_ledger_transaction   • RPC: transfer_wallet_balance    • RPC: get_wallet_dashboard_summary
  • API: wallet_accounts select          • API: universal_wallet_ledger    • Bucket state transitions        • RPC: get_wallet_entity_statement
```

---

## Stage 1: Account Inquiry & Balance Bucket Fetching

* **Action**: User or module fetches the current balance buckets for an entity (Vendor, Courier, Customer, Middleman, Tenant, Investor).
* **Execution**: Retrieves `available_balance`, `locked_balance`, and `pending_balance` along with total balance.
* **APIs / RPCs Used**:
  * [get_wallet_account_balances.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/wallet/rpc/get_wallet_account_balances.md) (`supabase.rpc('get_wallet_account_balances', ...)`)
  * [wallet_account_api.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/wallet/api/wallet_account_api.md) (`supabase.from('wallet_accounts').select(...)`)

---

## Stage 2: Ledger Transaction & Atomic Balance Mutation

* **Action**: System records a money movement (credit or debit) triggered by shop orders, vendor purchases, **inbound shipments**, shipment returns, **desk sales invoices**, sales returns, payouts, adjustments, or intercompany operations.
* **Execution**: Atomic RPC function inserts an immutable entry into `universal_wallet_ledger` and updates the target bucket in `wallet_accounts`. *(**Concurrency Note**: The underlying PostgreSQL RPC must utilize row-level locks via `SELECT ... FOR UPDATE` or direct atomic increments to prevent race conditions during high-concurrency balance updates.)*
* **Shipment rule**: Wallets belong to **tenant / vendor / cargo agent** — never the shipment. Use `source_type` ∈ (`shipment`, `shipment_return`, `vendor_purchase`) + `source_id`.
* **Shipment day one ([issues §3](../../PROCUREMENT_STOCK_ISSUES.md)):** Finalize and cost revision **do not** call this stage. Ledger rows for procurement cash/credit come only from a later **Pay / Settle** (or return) action — not from receive.
* **Desk sales rule**: Wallets belong to **tenant / billing profile (customer) / middleman** — never “the invoice” as an entity. Use `source_type = 'sales_invoice'` + `source_id = sales_invoices.id` (or `'sales_invoice_return'` + return id).
* **Desk sales day one ([invoice schema §5.2](../invoice/schema.md)):** Post invoice **does not** call this stage (stub-skip receivable). Ledger rows come only from explicit **Pay / allocate** (or refund after return) — same pattern as shipment Pay / Settle.
* **APIs / RPCs Used**:
  * [record_ledger_transaction.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/wallet/rpc/record_ledger_transaction.md) (`supabase.rpc('record_ledger_transaction', ...)`)
  * [universal_wallet_ledger_api.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/wallet/api/universal_wallet_ledger_api.md) (`supabase.from('universal_wallet_ledger').select(...)`)

---

## Stage 3: Bucket Transfer & Hold Management

* **Action**: Internal movement of funds between balance buckets (e.g. `pending` &rarr; `available` upon delivery, or `available` &rarr; `locked` during escrow).
* **Execution**: Atomic RPC adjusts balance buckets within `wallet_accounts` without affecting net total entity balance unless specified.
* **APIs / RPCs Used**:
  * [transfer_wallet_balance.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/wallet/rpc/transfer_wallet_balance.md) (`supabase.rpc('transfer_wallet_balance', ...)`)

---

## Stage 4: Dashboard Aggregations & Statement Reports

* **Action**: Standard users view their simplified financial dashboard, advanced users download itemized statements, and Tenant Admins view platform-wide financial totals.
* **Execution**: 
  * The "Presentation Engine" RPC aggregates data into plain-English metrics for frontend users.
  * Aggregate queries calculate total platform cash, vendor payables, and generate date-filtered ledger exports.
* **APIs / RPCs Used**:
  * [get_wallet_minimal_summary.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/wallet/rpc/get_wallet_minimal_summary.md) (`supabase.rpc('get_wallet_minimal_summary', ...)`) - *Minimal User Dashboard*
  * [get_wallet_entity_statement.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/wallet/rpc/get_wallet_entity_statement.md) (`supabase.rpc('get_wallet_entity_statement', ...)`) - *Advanced Ledger View*
  * [get_wallet_dashboard_summary.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/wallet/rpc/get_wallet_dashboard_summary.md) (`supabase.rpc('get_wallet_dashboard_summary', ...)` ) - *Tenant Admin View*
