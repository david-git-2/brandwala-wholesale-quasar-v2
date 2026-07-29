---
name: dropship-wallet-gap-closure
overview: Close dropship wallet/return/pricing gaps with SOP-locked phases (goal, read files, change files, do-nothing-else) following docs for TanStack Query, error handling, and skeleton loaders.
todos:
  - id: phase1-p0-backend
    content: "P0 backend only: invoice_billed + remittance unify + return finalize + entity normalize. Stop after migration."
    status: pending
  - id: phase2-p1-frontend-wire
    content: "P1 frontend only: single remittance path via TanStack mutations + fix hub query + remove retired table. No UI redesign."
    status: pending
  - id: phase3-p2-ops-ui
    content: "P2 UI only: settlement badge + return dialog + offer/gift UX with skeletons + parseSupabaseError. Modular components."
    status: pending
  - id: phase4-backfill
    content: "Backfill/check SQL only for historic drift. No feature code."
    status: pending
  - id: phase5-p3-governance
    content: "P3 only: reconciliation job + deprecate legacy RPC execute grants. No feature expansion."
    status: pending
isProject: false
---

# Dropship Wallet Gap Closure Plan

## Priority fix docs (source of truth for execution)

**Implementation order (do first):** [doc/fix/DROPSHIP_WALLET_IMPLEMENTATION_ORDER.md](../../doc/fix/DROPSHIP_WALLET_IMPLEMENTATION_ORDER.md)

Index: [doc/fix/README_DROPSHIP_WALLET.md](../../doc/fix/README_DROPSHIP_WALLET.md). One file per session:

- P0 gaps: [DROPSHIP_WALLET_GAPS_P0.md](../../doc/fix/DROPSHIP_WALLET_GAPS_P0.md) → impl [P0A](../../doc/fix/DROPSHIP_WALLET_IMPL_P0A_invoice_and_collection.md) / [P0B](../../doc/fix/DROPSHIP_WALLET_IMPL_P0B_remittance_unify.md) / [P0C](../../doc/fix/DROPSHIP_WALLET_IMPL_P0C_return_finalize.md)
- [P1](../../doc/fix/DROPSHIP_WALLET_GAPS_P1.md) · [P2](../../doc/fix/DROPSHIP_WALLET_GAPS_P2.md) · [P3](../../doc/fix/DROPSHIP_WALLET_GAPS_P3.md) · [P4 test gate](../../doc/fix/DROPSHIP_WALLET_GAPS_P4.md)
- Drop conflicting legacy same phase: [DROPSHIP_WALLET_LEGACY_DROP.md](../../doc/fix/DROPSHIP_WALLET_LEGACY_DROP.md)

AI agents open **only** the active priority/impl file + its READ ONLY / CHANGE list.


## Confirmed Gaps (Ordered by Priority)

### P0 (flow correctness / accounting integrity)

1. **Missing customer receivable debit in common auto-invoice path**
   - `invoice_billed` UWL debit is written in `post_global_invoice`, but dropship auto-invoice path can create invoice as already posted.
   - Impact: receivable side can be missing while profit/revenue credits exist.
   - What this means in simple terms: The system sometimes records earnings without recording that money is still owed, so balances can look healthier than reality.
   - Files: [supabase/migrations/20270129000001_retire_billing_profile_wallet_ledger.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20270129000001_retire_billing_profile_wallet_ledger.sql), [supabase/migrations/20261209000000_fix_is_default_billing_profiles.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20261209000000_fix_is_default_billing_profiles.sql)

2. **Two remittance engines with divergent wallet behavior**
   - Desk flow uses `record_dropship_courier_remittance`; finance hub uses `confirm_courier_remittance_to_tenant`.
   - Each path writes different wallet intents/metadata.
   - Impact: same business event can produce different ledger trails.
   - What this means in simple terms: Two different buttons/flows can do the “same job” but write different numbers, so reports do not match.
   - Files: [supabase/migrations/20261118000009_dropship_ledger_settlement_wireup.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20261118000009_dropship_ledger_settlement_wireup.sql), [supabase/migrations/20260728202727_dropship_finance_hub_wallet_flow.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20260728202727_dropship_finance_hub_wallet_flow.sql), [web/src/modules/shop_order/composables/useDropshipOrderActions.ts](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/composables/useDropshipOrderActions.ts), [web/src/modules/shop_order/repositories/dropshipFinanceRepository.ts](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/repositories/dropshipFinanceRepository.ts)

