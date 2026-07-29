# Dropship Wallet / Return — P1 Gaps & Implementation

**Priority:** P1 — reconciliation and runtime safety  
**Prerequisite:** P0A–P0C done ([DROPSHIP_WALLET_GAPS_P0.md](./DROPSHIP_WALLET_GAPS_P0.md))  
**Drop conflicting reads:** [LEGACY_DROP](./DROPSHIP_WALLET_LEGACY_DROP.md) R3–R4  
**Index:** [README_DROPSHIP_WALLET.md](./README_DROPSHIP_WALLET.md)  
**Execute:** one agent session; files listed below only; stop at review gate.  
**Follow:** [docs/AI_WORKFLOW_SOP.md](../../docs/AI_WORKFLOW_SOP.md), [docs/TANSTACK_QUERY_GUIDE.md](../../docs/TANSTACK_QUERY_GUIDE.md), [docs/ERROR_AND_SUCCESS_MESSAGE_GUIDE.md](../../docs/ERROR_AND_SUCCESS_MESSAGE_GUIDE.md)

---

## Gaps

### 1. `source_id` strategy is inconsistent (`order_no` vs `order_id` vs `invoice_no`)
- Different source ids are used for related lifecycle transactions.
- Impact: idempotency checks, rollback-delete, and reporting joins become fragile.
- What this means in simple terms: The same order is identified in different ways in different places, making reliable matching difficult.
- Related: `supabase/migrations/20270129000001_retire_billing_profile_wallet_ledger.sql`, `supabase/migrations/20260728202727_dropship_finance_hub_wallet_flow.sql`  
- **Note:** Canonical `source_id` rule is enforced in P0 migration; this phase must consume that contract in frontend/repo reads.

### 2. Finance hub computes merchant balances using field not selected
- Query selects `entity_type, type, amount` then references `entity_id` while building merchant maps.
- Impact: wrong merchant payable balances / mapping errors.
- What this means in simple terms: A report uses data it did not actually fetch, so merchant totals can be incorrect.
- Related: `web/src/modules/shop_order/repositories/dropshipFinanceRepository.ts`

### 3. Frontend still reads retired `billing_profile_wallet_ledger`
- One repository path still queries a table dropped by wallet unification migration.
- Impact: runtime failures in up-to-date environments.
- What this means in simple terms: Some screens still ask for an old table that no longer exists, which can break pages.
- Related: `web/src/modules/shop_order/repositories/courierRemittanceRepository.ts`, `supabase/migrations/20270129000001_retire_billing_profile_wallet_ledger.sql`

### 4. Courier entity resolution in legacy flow is not order-scoped
- Courier id lookup uses broad `limit 1` mapping rather than order’s selected courier service.
- Impact: wallet entries can be posted to incorrect courier entity.
- What this means in simple terms: Charges can be attached to the wrong courier account.
- Related: `supabase/migrations/20260728202727_dropship_finance_hub_wallet_flow.sql`  
- **Note:** Fixed in P0 RPC; this phase must call only the canonical remittance RPC.

### 5. Currency/exchange handling in wallet posts is effectively fixed
- Many wallet writes use `exchange_rate = 1.000000` regardless of context.
- Impact: inaccurate reversals/reporting if non-BDT or FX flows are introduced.
- What this means in simple terms: The system assumes one exchange rate, so multi-currency math can be wrong.
- Related: `supabase/migrations/20261220000000_create_universal_wallet_ledger.sql`  
- **Note:** Enforced in P0 writes; this phase must not reintroduce hardcoded rate `1` in client math.

---

## Implementation (Phase 2 — frontend wire-up only)

**Goal:** All remittance/finance/return API calls go through one repository + TanStack mutations; hub KPIs read UWL correctly; no retired table reads.

### Global constraints
- TanStack Query owns server state; do **not** store fetched API data in Pinia.
- Repository layer only; no `supabase.rpc` from Vue pages.
- Mutations: `showSuccessNotification` + `parseSupabaseError` on error; queries never toast success.

### READ ONLY (do not edit)
- `docs/TANSTACK_QUERY_GUIDE.md`
- `docs/ERROR_AND_SUCCESS_MESSAGE_GUIDE.md`
- `web/src/modules/shop_order/services/shopOrderQueryKeys.ts`
- P0 migration (RPC names/args only)

### CHANGE (only these)
- `web/src/modules/shop_order/repositories/courierRemittanceRepository.ts`
  - Remove `billing_profile_wallet_ledger` reads
  - Point remittance/reconcile to canonical RPC only (`record_dropship_courier_remittance` / `finalize_dropship_return` as applicable)
- `web/src/modules/shop_order/repositories/dropshipFinanceRepository.ts`
  - Select `entity_id` in UWL queries
  - Treat `middleman` (+ optional `customer` compat) for payable
  - Call canonical remittance RPC only
- `web/src/modules/shop_order/composables/useDropshipOrderActions.ts`
  - Move remittance/status/return RPC calls into repository methods + mutation composables; keep UI refs only as local/Pinia UI state
- **Add:**
  - `web/src/modules/shop_order/composables/useDropshipRemittanceMutations.ts`
  - `web/src/modules/shop_order/composables/useDropshipReturnMutations.ts`
  - Extend `shopOrderQueryKeys.ts` only for invalidate lists needed by these mutations
- Errors: `onError: (e) => showErrorNotification(parseSupabaseError(e, '...'))`; success toast on mutation only

### DO NOT
- Redesign pages, add settlement badges, or build offer/gift UI (P2)
- Store query results in Pinia
- Call `supabase` directly from Vue pages
- Edit backend migrations
- Expand scope beyond listed files

### Done when
Desk remittance + return call one path; finance hub balances use correct fields; **stop for review gate**.

---

## Verification checklist (P1)

- [ ] No repo queries `billing_profile_wallet_ledger`
- [ ] Finance hub UWL select includes `entity_id`
- [ ] Merchant payable map uses `middleman` (compat for historic `customer` profit rows if present)
- [ ] Desk remittance mutation → `record_dropship_courier_remittance` only
- [ ] Return mutation → `finalize_dropship_return` / wrapped `mark_dropship_order_returned` only
- [ ] Mutations toast via `parseSupabaseError`; no Pinia for fetched server lists
- [ ] LEGACY_DROP R3–R4 marked done
