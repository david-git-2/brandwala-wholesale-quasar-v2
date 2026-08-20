# Universal Multi-Currency Wallet Ledger Architecture

> **Single Source of Truth** for the generalized Wallet/Ledger system, replacing rigid feature-specific financial trackers.

## 1. Executive Summary & Value Proposition

To track complex financial flows reliably, Brandwala adopts an enterprise-standard **Universal Ledger** architecture (often presented to users as a "Wallet").

**Value Proposition:**
- **Zero Drift:** By using a true single/double-entry ledger instead of independent tracking tables, the system guarantees mathematical certainty across all entities.
- **Unified UX:** A single `<UniversalWallet />` component scales across Admin, Vendor, Courier, and Middleman dashboards, significantly reducing frontend duplication.
- **Future-Proof Extensibility:** Built-in multi-currency, exchange rate lock-ins, and flexible tagging prepare the platform for global expansion without database migrations.

**The Core Rule: Every entity on the platform (Tenant, Courier, Middleman, Vendor, Customer, Investor, Cargo Company) gets exactly **ONE** wallet identified by `entity_type` + `entity_id`.
A single wallet only tracks *its own money*. It does not track what it owes to others. **Tags never identify the wallet owner** — see §4 and [UNIVERSAL_TAGGING_SYSTEM.md](../tag/UNIVERSAL_TAGGING_SYSTEM.md).

### Answering Business Questions via Wallets:
- **"What do I have?"** $\rightarrow$ Check the balance of the Tenant Wallet.
- **"Who owes me money?"** $\rightarrow$ Check the balances of Courier or Customer Wallets (Negative/Owed balances).
- **"Who do I owe?"** $\rightarrow$ Check the balances of Middleman or Vendor Wallets (Positive/Payable balances).
- **"What have I spent?"** $\rightarrow$ Sum the `debit` transactions inside the Tenant Wallet.

---

## 2. Real-World Use Cases Handled Natively

Because the system relies on permanent Double-Entry / Single-Entry ledger mathematics, complex edge cases are handled automatically without custom code.

1. **Customer Debt (Buy Now, Pay Later):**
   - Customer orders item $\rightarrow$ Product shipped.
   - Wallet Action: `- 5,000 TK` (Debit).
   - Result: Customer wallet goes negative (Debt).
   
2. **Vendor Overpayment / Advance:**
   - Pay Vendor 10,000 TK, but receive 8,000 TK of goods.
   - Wallet Action: `+ 2,000 TK` (Credit).
   - Result: Vendor wallet goes positive (They hold our money). Next purchase deducts from this balance.

3. **Courier Cash Collection:**
   - Courier delivers COD order.
   - Wallet Action: `+ 1,200 TK` (Credit) added to Courier's wallet (They owe us).
   - When Courier remits cash to bank: `- 1,200 TK` (Debit) on Courier Wallet, `+ 1,200 TK` on Tenant Wallet.

4. **Shipment purchase (procurement handoff):**
   - Pay vendor $4,000 + cargo $1,000 for an inbound shipment.
   - Wallet Action: Debit **Tenant** (cash out); settle **Vendor** / **Cargo agent** (`cargo_company`) wallets.
   - Shipment is **not** a wallet owner — use `source_type = 'shipment'` (or `vendor_purchase`) + `source_id = shipment.id`.
   - Costing (landed cost) lives on `shipment_cost_entries`; wallet is optional day one. See [PROCUREMENT_STOCK_ISSUES.md](../PROCUREMENT_STOCK_ISSUES.md) §3.

5. **Vendor return for store credit (not cash):**
   - Return goods after payment; vendor issues credit instead of refunding cash.
   - Wallet Action: Credit **Vendor** wallet (they hold our value). **Do not** credit Tenant cash.
   - Stock qty decreases separately. Next purchase from that vendor consumes the credit balance first.
   - Cash refund path: Credit Tenant (+ clear vendor) instead.

### Dropship 3-Step Wallet Posting Matrix

