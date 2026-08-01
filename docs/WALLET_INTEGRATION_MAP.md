# Wallet Integration Map — Priority Task List

> This document is the **authoritative audit + priority-ordered task list** for connecting the Universal Wallet across all modules. It identifies what's wired, what's wired **wrong**, and what's missing — ordered by implementation priority.

---

## 🎯 Master Priority Implementation Order Roadmap

| Phase | Priority Level | Focus Area | Task Scope | Rationale / Target |
|:---|:---|:---|:---|:---|
| **Phase 0** | 🔴 **CRITICAL (P0)** | **Fix Existing SQL & UI Bugs** | P0.1 – P0.4 | Fix entity type split (`middleman` vs `customer`), kill legacy dual-writes, fix courier ID 0, and fix FinanceHub reading raw ledger instead of `wallet_accounts`. |
| **Phase 1** | 🟠 **HIGH (P1)** | **Order Lifecycle (shop_order)** | P1.1 – P1.2 | Extend delivery accruals & AR invoice booking to non-dropship (wholesale & retail) orders. |
| **Phase 2** | 🟡 **HIGH (P2)** | **Invoice & Payments (sales_invoice)** | P2.1 – P2.4 | Wire billing profile payments, direct cash collections, settlement discounts, and non-dropship returns into `wallet_accounts`. |
| **Phase 3** | 🔵 **MEDIUM (P3)** | **Procurement & Vendors (procurement_stock & vendor)** | P3.1 – P3.2 | Wire stock inbound GRN to vendor Accounts Payable (AP) and build vendor payment outflow tracking. |
| **Phase 4** | 🟣 **MEDIUM (P4)** | **Treasury Analytics (reporting_treasury & UI)** | P4.1 – P4.3 | Migrate Treasury Dashboard, Billing Balances, and Merchant Wallet UI to read exclusively from `wallet_accounts`. |
| **Phase 5** | 🟢 **LOW (P5)** | **Capital & Investments (investor_capital)** | P5.1 – P5.3 | Connect investor capital injections, capital withdrawals, and shipment profit distributions. |

---

## Architecture Health Check

### What Exists Today

| Layer | Status |
|:------|:-------|
| **`wallet_accounts` table** (3-bucket materialized balances) | ✅ Created |
| **`universal_wallet_ledger` table** (immutable append-only audit trail) | ✅ Created |
| **`record_ledger_transaction` RPC** (atomic ledger + wallet_accounts update) | ✅ Created — updates **both** UWL + wallet_accounts |
| **`transfer_wallet_balance` RPC** (bucket-to-bucket shift) | ✅ Created |
| **`get_wallet_account_balances` RPC** (O(1) balance read) | ✅ Created |
| **`get_wallet_dashboard_summary` RPC** (aggregate metrics from wallet_accounts) | ✅ Created |
| **`get_wallet_entity_statement` RPC** (date-range statement) | ✅ Created |
| **Legacy `billing_profile_wallet_ledger` table** | ⚠️ Still dual-written by some RPCs |

---

## Audit of Currently Wired Connections

### ✅ Correctly Wired

| # | RPC Name | Trigger | Wallet Entries | Verdict |
|:--|:---------|:--------|:---------------|:--------|
| 1 | `confirm_dropship_delivered_costing` | Order → `delivered` | Credit courier `pending` (COD holding) | ✅ **Correct** — idempotent, credits courier entity with COD amount |
| 2 | `confirm_courier_remittance_to_tenant` | Staff confirms courier cash remittance | Debit courier `pending`, Credit tenant `available`, Credit middleman/customer profit | ✅ **Correct** — 3-leg atomic transaction |
| 3 | `record_dropship_courier_remittance` | Newer version of #2 (unified) | Same 3-leg + global_payment creation + invoice paid_amount update | ✅ **Correct** — replaces #2 with invoice allocation |
| 4 | `dispense_middleman_payout_from_tenant` | Staff pays merchant profit out | Debit tenant `available`, Debit middleman/customer `available` | ✅ **Correct** — dual debit atomic payout |
| 5 | `ensure_dropship_invoice_billed_entry` | Invoice posted for dropship order | Debit customer `available` (AR) | ✅ **Correct** — records accounts receivable |
| 6 | `finalize_dropship_return` | Staff finalizes product return | Revenue/profit clawback entries | ✅ **Correct** — reverses profit + revenue on return |

### ⚠️ Wired But With Issues