3. **No explicit UWL reversal model for returned/cancelled outcomes**
   - Cleanup exists mainly on rollback to `processing`; formal compensating reversals for `returned`/`cancelled` are not standardized.
   - Impact: receivable/revenue/profit/courier states can remain logically open.
   - What this means in simple terms: When an order is returned, the earlier money entries may not be properly undone.
   - Files: [supabase/migrations/20270129000001_retire_billing_profile_wallet_ledger.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20270129000001_retire_billing_profile_wallet_ledger.sql), [supabase/migrations/20261118000008_fix_payout_ledger_balance_after_select_into.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20261118000008_fix_payout_ledger_balance_after_select_into.sql)

4. **Merchant profit entity mismatch across old/new flows**
   - One path uses `entity_type='customer'` for dropship profit while finance hub payable logic expects `entity_type='middleman'`.
   - Impact: merchant payable KPI and payout source can drift from real liability.
   - What this means in simple terms: The system stores merchant profit under different labels, so payable totals can be wrong.
   - Files: [supabase/migrations/20270129000001_retire_billing_profile_wallet_ledger.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20270129000001_retire_billing_profile_wallet_ledger.sql), [web/src/modules/shop_order/repositories/dropshipFinanceRepository.ts](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/repositories/dropshipFinanceRepository.ts)

5. **Shipment return orchestration gap (invoice/stock/ledger not finalized together)**
   - Invoice lifecycle states (`draft`, `posted`, `voided`) are valid, but return handling is fragmented across order return, invoice return rows, stock restoration, and wallet reversal paths.
   - Impact: post-delivery return can leave mismatched stock buckets, invoice net values, and wallet balances when not finalized as one atomic flow.
   - What this means in simple terms: A return can update one part (like stock) but miss another part (like money), causing inconsistencies.
   - Files: [supabase/migrations/20260823000000_sales_invoice_target_schema.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20260823000000_sales_invoice_target_schema.sql), [supabase/migrations/20261118000008_fix_payout_ledger_balance_after_select_into.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20261118000008_fix_payout_ledger_balance_after_select_into.sql), [supabase/migrations/20261207000000_dropship_deduct_and_restock_quantities.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20261207000000_dropship_deduct_and_restock_quantities.sql), [doc/SALES_INVOICE.md](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/doc/SALES_INVOICE.md)

6. **No hard idempotency key for return finalization writes**
   - Existing return flows do not consistently enforce a dedicated return event reference at write time.
   - Impact: duplicate reversals/restock from retries or concurrent actions.
   - What this means in simple terms: If staff clicks twice or network retries, the same return can be applied more than once.
   - Files: [supabase/migrations/20261118000008_fix_payout_ledger_balance_after_select_into.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20261118000008_fix_payout_ledger_balance_after_select_into.sql), [supabase/migrations/20261118000009_dropship_ledger_settlement_wireup.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20261118000009_dropship_ledger_settlement_wireup.sql)

7. **Return vs payout conflict policy is not hard-gated**
   - Payout completion and return finalization can race without a single blocking policy.
   - Impact: clawback complexity and temporary false profit settlement.
   - What this means in simple terms: Merchant payout may be completed before a return is settled, then finance must manually recover money.
   - Files: [supabase/migrations/20261118000009_dropship_ledger_settlement_wireup.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20261118000009_dropship_ledger_settlement_wireup.sql), [web/src/modules/shop_order/repositories/courierRemittanceRepository.ts](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/repositories/courierRemittanceRepository.ts)

### P1 (reconciliation and runtime safety)

6. **`source_id` strategy is inconsistent (`order_no` vs `order_id` vs `invoice_no`)**
   - Different source ids are used for related lifecycle transactions.
   - Impact: idempotency checks, rollback-delete, and reporting joins become fragile.
   - What this means in simple terms: The same order is identified in different ways in different places, making reliable matching difficult.
   - Files: [supabase/migrations/20270129000001_retire_billing_profile_wallet_ledger.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20270129000001_retire_billing_profile_wallet_ledger.sql), [supabase/migrations/20260728202727_dropship_finance_hub_wallet_flow.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20260728202727_dropship_finance_hub_wallet_flow.sql)

7. **Finance hub computes merchant balances using field not selected**
   - Query selects `entity_type, type, amount` then references `entity_id` while building merchant maps.
   - Impact: wrong merchant payable balances / mapping errors.
   - What this means in simple terms: A report uses data it did not actually fetch, so merchant totals can be incorrect.
   - File: [web/src/modules/shop_order/repositories/dropshipFinanceRepository.ts](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/repositories/dropshipFinanceRepository.ts)

8. **Frontend still reads retired `billing_profile_wallet_ledger`**
   - One repository path still queries a table dropped by wallet unification migration.
   - Impact: runtime failures in up-to-date environments.
   - What this means in simple terms: Some screens still ask for an old table that no longer exists, which can break pages.
   - Files: [supabase/migrations/20270129000001_retire_billing_profile_wallet_ledger.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20270129000001_retire_billing_profile_wallet_ledger.sql), [web/src/modules/shop_order/repositories/courierRemittanceRepository.ts](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/repositories/courierRemittanceRepository.ts)