| Step | Trigger Action | Courier Wallet | Tenant Wallet | Middleman Wallet | Notes |
|---|---|---|---|---|---|
| **1. Delivered Costing** | Confirm COD & delivery charge | `+ COD net` (Credit/Owed) | — | — | Courier holds collected COD cash |
| **2. Courier Remittance** | Courier deposits cash to Tenant | `- Remitted` (Debit) | `+ Remitted` (Credit) | `+ Profit` (Credit/Payable) | Cash lands in Tenant; Middleman profit payable is opened |
| **3. Tenant Payout** | Tenant pays Middleman profit | — | `- Payout` (Debit) | `- Payout` (Debit) | Settlement clears Middleman payable balance |

---

## 3. The Universal Data Model & Backend Architecture

This unified table (`universal_wallet_ledger`) replaces any need for separate "Courier Debt", "Vendor Advance", or "Customer Credit" tables.

| Column Name | Data Type | Description |
| :--- | :--- | :--- |
| **`id`** | `uuid` (PK) | Unique transaction identifier. |
| **`tenant_id`** | `bigint` (FK) | Identifies the organization/store. |
| **`entity_type`** | `text` | The owner category (`'customer'`, `'vendor'`, `'courier'`, `'middleman'`, `'tenant'`, `'investor'`, `'cargo_company'`). |
| **`entity_id`** | `bigint` | The specific ID of the owner. |
| **`type`** | `text` | `CHECK IN ('credit', 'debit')` - Money IN or Money OUT. |
| **`amount`** | `numeric(15,4)` | The raw transaction amount in the local currency (must be positive). |
| **`currency_code`** | `text` | e.g., `'BDT'`, `'USD'`, `'CNY'`. |
| **`exchange_rate`** | `numeric(15,6)`| The rate against base currency at the *exact moment* of the transaction. |
| **`base_amount`** | `numeric(15,4)`| `amount * exchange_rate`. Standardizes reporting across the platform. |
| **`balance_after`** | `numeric(15,4)`| Running balance of this wallet after this transaction. (Ensures 0.001s queries). |
| **`source_type`** | `text` | What triggered this? (`'shop_order'`, `'vendor_purchase'`, `'shipment'`, `'shipment_return'`, `'payout'`, `'adjustment'`). **Not** the wallet owner. |
| **`source_id`** | `text` | The ID of the trigger (e.g., Order #1234, shipment id). |
| **`metadata`** | `jsonb` | Optional dimensions / audit fields (See Section 4). **Not** wallet identity. |
| **`created_at`** | `timestamptz` | Exact time the transaction was recorded. |

### Supabase Architecture & Best Practices
- **Strict RLS & Client Restrictions:** Client applications must NEVER have direct `INSERT`, `UPDATE`, or `DELETE` access to the ledger table. Data modification must occur entirely through secure Postgres RPCs that enforce business logic, authorization, and calculate `balance_after` atomically.
- **Atomic Database Transactions:** Multi-wallet operations (e.g., Courier handing cash to Tenant) must be encapsulated in a single backend RPC transaction block to prevent partial execution failures.
- **Index Optimization:** A composite index on `(tenant_id, entity_type, entity_id, created_at DESC)` ensures lightning-fast queries for `<UniversalWallet />` data fetching and running balance updates.

---

## 4. Classification vs Identity (Tags & Metadata)

### Locked Rule

| Concern | Column / System | Example |
| :--- | :--- | :--- |
| **Whose wallet?** | `entity_type` + `entity_id` | `middleman` + billing_profile `12` |
| **What triggered it?** | `source_type` + `source_id` | `shop_order` + `1234` |
| **Optional dimension** | `metadata` now; universal tags later | expense bucket, campaign, trx id |

**Never** use a tag (or a free-text label) as the wallet owner. Tags do not identify entities; they classify ledger rows or other records. Full rules: [UNIVERSAL_TAGGING_SYSTEM.md](../tag/UNIVERSAL_TAGGING_SYSTEM.md).

### Interim: `metadata jsonb` on Ledger Rows

Until the shared `tags` + `entity_tags` engine ships, light tracking categories live on the ledger row:

```json
{
  "tags": ["eid_sale", "facebook_ads", "dhaka_region"],
  "approved_by": "admin_uuid",
  "trx_id": "bKash_9XF34..."
}
```

- Good for ad-hoc P&L slices and audit fields without migrations.
- When universal tagging ships, prefer linking ledger rows via `entity_tags` (`entity_type = 'wallet_ledger'`).

---

## 5. UI Architecture & Feature Blueprint: `<UniversalWallet />`

The Frontend UI provides a minimal, clutter-free financial command center. The layout strictly consists of **3 key areas**:

```
┌────────────────────────────────────────────────────────────────────────┐
│ 1. ACTION TOOLBAR:  [ Pay ]   [ Deposit ]   [ Credit ]   [ Withdraw ]  │
├────────────────────────────────────────────────────────────────────────┤
│ 2. WALLET BALANCE CARD:  Available Balance (৳ BDT + Foreign FX values) │
├────────────────────────────────────────────────────────────────────────┤
│ 3. TRANSACTION LEDGER:   Full chronological table (Date, Type, Rate,   │
│                          Amount, Balance After, Reference & Notes)     │
└────────────────────────────────────────────────────────────────────────┘
```

### Component Structure & Layout Integration
Following `.agents/rules/table_list_design_system.md` and the **Rule of 3**, the `<UniversalWallet :entityType="..." :entityId="..." />` component acts as the container, assembling these distinct visual blocks:

1. **`<UniversalWalletHeader />`**: Compact header displaying entity avatar, name, and owner type.
2. **`<WalletActionToolbar />`**: The 4 primary action buttons (`rounded-borders` 8px radius):
   - **`[ Pay ]`**: Real cash out (settle bills/invoices/vendor payments).
   - **`[ Deposit ]`**: Real cash in (bank/cash top-up or customer advance).
   - **`[ Credit ]`**: Store credit management (Record incoming credit from vendor/customer or use/apply existing store credit).
   - **`[ Withdraw ]`**: Cash payout to external bank account or mobile wallet.
3. **`<WalletBalanceCard />`**: Single consolidated balance card boldly showing live `available_balance`, along with foreign currency preview and secondary chips for `pending_balance` and `locked_balance` when non-zero.
4. **`<UniversalWalletLedgerTable />`**: Quasar internal-scrolling data table (`calc(100vh - 280px)`) displaying ledger rows chronologically:
   - Date & Time
   - Action / Type badge (`text-positive` for credit $+$, `text-negative` for debit $-$)
   - Transaction Amount (with currency symbol)
   - Exchange Rate locked at transaction time
   - Converted Base Amount (BDT)
   - Snapshot `balance_after`
   - Trigger / Source Reference & Notes

*Note: All business math (e.g., calculating totals, currency conversions) must be extracted into composables (`composables/useWalletMath.ts`). The Vue templates remain strictly presentational.*

### Skeleton Loaders (Zero CLS)
- A dedicated `<UniversalWalletSkeleton />` component mirrors the 4-button bar, balance card, and tabular layout natively. No layout jumps occur on data load.

### State Management & Error Handling
Following `docs/TANSTACK_QUERY_GUIDE.md` and `docs/ERROR_AND_SUCCESS_MESSAGE_GUIDE.md`:

- **Query Keys (`walletQueryKeys.ts`):** 
  ```typescript
  ledgerList: (params: { tenantId: number, entityType: string, entityId: string }) => 
    ['wallet', 'ledgerList', params] as const
  ```
- **Query Composables (`useWalletQuery.ts`):** 
  - Abstract `useQuery` fetches to the Supabase repository.
  - *Crucial Rule:* Queries **NEVER** trigger success toasts on load.
  - Any fetch errors are parsed using `showErrorNotification(parseSupabaseError(error, 'Failed to load ledger data.'))`.
- **Mutation Composables (`useWalletMutations.ts`):**
  - Adjustments (e.g., manual corrections by an admin) call `useAdjustWalletBalanceMutation()`.
  - On success: Must trigger a frontend-driven success notification (`showSuccessNotification('Wallet balance adjusted successfully.')`) and call `queryClient.invalidateQueries` to automatically refetch the ledger.
  - On error: Must parse technical backend errors (e.g., RLS rejections) using `showErrorNotification(parseSupabaseError(error, 'Failed to adjust balance.'))`. Users must never see raw Postgres errors.

---

## 6. Implementation Phases

### Phase 1: Database Schema & RPCs
**Goal:** Create the `universal_wallet_ledger` table, apply RLS, and expose secure RPCs for inserting transactions.
**Depends On:** None
**Files to Change:**
- `supabase/migrations/20261220000000_create_universal_wallet_ledger.sql`

**Specification:**
- Create the `universal_wallet_ledger` table with all columns defined in Section 3.
- Enforce strict RLS policies: Allow `SELECT` for authenticated users where `tenant_id` matches the user's active context and `entity_id` matches their allowed profiles, and block all direct `INSERT/UPDATE/DELETE`.
- Create a Postgres RPC `record_ledger_transaction(tenant_id, entity_type, entity_id, type, amount, currency, ...)` that calculates `balance_after` and inserts the row atomically.
- Create a composite index on `(tenant_id, entity_type, entity_id, created_at DESC)`.

**Rollback:** Execute `DROP FUNCTION record_ledger_transaction; DROP TABLE universal_wallet_ledger;` via Supabase SQL editor or down migration.
**Review Gate:** Verify table schema, constraints, and RPC signature via Supabase Dashboard.
**Status:** [Completed]

### Phase 2: Frontend API Repository & TanStack Composables
**Goal:** Build the frontend data access layer to interact with the Wallet Supabase RPCs and tables.
**Depends On:** Phase 1
**Files to Change:**
- `web/src/modules/wallet/repositories/walletRepository.ts`
- `web/src/modules/wallet/shared/queryKeys/walletQueryKeys.ts`
- `web/src/modules/wallet/composables/useWalletQuery.ts`
- `web/src/modules/wallet/composables/useWalletMutations.ts`
- `web/src/modules/wallet/composables/useWalletMath.ts`

**Specification:**
- Create `walletRepository.ts` to wrap Supabase `.rpc()` and `.select()` calls.
- Define `ledgerList` query keys in `walletQueryKeys.ts`.
- Implement `useWalletQuery` integrating `walletRepository` and ensuring NO success toasts are triggered (per Error Guide).
- Implement `useAdjustWalletBalanceMutation` integrating `showSuccessNotification` on success and `parseSupabaseError` on failure (per Error Guide).
- Create `useWalletMath.ts` to export utility functions for summing debits/credits.

**Rollback:** Delete the created TypeScript files inside `web/src/modules/wallet/`.
**Review Gate:** Review TypeScript interfaces, query key stability, and proper error/success message parsing.
**Status:** [Completed]

### Phase 3: UI Skeletons & Presentational Components
**Goal:** Build the isolated Vue sub-components and skeleton loaders strictly adhering to the max 150-line rule.
**Depends On:** Phase 2
**Files to Change:**
- `web/src/modules/wallet/components/skeletons/UniversalWalletSkeleton.vue`
- `web/src/modules/wallet/components/UniversalWalletHeader.vue`
- `web/src/modules/wallet/components/UniversalWalletToolbar.vue`
- `web/src/modules/wallet/components/UniversalWalletKPICards.vue`
- `web/src/modules/wallet/components/UniversalWalletLedgerTable.vue`

**Specification:**
- Create `UniversalWalletSkeleton.vue` using Quasar `q-skeleton` elements simulating exactly the KPIs and Table to achieve Zero CLS.
- Build `UniversalWalletHeader.vue` accepting `entityType` and `entityName` props.
- Build `UniversalWalletKPICards.vue` to display balance, debits, and credits.
- Build `UniversalWalletLedgerTable.vue` with columns matching the data model, utilizing `text-positive` and `text-negative` for debit/credit clarity.

**Rollback:** Delete the `.vue` component files.
**Review Gate:** Visual review of components in isolation or via a scratchpad to verify styling and Skeleton CLS rules.
**Status:** [Completed]

### Phase 4: Container Assembly & Wiring
**Goal:** Assemble the sub-components into the parent `<UniversalWallet />` and connect TanStack data fetching.
**Depends On:** Phase 3
**Files to Change:**
- `web/src/modules/wallet/components/UniversalWallet.vue`

**Specification:**
- Create the `UniversalWallet.vue` container component (max 300 lines).
- Consume `useWalletQuery` based on the passed `:entityType` and `:entityId` props.
- Conditionally render `<UniversalWalletSkeleton>` while `isLoading`.
- Pass fetched data to `<UniversalWalletHeader>`, `<UniversalWalletKPICards>`, and `<UniversalWalletLedgerTable>`.

**Rollback:** Revert changes to or delete `UniversalWallet.vue`.
**Review Gate:** Verify end-to-end functionality (loading states, accurate totals, data rendering).
**Status:** [Completed]