| # | Issue | Location | Problem | Impact |
|:--|:------|:---------|:--------|:-------|
| **A** | **Entity type mismatch** | `confirm_courier_remittance_to_tenant` writes `entity_type = 'middleman'` for profit, but `ensure_dropship_invoice_billed_entry` writes `entity_type = 'customer'` for the same billing_profile | **Split wallet identity** — a billing profile has entries under both `middleman` AND `customer` entity types | Balance calculation breaks: `wallet_accounts` has separate rows for `middleman:42` and `customer:42` for the same billing profile |
| **B** | **Backfill migration exists but may not cover all data** | Migration `20270131000000` attempted to unify `middleman` → `customer` | If new orders still trigger the old `confirm_courier_remittance_to_tenant` (not the newer `record_dropship_courier_remittance`), fresh `middleman` entries are still being created | Ongoing data divergence |
| **C** | **Legacy dual-write** | `confirm_courier_remittance_to_tenant` and `dispense_middleman_payout_from_tenant` still write to `billing_profile_wallet_ledger` | Redundant writes to deprecated table | Extra DB load, risk of stale legacy reads |
| **D** | **Courier entity_id always 0** | `confirm_dropship_delivered_costing` and `process_dropship_courier_remittance_uwl` both use `v_courier_id := 0` | All courier COD holdings aggregate into a single `courier:0` wallet row regardless of which courier service delivered | Cannot track per-courier balances; Courier A and Courier B share one wallet |
| **E** | **FinanceHub KPIs read from raw ledger, not wallet_accounts** | `dropshipFinanceRepository.ts` → `getHubData()` fetches ALL `universal_wallet_ledger` rows and sums in JS | Bypasses `wallet_accounts` materialized balances; scans entire ledger on every page load | Performance degrades linearly with ledger growth; **violates single source of truth** |
| **F** | **Merchant Wallet Page reads from custom RPC, not `get_wallet_account_balances`** | `merchantWalletRepository.ts` → `get_my_dropship_wallet_summary` RPC | Separate read path from the canonical `wallet_accounts` RPC | May drift from `wallet_accounts` materialized balances if they diverge |

---

## Detailed Task Breakdown

### P0 — Fix Existing Wiring Bugs (Must Do First)

#### P0.1 — Unify Entity Type: `middleman` → `customer`
- **Problem**: Profit entries use `entity_type = 'middleman'`, but invoice/AR entries use `entity_type = 'customer'` for the same `billing_profile_id`. This splits one entity into two wallet_accounts rows.
- **Files**:
  - `supabase/migrations/20260728202727_dropship_finance_hub_wallet_flow.sql` — `confirm_courier_remittance_to_tenant()` lines 271-285 write `'middleman'`
  - `supabase/migrations/20260728202727_dropship_finance_hub_wallet_flow.sql` — `dispense_middleman_payout_from_tenant()` lines 404-419 write `'middleman'`
- **Fix**: Update all remaining RPCs to use `entity_type = 'customer'` exclusively. Run backfill to merge any `middleman` wallet_accounts rows into `customer`.
- **Impact**: Until fixed, merchant balance reads are **incorrect**.

#### P0.2 — Retire Legacy Dual-Write to `billing_profile_wallet_ledger`
- **Problem**: Two RPCs still dual-write to the deprecated `billing_profile_wallet_ledger` table.
- **Files**:
  - `confirm_courier_remittance_to_tenant()` — line 292: `record_wallet_ledger_entry()`
  - `dispense_middleman_payout_from_tenant()` — line 422: `record_wallet_ledger_entry()`
- **Fix**: Remove `record_wallet_ledger_entry` calls. Ensure MerchantWalletPage reads from `wallet_accounts` / `universal_wallet_ledger` only.

#### P0.3 — Fix Courier `entity_id` Always 0
- **Problem**: All courier entries use `entity_id = 0` regardless of which courier service. Cannot track per-courier COD balances.
- **Files**:
  - `confirm_dropship_delivered_costing()` — line 69-72
  - `process_dropship_courier_remittance_uwl()` — line 37
- **Fix**: Map `courier_service_id` (UUID) to a stable numeric ID or use `courier_services.id::bigint`. If courier entities are not needed for balance tracking, document this as intentional.

#### P0.4 — FinanceHub KPIs Must Read from `wallet_accounts`, Not Raw Ledger
- **Problem**: `dropshipFinanceRepository.ts` → `getHubData()` fetches ALL `universal_wallet_ledger` rows and sums them in JavaScript on every page load.
- **File**: `web/src/modules/shop_order/repositories/dropshipFinanceRepository.ts` lines 46-73
- **Fix**: Replace with single call to `get_wallet_dashboard_summary` RPC (already exists, reads from `wallet_accounts` in O(1)).

---

### P1 — Core Revenue Cycle (Dropship is already wired; verify Non-Dropship)

#### P1.1 — Non-Dropship (Wholesale/Retail) Order Delivery Accrual
- **Module**: `shop_order` — wholesale and retail order types
- **Current State**: Only dropship orders trigger wallet entries. Wholesale/retail orders do NOT create any wallet entries when delivered.
- **What's Needed**: When a wholesale/retail order is delivered and payment is collected, record tenant bank cash received.
- **RPC**: `record_ledger_transaction` → `entity_type: 'tenant'`, `type: 'credit'`, `target_bucket: 'available'`