9. **Courier entity resolution in legacy flow is not order-scoped**
   - Courier id lookup uses broad `limit 1` mapping rather than order’s selected courier service.
   - Impact: wallet entries can be posted to incorrect courier entity.
   - What this means in simple terms: Charges can be attached to the wrong courier account.
   - File: [supabase/migrations/20260728202727_dropship_finance_hub_wallet_flow.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20260728202727_dropship_finance_hub_wallet_flow.sql)

10. **Currency/exchange handling in wallet posts is effectively fixed**
    - Many wallet writes use `exchange_rate = 1.000000` regardless of context.
    - Impact: inaccurate reversals/reporting if non-BDT or FX flows are introduced.
    - What this means in simple terms: The system assumes one exchange rate, so multi-currency math can be wrong.
    - Files: [supabase/migrations/20261220000000_create_universal_wallet_ledger.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20261220000000_create_universal_wallet_ledger.sql), [supabase/migrations/20260728202727_dropship_finance_hub_wallet_flow.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20260728202727_dropship_finance_hub_wallet_flow.sql)

### P2 (operational edge-case correctness)

10. **Prepaid collection mode can conflict with recipient remittance action**
   - Dropship invoice may be `collection_source='billing_profile'`, but recipient remittance RPC enforces recipient collection.
   - Impact: dead-end flows if UI still offers recipient remittance for prepaid orders.
   - What this means in simple terms: Staff may be shown an action that cannot work for that order type.
   - Files: [supabase/migrations/20261118000008_fix_payout_ledger_balance_after_select_into.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20261118000008_fix_payout_ledger_balance_after_select_into.sql), [supabase/migrations/20261118000009_dropship_ledger_settlement_wireup.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20261118000009_dropship_ledger_settlement_wireup.sql)

11. **Remittance amount validation is lower-bound only**
    - Positive check exists, but no strict upper bound against collectible/outstanding constraints.
    - Impact: over-remittance can distort paid/outstanding lifecycle.
    - What this means in simple terms: The system checks “more than zero” but not “too much,” so over-collection can be saved.
    - File: [supabase/migrations/20261118000009_dropship_ledger_settlement_wireup.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20261118000009_dropship_ledger_settlement_wireup.sql)

12. **Middleman payout handoff not visible as explicit order-level state**
    - Financial payout completion is tracked separately from order status.
    - Impact: ops view can treat delivered/payment_received as fully closed even when merchant payout is pending.
    - What this means in simple terms: Operations may think an order is fully done even though merchant payment is still pending.
    - Files: [web/src/modules/shop_order/composables/useDropshipOrderActions.ts](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/composables/useDropshipOrderActions.ts), [web/src/modules/shop_order/repositories/courierRemittanceRepository.ts](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/repositories/courierRemittanceRepository.ts), [web/src/modules/shop_order/repositories/dropshipFinanceRepository.ts](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/repositories/dropshipFinanceRepository.ts)

13. **Storefront unified pricing gap for same product across multiple shipments**
    - Listing model is allocation/stock-line oriented, so same product can appear with inconsistent customer prices depending on source allocation/shipment.
    - Impact: customer trust issues, pricing inconsistency, and harder promotion control.
    - What this means in simple terms: Customers can see different prices for what appears to be the same item.
    - Files: [supabase/migrations/20261024000000_shop_order_p14_dropship_default_min_price.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20261024000000_shop_order_p14_dropship_default_min_price.sql), [doc/SHOP_ORDER.md](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/doc/SHOP_ORDER.md)

14. **Condition-segmented pricing not formalized for normal vs open-box vs damaged storefront offers**
    - Condition stock buckets exist in inventory semantics, but offer-level condition pricing policy is not consistently modeled for customer-facing listing behavior.
    - Impact: damaged/open-box handling becomes ad-hoc and can leak wrong price/quality expectations.
    - What this means in simple terms: Item quality types are not consistently priced, so buyers may get confusing quality/price combinations.
    - Files: [supabase/migrations/20260428120000_inventory_module.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20260428120000_inventory_module.sql), [doc/SHOP_ORDER.md](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/doc/SHOP_ORDER.md)

15. **Gift-item policy gap (customer-group-specific gifts + cost ownership)**
    - Gift/complimentary lines are not formalized as a scoped policy engine by customer group with explicit cost-bearing rules.
    - Impact: promo leakage, duplicate gift application, and unclear margin ownership between tenant and middleman.
    - What this means in simple terms: Free gift rules are not strict enough, so giveaways and costs can get out of control.
    - Files: [doc/SHOP_ORDER.md](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/doc/SHOP_ORDER.md), [supabase/migrations/20261108000000_separate_dropship_charges_configurations.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20261108000000_separate_dropship_charges_configurations.sql)

