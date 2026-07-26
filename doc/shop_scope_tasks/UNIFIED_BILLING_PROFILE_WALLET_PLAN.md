# Unified Billing Profile Wallet (Ledger Refactor)

This plan outlines the architectural changes required to merge the disconnected "Invoice Due" (Accounts Receivable) and "Dropship Payout" ledgers into a single unified Wallet attached to each Billing Profile. 

By unifying these transactions, the system will automatically net dropship profits against wholesale debt, provide a clear single balance for middle-men/buyers, and unlock bulk payouts.

## User Review Required

> [!WARNING]
> **Data Migration Strategy**
> Currently, there is existing logic for `middle_man_payout_ledger` and B2B invoice payments. Before starting execution, we need to decide if we should **migrate existing data** or do a **fresh drop and recreate** (as was done in the recent Sales Invoice refactor). A fresh start is generally faster but destroys mock/test data.

> [!IMPORTANT]
> **Terminology**
> I am proposing the term "Wallet" for the UI (e.g., "Wallet Balance: +5,000 BDT"). Is this acceptable, or would you prefer traditional accounting terms like "Account Ledger" or "Net Balance"?

## Open Questions

1. **Bulk Payment Flexibility:** When doing a bulk payout, should the staff be allowed to pay a *partial* amount of the total wallet balance (e.g. paying 5,000 out of an 8,000 balance), or should it strictly clear the *entire* positive balance in one click?
2. **Customer Group Member vs Billing Profile:** Dropship currently links orders to the `customer_group_member_id` placing the order, but financial transactions should live on the `billing_profile_id`. We will standardize all ledger entries to map exclusively to `billing_profile_id`. Does a middle-man *always* have exactly one billing profile in your current setup?

## Proposed Changes

---

### 1. Database (Schema & RPCs)

We will replace the isolated dropship ledger with a universal wallet transaction table.

#### [NEW] `billing_profile_wallet_ledger` (Table)
A new table to record every financial movement for a billing profile.
- `tenant_id`
- `billing_profile_id`
- `transaction_type`: 
  - `invoice_billed` (-)
  - `payment_received` (+) 
  - `dropship_profit` (+)
  - `dropship_return_fee` (-)
  - `payout_paid` (-)
  - `adjustment` (+/-)
- `amount` (Absolute value)
- `balance_after` (Running net balance)
- `reference_id` (Invoice ID, Payment ID, or Shop Order ID depending on context)

#### [DELETE] `middle_man_payout_ledger` (Table)
Remove the old dropship-only ledger table and its specific types.

#### [MODIFY] RPCs (Targeting `/supabase/migrations/`)
- **`post_global_invoice`**: Update to automatically write an `invoice_billed` debit (-) to the wallet.
- **`create_billing_profile_payment_with_allocations`**: Update to write a `payment_received` credit (+) to the wallet.
- **Dropship Profit Generation**: Ensure that when a dropship B2B invoice is posted, the profit delta (Face value - Accounting value) is written as a `dropship_profit` credit (+) to the wallet.
- **`create_bulk_wallet_payout` [NEW]**: A new RPC that deducts a specified amount from a positive wallet balance and records a `payout_paid` debit (-), completely replacing the old order-by-order `create_middle_man_payout`.

---

### 2. Frontend (UI & Services)

We will update the UI so that it is universally usable for both Wholesale buyers and Dropship middle-men.

#### [MODIFY] `BillingProfileDetailsPage.vue` (Or similar profile view)
- Add a highly visible "Wallet Net Balance" card at the top.
- Add a new "Wallet Transactions" tab to show the chronological list of all debits and credits.

#### [MODIFY] `DropshipLedgerPage.vue` -> `BillingWalletLedgerPage.vue`
- Rename and move this page to be a more generic "Wallet & Payouts" screen.
- Instead of showing individual orders that need settling, show a list of **Billing Profiles** with their current Net Balances.
- Add a "Settle Balance / Payout" button next to profiles that have a positive balance (meaning we owe them money).

#### [MODIFY] `DropshipOrderDetailPage.vue`
- Remove the individual "Settle Payout" buttons from the single order view, as settlement will now happen at the Wallet/Billing Profile level in bulk.
- Change the verbiage to state: "Profit credited to Billing Profile Wallet."

## Implementation Phases