#### P1.2 — Non-Dropship Order Fulfillment → Invoice Payment Recording
- **Module**: `shop_order` → `fulfillOrderToInvoice()`
- **Current State**: Creates a `global_invoice` but does NOT record wallet entries.
- **What's Needed**: When a wholesale order is fulfilled and converted to invoice, if it's a billing_profile-based order, record the AR (accounts receivable) entry.
- **RPC**: `record_ledger_transaction` → `entity_type: 'customer'`, `type: 'debit'`, `target_bucket: 'available'`, `source_type: 'sales_invoice'`

---

### P2 — Invoice & Payment Module (`sales_invoice`)

#### P2.1 — Billing Profile Payment Received
- **File**: `invoiceRepository.ts` → `recordBillingProfilePayment()` (calls `create_billing_profile_payment_with_allocations` RPC)
- **Current State**: Only updates `global_invoices.paid_amount` and creates `global_payments` row. **No wallet entry**.
- **What's Needed**: Credit tenant bank cash, debit customer AR.
- **RPCs to add inside existing SQL RPC**:
  - `record_ledger_transaction(entity_type='tenant', type='credit', target_bucket='available')` — cash in
  - `record_ledger_transaction(entity_type='customer', type='credit', target_bucket='available')` — reduce AR
- **`source_type`**: `'sales_invoice'`, **`source_id`**: `invoice_no`

#### P2.2 — Recipient Invoice Collection (Direct COD/Cash)
- **File**: `invoiceRepository.ts` → `recordRecipientInvoiceCollection()` (calls `record_recipient_invoice_collection` RPC)
- **Current State**: Only updates `global_invoices.paid_amount`. **No wallet entry**.
- **What's Needed**: Credit tenant bank cash.
- **RPC to add**: `record_ledger_transaction(entity_type='tenant', type='credit', target_bucket='available')`
- **Note**: For dropship orders, `record_dropship_courier_remittance` already handles this — so this only applies to non-dropship invoice collections.

#### P2.3 — Settlement Discount Applied
- **File**: `invoiceRepository.ts` → `applySettlementDiscount()` (calls `apply_global_invoice_settlement_discount` RPC)
- **Current State**: Only reduces `due_amount` on invoice. **No wallet entry**.
- **What's Needed**: Record revenue write-off so platform profit reporting is accurate.
- **RPC to add**: `record_ledger_transaction(entity_type='tenant', type='debit', target_bucket='available', metadata: {section: 'settlement_discount'})`

#### P2.4 — Non-Dropship Product Returns
- **File**: `invoiceRepository.ts` → `addGlobalReturnItem()` (calls `add_global_return_item` RPC)
- **Current State**: Dropship returns handled by `finalize_dropship_return` which IS wired. Non-dropship returns only update invoice quantities — **no wallet entry**.
- **What's Needed**: Reverse tenant revenue and optionally credit customer store credit.
- **RPCs to add**:
  - `record_ledger_transaction(entity_type='tenant', type='debit', source_type='sales_invoice', metadata: {section: 'return_refund'})`
  - Optionally: `record_ledger_transaction(entity_type='customer', type='credit')` for store credit

---

### P3 — Procurement & Vendor

#### P3.1 — Inbound Shipment Received (Vendor Payable)
- **Module**: `procurement_stock`
- **File**: `InboundShipmentDetailsPage.vue` — when shipment status is marked received
- **Current State**: Only creates stock records. **No wallet entry**.
- **What's Needed**: Record accounts payable to vendor.
- **RPC**: `record_ledger_transaction(entity_type='vendor', type='credit', target_bucket='available', source_type='vendor_purchase')`

#### P3.2 — Vendor Payment Made
- **Module**: `vendor`
- **File**: `vendorService.ts` — **No payment recording function exists at all**
- **Current State**: Vendor module has CRUD for vendor profiles only. Cannot record payments.
- **What's Needed**: New service function + RPC call to settle vendor AP and debit platform cash.
- **RPCs**:
  - `record_ledger_transaction(entity_type='vendor', type='debit', target_bucket='available')` — reduce AP
  - `record_ledger_transaction(entity_type='tenant', type='debit', target_bucket='available')` — cash outflow

---

### P4 — Treasury & Reporting (Read Path)

#### P4.1 — Treasury Dashboard Should Read from `wallet_accounts`
- **Module**: `reporting_treasury`
- **File**: `treasuryRepository.ts` → `getParentDashboard()`
- **Current State**: Computes KPIs from operational tables (`global_invoices`, `global_payments`). Does NOT use `wallet_accounts`.
- **What's Needed**: Replace or supplement with `get_wallet_dashboard_summary` RPC reads.