16. **Override audit trail is not mandatory for sensitive financial edits**
    - Return-fee overrides and gift-cost ownership decisions are not enforced with actor+reason snapshots in one contract.
    - Impact: post-facto dispute handling becomes weak.
    - What this means in simple terms: When someone changes a fee, the system may not clearly record who changed it and why.
    - Files: [supabase/migrations/20261118000008_fix_payout_ledger_balance_after_select_into.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20261118000008_fix_payout_ledger_balance_after_select_into.sql), [web/src/modules/shop_order/composables/useDropshipOrderActions.ts](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/composables/useDropshipOrderActions.ts)

### P3 (governance / ongoing control)

17. **No scheduled reconciliation control loop**
    - Backfill queries exist as one-time work, but no periodic reconciliation job enforces drift detection.
    - Impact: silent inconsistencies can reappear after release.
    - What this means in simple terms: Even after fixes, errors can slowly come back if there is no routine health check.
    - Files: [supabase/migrations/20260728202828_backfill_middleman_universal_wallet.sql](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/20260728202828_backfill_middleman_universal_wallet.sql), [supabase/migrations/](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/supabase/migrations/)

18. **Legacy endpoint exposure risk after canonicalization**
    - Even after unifying logic, old RPC entry points can remain callable unless explicitly restricted/deprecated.
    - Impact: duplicate semantic writes from mixed clients.
    - What this means in simple terms: Old and new app paths may both stay active, causing the same event to be recorded twice.
    - Files: [web/src/modules/shop_order/repositories/dropshipFinanceRepository.ts](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/repositories/dropshipFinanceRepository.ts), [web/src/modules/shop_order/repositories/courierRemittanceRepository.ts](/Users/daviditc/Documents/Personal Project/brandwala-wholesale-quasar-v2/web/src/modules/shop_order/repositories/courierRemittanceRepository.ts)

## Solution for Each Gap (Ordered)

### P0 Solutions

1. **Guarantee `invoice_billed` creation independently of posting path**
   - Add `ensure_dropship_invoice_billed_entry(invoice_id, order_key)` helper and call it from both:
     - `post_global_invoice`
     - `advance_dropship_order_status` after auto-invoice create/attach
   - Idempotency key: tenant + invoice id + `transaction_type='invoice_billed'`.

2. **Unify remittance lifecycle into one authoritative implementation**
   - Move all courier/tenant/merchant remittance ledger effects into a shared internal routine.
   - Make one RPC canonical (`record_dropship_courier_remittance`) and convert `confirm_courier_remittance_to_tenant` to wrapper or deprecate.
   - Ensure consistent metadata contract (`purpose`, `transaction_type`, `order_id`, `order_no`, `invoice_id`).

3. **Define formal reversal matrix for `returned`/`cancelled`**
   - Implement compensating UWL entries for each posted transaction type:
     - `invoice_billed` reversal
     - `dropship_profit` reversal
     - `revenue` reversal
     - courier remittance reversal
   - Keep rollback-to-processing hard-delete behavior only if explicitly required by business rule.

4. **Normalize merchant ledger entity model**
   - Pick one canonical merchant entity type (`middleman` recommended for payout semantics).
   - Add compatibility read strategy for old `customer`-typed profit rows during transition.

5. **Introduce atomic shipment return finalization flow**
   - Keep invoice status model unchanged (`draft`/`posted`/`voided`) and add one authoritative return finalization RPC for posted invoices/orders.
   - Finalization must atomically perform:
     - condition-based stock re-entry (`perfect`, `open_box`, `damaged`) to correct stock buckets
     - allocation/show-stock sync (`global_stock_allocations`) with actual stock
     - invoice return row + line return quantity updates
     - compensating wallet entries for already posted monetary effects
   - Add return sub-state progression (`return_requested` -> `return_in_transit` -> `return_received` -> `return_finalized`) while keeping top-level order status compatible.

6. **Enforce return event idempotency**
   - Require `p_return_ref` (or equivalent) and unique guard across stock+wallet+invoice return writes.
   - Reject duplicate finalization attempts with same reference.

7. **Add hard gating between payout and return finalization**
   - Block payout while return is unresolved, or require explicit recovery workflow before marking payout complete.

### P1 Solutions

5. **Standardize source identity contract**
   - Use one canonical `source_id` rule for shop orders (recommend: immutable order id text), keep `order_no` in metadata only.
   - Update all idempotency/reconciliation checks to this contract.

6. **Fix finance hub data query contract**
   - Ensure required fields (`entity_id`, plus metadata where used) are selected whenever balance mapping logic consumes them.

