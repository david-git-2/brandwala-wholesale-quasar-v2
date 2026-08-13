# Feature Blueprint: Universal Wallet & Ledger System

## 1. User Story & Core Logic
As an admin, staff member, or tenant, I need a centralized, double-entry style wallet and transaction ledger system so that I can reliably track all cash, store credit, investor deposits, dropship profits, and payouts in a unified, mathematically sound manner without relying on fragmented, ad-hoc tables.

**Core Logic:**
- A single `wallets` table that acts as a generalized account balance repository for different entities (`tenant`, `billing_profile`, `investor_profile`, `courier_service`).
- A `wallet_transactions` table representing the true ledger of every debit and credit, maintaining a strict running balance.
- All core accounting workflows (dropship profits, retail cash collections, wholesale advance payments, bulk payouts) interact strictly via this unified API to ensure an uncorrupted source of truth.
- **Identity:** Wallet owner is always `owner_type` + `owner_id` (or ledger `entity_type` + `entity_id`). Tags are classification only and are out of scope for v1 of this feature — see [tag/UNIVERSAL_TAGGING_SYSTEM.md](tag/UNIVERSAL_TAGGING_SYSTEM.md) and [wallet/UNIVERSAL_WALLET_LEDGER.md](wallet/UNIVERSAL_WALLET_LEDGER.md).

## 2. Data Modeling & Database Schema
**New Tables:**