#### P4.2 — Billing Balances Page Should Include Wallet Balances
- **Module**: `reporting_treasury`
- **File**: `treasuryRepository.ts` → `listBillingBalances()`
- **Current State**: Shows billing profile outstanding from invoice totals. Does not show wallet `available_balance` / `pending_balance`.
- **What's Needed**: Join or supplement with per-entity `wallet_accounts` data.

#### P4.3 — Merchant Wallet Page Should Read from Canonical RPCs
- **Module**: `shop_order`
- **File**: `merchantWalletRepository.ts` → calls `get_my_dropship_wallet_summary`
- **Current State**: Uses its own custom RPC instead of canonical `get_wallet_account_balances`.
- **What's Needed**: Migrate to call `get_wallet_account_balances` for consistency.

---

### P5 — Investor Capital Module

#### P5.1 — Capital In (Investor Deposits)
- **Module**: `investor_capital`
- **File**: `investorCapitalRepository.ts` → `recordCapitalIn()` (calls `record_investor_capital_in` RPC)
- **Current State**: Records in `investor_transactions` table only. **No wallet entry**.
- **What's Needed**: Credit tenant bank cash + track capital owed to investor.
- **New entity type needed**: `investor`
- **RPCs**:
  - `record_ledger_transaction(entity_type='tenant', type='credit', target_bucket='available')`
  - `record_ledger_transaction(entity_type='investor', type='credit', target_bucket='available')`

#### P5.2 — Investor Withdrawal Paid
- **File**: `investorCapitalRepository.ts` → `recordWithdrawalPaid()` (calls `record_investor_withdrawal_paid` RPC)
- **Current State**: Records in `investor_transactions` only. **No wallet entry**.
- **RPCs**:
  - `record_ledger_transaction(entity_type='investor', type='debit', target_bucket='available')`
  - `record_ledger_transaction(entity_type='tenant', type='debit', target_bucket='available')`

#### P5.3 — Shipment Profit Distribution
- **File**: `investorCapitalRepository.ts` → `refreshShipmentInvestorProfits()` (calls `refresh_shipment_investor_profits` RPC)
- **Current State**: Only updates `shipment_investments.profit_amount`. **No wallet entry**.
- **RPC**: `record_ledger_transaction(entity_type='investor', type='credit', target_bucket='pending')`

---

## Summary Scorecard

| Priority | Task ID | Module | What | Status |
|:---------|:--------|:-------|:-----|:-------|
| **P0.1** | Fix Entity Type | `shop_order` (SQL) | Unify `middleman` → `customer` in all RPCs | 🔴 Bug |
| **P0.2** | Kill Dual-Write | `shop_order` (SQL) | Remove `billing_profile_wallet_ledger` writes | 🔴 Bug |
| **P0.3** | Courier entity_id | `shop_order` (SQL) | Stop hardcoding `entity_id = 0` | 🟡 Design |
| **P0.4** | FinanceHub KPIs | `shop_order` (Frontend) | Read from `wallet_accounts` not raw ledger | 🔴 Perf Bug |
| **P1.1** | Non-Dropship Delivery | `shop_order` | Add wallet entry for wholesale/retail delivery | ❌ Missing |
| **P1.2** | Fulfill → Invoice AR | `shop_order` | Record AR on invoice creation | ❌ Missing |
| **P2.1** | Billing Payment | `sales_invoice` | Credit tenant + debit customer AR on payment | ❌ Missing |
| **P2.2** | Recipient Collection | `sales_invoice` | Credit tenant on direct cash collection | ❌ Missing |
| **P2.3** | Settlement Discount | `sales_invoice` | Record write-off in wallet | ❌ Missing |
| **P2.4** | Non-DS Returns | `sales_invoice` | Reverse revenue on non-dropship return | ❌ Missing |
| **P3.1** | Shipment Received | `procurement_stock` | Record vendor payable (AP) | ❌ Missing |
| **P3.2** | Vendor Payment | `vendor` | Settle AP + cash outflow | ❌ Missing |
| **P4.1** | Treasury Dashboard | `reporting_treasury` | Read from `wallet_accounts` | ⚠️ Partial |
| **P4.2** | Billing Balances | `reporting_treasury` | Include wallet balances | ⚠️ Partial |
| **P4.3** | Merchant Wallet | `shop_order` | Use canonical wallet RPCs | ⚠️ Partial |
| **P5.1** | Capital In | `investor_capital` | Credit tenant + investor | ❌ Missing |
| **P5.2** | Withdrawal Paid | `investor_capital` | Debit investor + tenant | ❌ Missing |
| **P5.3** | Profit Distribution | `investor_capital` | Credit investor pending | ❌ Missing |