7. **Remove legacy-table dependency from frontend**
   - Replace `billing_profile_wallet_ledger` reads with UWL-based reads and shared wallet math utilities.

8. **Fix courier resolution to be order-scoped**
   - Resolve courier entity strictly from order’s selected courier service mapping; fail clearly if unresolved.

9. **Make currency/exchange handling explicit in wallet contracts**
   - Persist and validate currency/exchange fields for all compensating entries, not only default BDT assumptions.

### P2 Solutions

9. **Guard remittance action by collection mode**
   - If invoice collection source is `billing_profile`, disable recipient-remittance flow and route to account-collection flow.

10. **Enforce remittance amount caps**
    - Validate against invoice outstanding/collectible amount and block over-remit writes.

11. **Expose payout handoff state in desk**
    - Add explicit settlement state derived from payout ledger/invoice payout status (`unpaid`, `partial`, `paid`), shown alongside order status.

12. **Add product-offer layer for unified storefront pricing**
    - Introduce canonical offer key `(shop_id, product_id, condition_bucket)` for customer-facing price.
    - Keep allocation rows as quantity/cost source only; fulfillment can pick from multiple shipment allocations behind one offer.

13. **Formalize condition-based offer pricing**
    - Define explicit condition buckets (`normal`, `open_box`, `damaged`) with independent offer activation/price controls.
    - Enforce condition-appropriate visibility and stock routing at listing/cart/checkout.

14. **Add customer-group-scoped gift policy engine**
    - Add gift program + rule + gift item mapping scoped by `customer_group_id`, with priority and eligibility triggers.
    - Persist gift lines as explicit `line_type='gift'` with zero customer price but full cost posting.
    - Add cost ownership policy (`tenant`/`middleman`/split) and idempotency guard (order + rule key).

15. **Require override audit metadata**
    - Enforce mandatory actor/reason/timestamp payload fields for return-fee overrides and special cost-allocation overrides.

### P3 Solutions

16. **Introduce scheduled reconciliation jobs**
    - Add periodic SQL checks for wallet/order/invoice/stock drift and publish actionable mismatch outputs.

17. **Deprecate and hard-guard legacy RPC paths**
    - Convert old endpoints to wrappers with strict idempotency checks or remove execute permissions after migration window.

## Wallet Return Gaps (Detailed)

1. **No canonical return-wallet RPC**
   - Return-related wallet logic is distributed across status/remittance/order-return paths.
   - Risk: partial reversals, duplicate reversals, and inconsistent balances.

2. **No deterministic reversal matrix by transaction type**
   - There is no strict rulebook for how each posted transaction is compensated when return is finalized.
   - Required transaction families: `invoice_billed`, `dropship_profit`, `revenue`, courier remittance legs, payout-paid cases.

3. **Inconsistent lifecycle keying for reversal matching**
   - Existing flows mix `order_no`, `order_id`, and `invoice_no` in source linkage.
   - Risk: idempotency and reconciliation failures on returned/cancelled outcomes.

4. **Partial return allocation is not standardized financially**
   - No single proportional method is documented/enforced for partial return reversal of receivable/profit/revenue.
   - Risk: over/under reversal against invoice line returns.

5. **Remitted vs non-remitted return branches are not explicitly separated**
   - Financial behavior differs materially if remittance/payment already happened, but branch policy is not codified.
   - Risk: incorrect cash/liability balances after return.

6. **Payout-already-dispensed return recovery path is undefined**
   - If merchant payout has already been marked paid, return policy must define clawback/negative payable handling.
   - Risk: tenant loss hidden by incomplete wallet reversal.

## Wallet Return Solutions (Detailed, Ordered)

1. **Create one authoritative wallet return finalization routine**
   - Add shared internal routine + exposed RPC (called by all return pathways) that applies all wallet compensations atomically.
   - Enforce row locks and transaction boundaries around order/invoice/wallet context.

2. **Implement strict reversal matrix with compensating entries**
   - Map each posted transaction type to one compensation rule and metadata contract.
   - Prefer compensating entries over deletion for auditability.

3. **Standardize reversal identity contract**
   - Canonical linkage key for order lifecycle (recommended `order_id::text` as source key).
   - Required metadata on each reversal: `return_ref`, `reversal_of_transaction_type`, `order_id`, `order_no`, `invoice_id`, `reason`.

4. **Add proportional reversal formulas for partial returns**
   - Reverse receivable/profit/revenue by returned-line ratio (net of configured return charge ownership).
   - Use invoice line `return_quantity` and return records as source of truth.

5. **Separate remittance-state branches**
   - Branch A: not remitted/unpaid (reverse receivable/profit/revenue).
   - Branch B: remitted/paid (also reverse remittance cash/liability legs and settlement links).

