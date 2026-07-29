# Dropship Wallet / Return — P0 Gaps & Checklist

**Priority:** P0 — flow correctness / accounting integrity  
**Implement via:** [P0A](./DROPSHIP_WALLET_IMPL_P0A_invoice_and_collection.md) → [P0B](./DROPSHIP_WALLET_IMPL_P0B_remittance_unify.md) → [P0C](./DROPSHIP_WALLET_IMPL_P0C_return_finalize.md)  
**Drop conflicting legacy immediately:** [DROPSHIP_WALLET_LEGACY_DROP.md](./DROPSHIP_WALLET_LEGACY_DROP.md)  
**Follow:** [docs/AI_WORKFLOW_SOP.md](../../docs/AI_WORKFLOW_SOP.md)

---

## Gaps

### 1. Missing customer receivable debit in common auto-invoice path
- `invoice_billed` UWL debit is written in `post_global_invoice`, but dropship auto-invoice path can create invoice as already posted.
- Impact: receivable side can be missing while profit/revenue credits exist.
- What this means in simple terms: The system sometimes records earnings without recording that money is still owed, so balances can look healthier than reality.
- Related: `supabase/migrations/20270129000001_retire_billing_profile_wallet_ledger.sql`, `supabase/migrations/20261209000000_fix_is_default_billing_profiles.sql`
- **Impl:** P0A

### 2. Auto-invoice hard-codes `collection_source = billing_profile` (FLOW BREAKER)
- Latest `create_dual_invoice_from_dropship_order` always sets billing_profile; desk remittance requires `recipient` for COD.
- Impact: COD orders invoice OK then remittance raises “does not collect from recipient.”
- What this means in simple terms: After ready-for-pickup, staff cannot record courier money for normal COD orders.
- Related: `supabase/migrations/20261209000000_fix_is_default_billing_profiles.sql`, `supabase/migrations/20261118000009_dropship_ledger_settlement_wireup.sql`
- **Impl:** P0A — restore `is_prepaid_snapshot ? billing_profile : recipient`

### 3. Two remittance engines with divergent wallet behavior
- Desk: `record_dropship_courier_remittance`; finance hub: `confirm_courier_remittance_to_tenant`.
- Impact: same business event can produce different ledger trails.
- What this means in simple terms: Two different buttons write different numbers.
- Related: `supabase/migrations/20261118000009_dropship_ledger_settlement_wireup.sql`, `supabase/migrations/20260728202727_dropship_finance_hub_wallet_flow.sql`
- **Impl:** P0B + drop legacy write path same migration ([LEGACY_DROP](./DROPSHIP_WALLET_LEGACY_DROP.md) row R1)

### 4. No explicit UWL reversal model for returned/cancelled outcomes
- Cleanup mainly on rollback to `processing`; returned/cancelled not standardized.
- Impact: receivable/revenue/profit/courier can stay open after return.
- What this means in simple terms: Returned orders may still show money as earned.
- Related: `supabase/migrations/20270129000001_retire_billing_profile_wallet_ledger.sql`
- **Impl:** P0C

### 5. Merchant profit entity mismatch (`customer` vs `middleman`)
- Status flow credits `customer`; finance hub expects `middleman`.
- Impact: payable KPI wrong.
- What this means in simple terms: Merchant balance reports can be wrong.
- Related: `supabase/migrations/20270129000001_retire_billing_profile_wallet_ledger.sql`
- **Impl:** P0B (profit write) — hub read compat in P1

### 6. Shipment return orchestration gap + wrong stock model risk (FLOW BREAKER if wrong)
- Return fragmented across order/invoice/stock/wallet.
- Restock must use **`global_stocks` rows by `stock_type_id`** (sellable / box-less / damage per `doc/PROCUREMENT_STOCK.md`), **not** legacy `open_box_quantity` columns on `global_stocks` (those do not exist there).
- Impact: broken return or unsellable restock.
- What this means in simple terms: Returned goods may not go back to the right warehouse pile.
- Related: `doc/PROCUREMENT_STOCK.md`, `supabase/migrations/20260806000000_procurement_stock_schema.sql`
- **Impl:** P0C

### 7. Return desk still calls `mark_dropship_order_returned` while finalize is new (FLOW BREAKER)
- Desk uses `mark_dropship_order_returned`; if only `finalize_dropship_return` has stock+wallet, returns skip money/stock fix.
- Impact: status becomes returned without ledger/stock finalize.
- What this means in simple terms: Clicking Returned does not fully undo the order financially.
- Related: `web/src/modules/shop_order/composables/useDropshipOrderActions.ts`
- **Impl:** P0C must make `mark_dropship_order_returned` a wrapper to finalize (or same-release P1 UI). Prefer wrapper in P0C so backend alone is safe.

### 8. No hard idempotency key for return finalization
- No dedicated `return_ref` guard.
- Impact: double-click duplicates restock/reversals.
- What this means in simple terms: One return can be applied twice by mistake.
- **Impl:** P0C

### 9. Return vs payout conflict not hard-gated
- Payout and return can race.
- Impact: false profit settlement then clawback.
- What this means in simple terms: Merchant can be paid before return is settled.
- **Impl:** P0C

### 10. `source_id` / currency inconsistencies (ledger integrity)
- Mixed `order_no` / `order_id` / `invoice_no`; exchange often forced to `1.0`.
- Impact: fragile idempotency and FX math.
- **Impl:** P0B + P0C writes use canonical `source_id = order id text`; currency from order when present

---

## Verification checklist (P0)

After P0A+P0B+P0C migrate:

- [ ] New COD dropship order → `ready_for_pickup` → invoice `collection_source = recipient`
- [ ] Prepaid order → invoice `collection_source = billing_profile`
- [ ] Same transition creates UWL `invoice_billed` debit (idempotent on re-run)
- [ ] Remittance via desk RPC posts courier + tenant UWL entries once
- [ ] Calling old `confirm_courier_remittance_to_tenant` only wraps shared routine (no divergent second write)
- [ ] Profit UWL uses `entity_type = middleman` for new rows
- [ ] `source_id` on new shop-order lifecycle rows is order id text
- [ ] `mark_dropship_order_returned` either finalizes fully or refuses with clear error pointing to finalize
- [ ] Finalize return with `p_return_ref`: second call no-ops / rejects duplicate
- [ ] Returned perfect qty increases sellable `global_stocks` + matching allocation
- [ ] Returned damaged qty lands on damage stock type (not sellable)
- [ ] Payout blocked or recovery path when return unresolved / already paid
- [ ] Run matching rows in [LEGACY_DROP](./DROPSHIP_WALLET_LEGACY_DROP.md) for R1–R3

**Stop for review gate before P1.**