### Phase 1: Database Table Creation
**Goal:** Set up the core database schema for the unified billing profile wallet.
**Files to add/change:**
- `[NEW]` `/supabase/migrations/[timestamp]_create_billing_profile_wallet_ledger.sql`
**Details:**
- Create the `billing_profile_wallet_ledger` table with columns: `tenant_id`, `billing_profile_id`, `transaction_type`, `amount`, `balance_after`, and `reference_id`.
- Establish constraints and Row Level Security (RLS) policies for tenant isolation.

### Phase 2: Route Registration & Setup
**Goal:** Create the frontend scaffolding for the new wallet page and register it in the routing and module registry.
**Files to add/change:**
- `[NEW]` `web/src/pages/billing/BillingWalletLedgerPage.vue`
- `[MODIFY]` `web/src/router/routes.ts`
- `[NEW]` `/supabase/migrations/[timestamp]_register_wallet_module_key.sql` (if applicable)
**Details:**
- Register the route module key in the database to ensure proper access control.
- Set up a simple blank Vue page (`BillingWalletLedgerPage.vue`) to test that the new route is functioning.
- Add the route to `routes.ts` making it accessible in the frontend navigation system.

### Phase 3: UI Implementation
**Goal:** Build the actual user interfaces for viewing and interacting with the unified wallet.
**Files to add/change:**
- `[MODIFY]` `web/src/pages/billing/BillingProfileDetailsPage.vue`
- `[MODIFY]` `web/src/pages/billing/BillingWalletLedgerPage.vue`
- `[MODIFY]` `web/src/pages/dropship/DropshipOrderDetailPage.vue`
**Details:**
- **BillingProfileDetailsPage.vue:** Add a highly visible "Wallet Net Balance" card and a "Wallet Transactions" tab to display chronological debits and credits.
- **BillingWalletLedgerPage.vue:** Build out the view to show a list of Billing Profiles with their current Net Balances, and implement a "Settle Balance / Payout" button.
- **DropshipOrderDetailPage.vue:** Remove individual "Settle Payout" buttons and update the verbiage to state "Profit credited to Billing Profile Wallet."

### Phase 4: Migration & Wiring
**Goal:** Update existing RPCs to use the new wallet table and migrate or wire existing accounts and data.
**Files to add/change:**
- `[NEW]` `/supabase/migrations/[timestamp]_wire_wallet_and_migrate.sql`
**Details:**
- Modify the `post_global_invoice` RPC to record an `invoice_billed` debit.
- Modify the `create_billing_profile_payment_with_allocations` RPC to record a `payment_received` credit.
- Ensure dropship profit logic writes a `dropship_profit` credit to the wallet.
- Create a new `create_bulk_wallet_payout` RPC to replace order-by-order settlements.
- Execute a data migration script to wire existing accounts and optionally port data from the old `middle_man_payout_ledger` to the new wallet table.

### Phase 5: Cleanup & Deletion
**Goal:** Remove all old dropship ledger tables, RPCs, and deprecated UI pages to finalize the transition.
**Files to add/change:**
- `[NEW]` `/supabase/migrations/[timestamp]_drop_dropship_ledger.sql`
- `[DELETE]` `web/src/pages/dropship/DropshipLedgerPage.vue`
- `[MODIFY]` `web/src/router/routes.ts`
- `[MODIFY]` `web/src/layouts/MainLayout.vue` (or appropriate navigation component)
**Details:**
- Drop the old `middle_man_payout_ledger` table and any associated old RPCs (e.g., `create_middle_man_payout`).
- Delete the old Dropship Ledger UI (`DropshipLedgerPage.vue`).
- Remove the route for the deleted page from `routes.ts`.
- Remove any sidebar links or UI connections pointing to the old ledger.

## Verification Plan

### Automated Tests
- Create backend `pgTAP` tests (if configured) or manual SQL scripts to verify the running balance logic:
  - Create Invoice (1,000 BDT) -> Balance = -1,000
  - Dropship Profit (1,500 BDT) -> Balance = +500
  - Bulk Payout (500 BDT) -> Balance = 0

### Manual Verification
- Place a Dropship Order and process it to `delivered`.
- Check the Billing Profile's Wallet to ensure the profit was credited.
- Create a Wholesale Invoice for the same Billing Profile.
- Verify the Wallet balance correctly netted the profit against the invoice debt.
- Perform a bulk payout from the UI and ensure the balance drops to zero.