6. **Define payout recovery policy**
   - If payout already dispensed, create controlled recovery ledger flow (negative payable / clawback tracking) instead of silent mutation.

7. **Add validation + backfill checks**
   - Detect returned orders missing reversal entries.
   - Detect duplicate reversals per `return_ref`.
   - Detect full returns with residual profit/revenue/receivable balance.

## Phased Implementation Plan (Where to Change)

Follow [docs/AI_WORKFLOW_SOP.md](docs/AI_WORKFLOW_SOP.md): **one phase per agent session**; expose only listed files; **review gate** after each phase; abort/undo on drift.

### Global AI coding constraints (all frontend phases)

- **Server state:** TanStack Query only (`useQuery` / `useMutation`). Do **not** put fetched API data into Pinia stores. Pinia only for UI/auth/local form filters. Follow [docs/TANSTACK_QUERY_GUIDE.md](docs/TANSTACK_QUERY_GUIDE.md).
- **API calls:** repository layer only; never call `supabase.rpc` from Vue pages.
- **Errors/success:** mutations use `showSuccessNotification` + `parseSupabaseError` on error; queries never toast success. Follow [docs/ERROR_AND_SUCCESS_MESSAGE_GUIDE.md](docs/ERROR_AND_SUCCESS_MESSAGE_GUIDE.md).
- **Loaders:** page/section loads use dedicated `*Skeleton.vue` with `q-skeleton` (not spinners for initial load). Follow [docs/PAGE_LAYOUT_AND_LOADERS.md](docs/PAGE_LAYOUT_AND_LOADERS.md).
- **UI structure:** modular components; parent page is container; respect [docs/UI_CONSISTENCY.md](docs/UI_CONSISTENCY.md) + [docs/COMPONENT_MODULARIZATION_GUIDE.md](docs/COMPONENT_MODULARIZATION_GUIDE.md).
- **Do nothing else:** no drive-by refactors, no unrelated renames, no docs unless the phase lists a doc file.

---

### Phase 1 — P0 Backend ledger + return finalization

**Goal:** Make money and return side effects correct in the database for every dropship status transition, remittance, and return finalization.

**READ ONLY (info — do not edit):**
- [supabase/migrations/20270129000001_retire_billing_profile_wallet_ledger.sql](supabase/migrations/20270129000001_retire_billing_profile_wallet_ledger.sql) — current `advance_dropship_order_status` + `post_global_invoice`
- [supabase/migrations/20261209000000_fix_is_default_billing_profiles.sql](supabase/migrations/20261209000000_fix_is_default_billing_profiles.sql) — auto-invoice creates as `posted`
- [supabase/migrations/20261118000009_dropship_ledger_settlement_wireup.sql](supabase/migrations/20261118000009_dropship_ledger_settlement_wireup.sql) — `record_dropship_courier_remittance`
- [supabase/migrations/20260728202727_dropship_finance_hub_wallet_flow.sql](supabase/migrations/20260728202727_dropship_finance_hub_wallet_flow.sql) — courier remittance UWL pattern to port
- [supabase/migrations/20261118000008_fix_payout_ledger_balance_after_select_into.sql](supabase/migrations/20261118000008_fix_payout_ledger_balance_after_select_into.sql) — `mark_dropship_order_returned`
- [supabase/migrations/20261220000000_create_universal_wallet_ledger.sql](supabase/migrations/20261220000000_create_universal_wallet_ledger.sql) — `record_ledger_transaction` contract
- [doc/wallet/UNIVERSAL_WALLET_LEDGER.md](doc/wallet/UNIVERSAL_WALLET_LEDGER.md) — wallet semantics

**CHANGE (create one new migration only):**
- New file: `supabase/migrations/YYYYMMDDHHMMSS_dropship_wallet_return_p0.sql`
- Redefine / add only:
  1. Helper `ensure_dropship_invoice_billed_entry` + call from `post_global_invoice` and after auto-invoice in `advance_dropship_order_status`
  2. Shared remittance ledger routine; make `record_dropship_courier_remittance` authoritative; wrap `confirm_courier_remittance_to_tenant`
  3. Canonical merchant entity `middleman` for profit credits (compat read for old `customer` rows)
  4. `finalize_dropship_return` with `p_return_ref` idempotency, condition restock, compensating UWL reversals, payout hard-gate
  5. Order-scoped courier entity resolve; remittance amount upper bound; remitted vs non-remitted reverse branches
- Schema adds only if missing: return sub-state, suggested/actual return fee, override audit columns

**DO NOT:**
- Touch any `web/` files
- Regenerate types unless user asks
- Rewrite unrelated RPCs, rename tables, or change invoice status enum
- Add gift/pricing/offer tables (Phase 3 / P2)

**Done when:** migration applies cleanly; P0 solutions 1–7 behave as specified; **stop for review gate**.

