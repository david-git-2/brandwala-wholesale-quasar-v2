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

* **Action**: System records a money movement (credit or debit) triggered by shop orders, vendor purchases, payouts, adjustments, or intercompany operations.
* **Execution**: Atomic RPC function inserts an immutable entry into `universal_wallet_ledger` and updates the target bucket in `wallet_accounts`.
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

* **Action**: Tenant admins or accountants view platform-wide financial summaries, liabilities, receivables, or download detailed entity statements.
* **Execution**: Aggregate queries calculate total platform cash, courier COD holdings, vendor payables, and generate date-filtered ledger export data.
* **APIs / RPCs Used**:
  * [get_wallet_dashboard_summary.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/wallet/rpc/get_wallet_dashboard_summary.md) (`supabase.rpc('get_wallet_dashboard_summary', ...)` )
  * [get_wallet_entity_statement.md](file:///Users/daviditc/Documents/personal_projects/brandwala-wholesale-quasar-v2/doc/v2/wallet/rpc/get_wallet_entity_statement.md) (`supabase.rpc('get_wallet_entity_statement', ...)`)