`public.wallets`
- `id`: uuid (PK)
- `tenant_id`: bigint (FK to tenants, null if it's a global platform wallet)
- `owner_type`: text (enum: 'tenant', 'billing_profile', 'investor_profile', 'courier_service')
- `owner_id`: bigint / uuid (ID corresponding to the owner_type)
- `balance`: numeric(12,2) (Current computed or strictly tracked balance)
- `created_at`: timestamptz
- `updated_at`: timestamptz
*(Unique constraint on tenant_id, owner_type, owner_id)*

`public.wallet_transactions`
- `id`: uuid (PK)
- `wallet_id`: uuid (FK to wallets)
- `transaction_type`: text (enum: 'dropship_profit', 'advance_payment_in', 'payout_sent', 'invoice_payment_deduction', 'sales_revenue', 'capital_invested', 'dividend_payout', 'unremitted_cod', 'courier_charge', 'remittance_collected', 'adjustment')
- `amount`: numeric(12,2) (+ for credit/income, - for debit/expense)
- `balance_after`: numeric(12,2) (Running balance for auditability)
- `reference_type`: text (enum: 'global_invoice', 'global_payment', 'shop_order', 'manual')
- `reference_id`: bigint (FK to the respective reference table, or null)
- `note`: text (Optional description)
- `created_by`: uuid (FK to auth.users)
- `created_at`: timestamptz

**Schema Changes & Data Migration:**
- Drop `public.middle_man_payout_ledger` and all associated dropship-specific payout RPCs.
- **Data Bootstrap:** The SQL migration script will include an `INSERT INTO public.wallets` statement that auto-creates an empty wallet (balance = 0) for every existing `tenant`, `billing_profile`, and `courier` (if applicable) currently in the database to ensure immediate compatibility.

## 3. AuthN, AuthZ, & Permissions
- **Row Level Security (RLS):**
  - `wallets`: Staff/Admins can read/write wallets within their `tenant_id` scope. Parent tenant admins can read all wallets.
  - `wallet_transactions`: Strictly insert-only (except for system-level migrations). No `UPDATE` or `DELETE` grants should be given to any UI-facing role to preserve ledger immutability.
- **RPC Security:** Functions like `create_wallet_transaction` should be `security definer` to ensure `balance_after` is mathematically locked during concurrent inserts.

## 4. API Surface & Contracts (Per Page/Module)
- `POST /rpc/record_wallet_transaction`
  - **Payload:** `{ wallet_id: uuid, amount: numeric, transaction_type: text, reference_type: text, reference_id: bigint, note?: text }`
  - **Returns:** `{ success: boolean, new_balance: numeric, transaction_id: uuid }`
- `POST /rpc/settle_invoice_from_wallet`
  - **Payload:** `{ wallet_id: uuid, global_invoice_id: bigint, amount: numeric }`
  - **Returns:** `{ success: boolean, invoice_paid_amount: numeric, wallet_balance: numeric }`
- `GET /rest/v1/wallets`
  - Used for listing balances on the unified Payouts/Wallets dashboard.
- `GET /rest/v1/wallet_transactions`
  - Used for generating the historical statement for a specific wallet.

## 5. UI & Responsive Design Strategy
- **Wallet Overview Page (Admin/Staff):** A new responsive data table replacing the Dropship Ledger. It will display a list of all Wallets, grouped by `owner_type` (e.g., A tab for Resellers, a tab for Investors).
- **Wallet Statement Component:** A reusable Vue component showing a chronological timeline/ledger of transactions, designed to be embedded inside the `BillingProfileDetailsPage`, `TenantDetailsPage`, or `InvestorDetailsPage`.
- **Bulk Action Dialogs:** Modals for "Manual Adjustment", "Add Funds", and "Settle Payout" that gracefully handle form validation across desktop and mobile.

## 6. State Management, Module Structure & Routing
- **Frontend Module:** Create a dedicated top-level module at `web/src/modules/finance_wallet`.
- **TanStack Query (Services/Hooks):**
  - `useWalletsQuery(filters)`: Cache key `['wallets', tenantId, filters]`.
  - `useWalletTransactionsQuery(walletId)`: Cache key `['wallet_transactions', walletId]`.
- **Pinia:** Not required for this feature, stick to TanStack Query for server state.
- **Routing (Inside `web/src/modules/finance_wallet/router/index.ts`):** 
  - Deprecate the old dropship ledger routes (`/dropship/ledger`).
  - `path: '/finance/wallets', name: 'finance_wallets_list', component: () => import('../pages/WalletListPage.vue')`
  - `path: '/finance/wallets/:walletId', name: 'finance_wallet_details', component: () => import('../pages/WalletDetailsPage.vue')`

## 7. Style Guidelines & Accessibility
- Follow existing Quasar framework guidelines.
- **Color Coding:** Use positive (green) styling for credit `amount` and negative (red) for debit `amount` in the transaction history.
- **Accessibility:** Ensure ARIA labels on complex data tables and proper tab-indexing on the manual adjustment modals.

## 8. Network Handling & Loading Strategy
- Implement optimistic UI updates when a staff member submits a "Settle Payout" action.
- Use Skeleton loaders for the Wallet Statement component to avoid layout shift when fetching heavy historical transaction logs.

## 9. Component Specifications
All files will reside within the `web/src/modules/finance_wallet/` directory structure:

- **Pages (`/pages`):**
  - `WalletListPage.vue`: The main dashboard page for the `/finance/wallets` route.
  - `WalletDetailsPage.vue`: The deep-dive ledger page for `/finance/wallets/:walletId`.

- **Components (`/components`):**
  - `WalletListTable.vue`: Accepts `owner_type` as a prop. Handles pagination and filtering.
  - `WalletStatementCard.vue`: Displays current `balance` boldly at the top and a virtualized list of `wallet_transactions` below. *Designed to be easily exported and embedded into other modules like `TenantDetailsPage` or `BillingProfileDetailsPage`.*
  - `WalletTransactionDialog.vue`: Reusable dialog for making manual adjustments or recording an external payout, yielding a fresh `wallet_transactions` row.

## 10. Explicit Out of Scope
- **Cryptocurrency or External Bank Integrations:** This is an internal ledger only; it does not automatically wire money to external bank accounts via APIs.
- **Complex Multi-Currency Support:** All balances are assumed to be in the base fiat currency (BDT) of the tenant.
- **Automated Tax Deductions:** Tax calculations remain at the invoice level; the wallet strictly handles the net cash flow.

## 11. Testing Strategy
- **Database/pgTAP:** Write assertions proving that concurrent calls to `record_wallet_transaction` correctly compute `balance_after` without race conditions.
- **Integration Tests:** Verify the full lifecycle: `Dropship Order Delivered` -> `Profit Credit` -> `Invoice Deduction` -> `Wallet Balance = 0`.
- **UI Tests:** Ensure the `WalletStatementCard` accurately reflects positive and negative balances visually.

## 12. Definition of Done
- [ ] `wallets` and `wallet_transactions` tables and RLS policies created.
- [ ] `middle_man_payout_ledger` dropped.
- [ ] `record_wallet_transaction` RPC created with concurrency safety.
- [ ] Core business flows (dropship profits, payments, order returns) updated to use the new RPC.
- [ ] `WalletListTable` and `WalletStatementCard` Vue components built and integrated.
- [ ] All previous references to `dropshipLedgerService` refactored or removed.
- [ ] Feature tested successfully on staging environment.