---

### Phase 2 — P1 Frontend wire-up (TanStack, no Pinia server cache)

**Goal:** All remittance/finance/return API calls go through one repository + TanStack mutations; hub KPIs read UWL correctly; no retired table reads.

**READ ONLY (info — do not edit):**
- [docs/TANSTACK_QUERY_GUIDE.md](docs/TANSTACK_QUERY_GUIDE.md)
- [docs/ERROR_AND_SUCCESS_MESSAGE_GUIDE.md](docs/ERROR_AND_SUCCESS_MESSAGE_GUIDE.md)
- [web/src/modules/shop_order/services/shopOrderQueryKeys.ts](web/src/modules/shop_order/services/shopOrderQueryKeys.ts) — existing key factory pattern
- Phase 1 migration (RPC names/args only)

**CHANGE (only these):**
- [web/src/modules/shop_order/repositories/courierRemittanceRepository.ts](web/src/modules/shop_order/repositories/courierRemittanceRepository.ts)
  - Remove `billing_profile_wallet_ledger` reads
  - Point remittance/reconcile to canonical RPC only
- [web/src/modules/shop_order/repositories/dropshipFinanceRepository.ts](web/src/modules/shop_order/repositories/dropshipFinanceRepository.ts)
  - Select `entity_id` in UWL queries; treat `middleman` (+ optional `customer` compat) for payable
  - Call canonical remittance RPC only
- [web/src/modules/shop_order/composables/useDropshipOrderActions.ts](web/src/modules/shop_order/composables/useDropshipOrderActions.ts)
  - Move remittance/status/return RPC calls into repository methods + mutation composables; keep UI refs only as local/Pinia UI state
- **Add** (new):
  - `web/src/modules/shop_order/composables/useDropshipRemittanceMutations.ts`
  - `web/src/modules/shop_order/composables/useDropshipReturnMutations.ts`
  - Extend `shopOrderQueryKeys.ts` only for invalidate lists needed by these mutations
- Errors: `onError: (e) => showErrorNotification(parseSupabaseError(e, '...'))`; success toast on mutation only

**DO NOT:**
- Redesign pages, add settlement badges, or build offer/gift UI (Phase 3)
- Store query results in Pinia
- Call `supabase` directly from Vue pages
- Edit backend migrations

**Done when:** desk remittance + return call one path; finance hub balances use correct fields; **stop for review gate**.

---

### Phase 3 — P2 Ops UI (settlement, return dialog, offer/gift surfaces)

**Goal:** Operators can see payout settlement and complete returns with condition/fee override; storefront uses unified condition-scoped price; gift rules are customer-group scoped.

**READ ONLY (info — do not edit):**
- [docs/PAGE_LAYOUT_AND_LOADERS.md](docs/PAGE_LAYOUT_AND_LOADERS.md)
- [docs/UI_CONSISTENCY.md](docs/UI_CONSISTENCY.md)
- [docs/COMPONENT_MODULARIZATION_GUIDE.md](docs/COMPONENT_MODULARIZATION_GUIDE.md)
- Existing [web/src/modules/shop_order/pages/DropshipOrderDetailPage.vue](web/src/modules/shop_order/pages/DropshipOrderDetailPage.vue) layout only as placement reference

**Prerequisite:** If offer/gift tables were not added in Phase 1, add **one** schema migration first (tables only), then this UI phase. Do not mix schema + large UI in one unfocused run.

**CHANGE (only these UI/module files):**
- [web/src/modules/shop_order/pages/DropshipOrderDetailPage.vue](web/src/modules/shop_order/pages/DropshipOrderDetailPage.vue) — wire settlement badge + return CTA; keep as container; extract if >250 lines
- [web/src/modules/shop_order/components/DropshipOrderDialogs.vue](web/src/modules/shop_order/components/DropshipOrderDialogs.vue) — return dialog: condition split, suggested vs actual fee, override reason required
- [web/src/modules/shop_order/components/ShopOrdersTable.vue](web/src/modules/shop_order/components/ShopOrdersTable.vue) — payout settlement column/badge only
- **Add** presentational components + skeletons (do not inline skeletons in page):
  - `components/DropshipSettlementBadge.vue`
  - `components/DropshipReturnFinalizeDialog.vue` (if dialog grows)
  - `components/DropshipOrderDetailSkeleton.vue`
- Listing/offer admin: only the existing shop listings pricing surface — condition bucket + unified offer price; no new nav modules
- Gift admin: minimal rule form scoped by `customer_group_id` on existing dropship merchants/settings surface only
- Data via TanStack `useQuery`/`useMutation` + repositories from Phase 2; `q-skeleton` for initial load

**DO NOT:**
- Change order status enum
- Refactor unrelated shop_order pages
- Put catalog data into Pinia
- Skip `parseSupabaseError` / success toast rules
- Expand into marketing/CMS features

**Done when:** settlement visible; return dialog posts `finalize_dropship_return`; one price per `(shop, product, condition)`; **stop for review gate**.

---

### Phase 4 — Backfill and drift checks only

**Goal:** Detect/fix historic bad ledger and pricing rows so production matches the new rules.

**READ ONLY:** Phase 1–3 RPC/table names; sample checks from gap list above.

**CHANGE:**
- One new migration: `supabase/migrations/YYYYMMDDHHMMSS_dropship_wallet_gap_backfill.sql`
  - Insert missing `invoice_billed` where invoice exists
  - Flag/fix remitted orders missing courier UWL
  - Flag returns missing compensating entries
  - Flag conflicting active offer prices
  - Flag missing/duplicate gifts
- Optional short note in [doc/SHOP_ORDER_DROPSHIP.md](doc/SHOP_ORDER_DROPSHIP.md) **only if user asks for docs in this phase**

**DO NOT:** change application code; invent new business features.

**Done when:** check queries return empty critical sets or documented exceptions; **stop for review gate**.

---

### Phase 5 — P3 Governance

**Goal:** Ongoing drift detection + prevent old clients from writing duplicate wallet events.

**READ ONLY:** Phase 1 wrapper RPCs; Phase 4 check SQL.

**CHANGE:**
- Migration: callable reconciliation report RPC (use `pg_cron` only if project already uses it — do not invent cron infra)
- Revoke or wrap execute on legacy remittance entry points after cutover window
- No UI beyond a minimal “run reconciliation” action if finance hub already exists — otherwise RPC-only

**DO NOT:** redesign finance hub; add new wallet entity types; reopen P0–P2 scope.

**Done when:** one reconciliation report RPC exists and legacy write path is guarded; **stop**.

---

## AI execution rules (anti-drift)

1. Execute **one phase per agent session**.
2. Open **only** files listed under READ ONLY + CHANGE for that phase.
3. If a needed file is not listed → **stop** and ask; do not expand scope.
4. Prefer compensating ledger entries over deletes (except documented rollback-to-processing).
5. Keep writes idempotent (`source_type`, canonical `source_id`, `metadata.transaction_type` / `return_ref`).
6. Preserve existing permission/`security definer` patterns.
7. Frontend: TanStack for server state; skeletons for load; `parseSupabaseError` for errors; **nothing more, nothing else**.


## Dropship Return Policy (Add-on Scope)

### Return policy goals

1. Courier return charge must be policy-based but overrideable per order.
2. Returned items must re-enter stock by condition (`perfect`, `open_box`, `damaged`).
3. Both actual stock and shown/shop stock must be updated together.
4. Financial side must stay aligned with operational return finalization.

### Proposed backend contract (implemented in Phase 1 only)

- RPC: `finalize_dropship_return(...)` in Phase 1 migration.
- Payload: `p_order_id`, `p_items` JSON (`order_item_id`, `returned_qty`, `condition`, optional `note`), `p_actual_return_charge`, `p_deduct_from_middle_man`, `p_override_reason` (required when actual != suggested), `p_return_ref` (idempotency).
- Single transaction: lock order + stock → validate qty → write return state → restock by condition → wallet compensations.

### Courier charge policy with override

- Compute `suggested_return_fee` from courier defaults (`inside/outside` by zone).
- Persist `suggested_return_fee` (audit) and `actual_return_fee` (financial).
- Persist override metadata (`override_reason`, actor, timestamp) when changed.

### Condition-based restock rules

- `perfect` → normal sellable bucket.
- `open_box` → open-box bucket.
- `damaged` → damaged bucket (non-sellable).
- Reuse existing disposition semantics; do not create parallel condition systems.

### Actual + shown stock sync

- Update `global_stocks` (actual) and `global_stock_allocations` (shown) together.
- Keep listing activation in sync when returned stock becomes available.

### Return operational sub-states (without enum churn)

- Keep `shop_orders.status='returned'`.
- Sub-state: `return_requested` → `return_in_transit` → `return_received` → `return_finalized`.
- Stock and ledger writes only at `return_finalized`.

### Return financial policy alignment

- At `return_finalized`, apply compensating UWL entries.
- Apply return fee via `actual_return_fee` + `p_deduct_from_middle_man`.
- One-time processing via `p_return_ref`.

### Where this maps in phases

- **Phase 1:** schema + `finalize_dropship_return` + wallet compensations (backend only).
- **Phase 2:** TanStack mutation composable calling that RPC (no UI redesign).
- **Phase 3:** return dialog UI + skeleton + override reason fields.
- **Phase 4:** backfill checks for returned orders missing stock/ledger effects.
