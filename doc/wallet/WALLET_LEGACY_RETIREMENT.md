# Wallet Legacy — RPC & Code Retirement

What to **drop** after parent-books migration and new wallet RPCs ship. Do not delete before the replacement in the “Replace with” column is live.

**Depends on:** P5b (detail + manual tx RPCs), [`UNIVERSAL_WALLET_DETAIL_RPC.md`](./UNIVERSAL_WALLET_DETAIL_RPC.md)  
**Related:** [`WALLET_PARENT_BOOKS_IMPLEMENTATION.md`](./WALLET_PARENT_BOOKS_IMPLEMENTATION.md) P7–P8, [`RECORD_LEDGER_SYSTEM_RPC_MIGRATION.md`](./RECORD_LEDGER_SYSTEM_RPC_MIGRATION.md)

---

## Phase timing

| Phase | Retirement scope |
| :--- | :--- |
| **P8a** | Broken / zombie backend RPCs + no-op stubs (safe anytime after UWL is canonical) |
| **P8b** | Wallet UI dead files + stop client `record_ledger_transaction` |
| **P8c** | Revoke client grants on internal ledger RPCs; narrow repository surface |
| **P7** | Drop `wallet_accounts.tenant_id`, `universal_wallet_ledger.tenant_id`, deprecated overloads |

---

## P8a — Backend: drop or fix zombies

### Drop (table already gone — RPCs are broken)

| RPC | File | Why drop | Replacement |
| :--- | :--- | :--- | :--- |
| `dispense_middleman_payout` | `supabase/schemas/public.sql` | Uses dropped `billing_profile_wallet_ledger` + dropped `record_wallet_ledger_entry` | `dispense_middleman_payout_from_tenant` (already used by finance hub + invoice repos) |
| `record_wallet_ledger_entry` | Already dropped in migration `20270129000001` | Schema stub out of sync | `record_ledger_transaction` / UWL only |

**SQL:**

```sql
DROP FUNCTION IF EXISTS public.dispense_middleman_payout(bigint, numeric, text, text);
-- record_wallet_ledger_entry already dropped in 20270129000001
```

**Frontend:** No caller for `dispense_middleman_payout` (only types). Regenerate types after drop.

### Drop no-op stub + callers

| RPC | Why | Action |
| :--- | :--- | :--- |
| `ensure_dropship_invoice_billed_entry` | No-op since dropship B2B does not bill customer wallet ([`20270831450000`](../../supabase/migrations/20270831450000_dropship_invoice_no_customer_wallet.sql)) | Remove `perform ensure_dropship_invoice_billed_entry(...)` from callers; `DROP FUNCTION` |

**Callers to edit (remove `perform` only):**

- `create_dual_invoice_from_dropship_order` — `supabase/schemas/sales_invoice/03_rpcs.sql`
- Any other `perform ensure_dropship_invoice_billed_entry` found via grep

### Fix before drop (still needed — rewrite, do not delete)

| RPC | Problem | Fix |
| :--- | :--- | :--- |
| `get_courier_unremitted_financial_summary` | Joins dropped `billing_profile_wallet_ledger` for `dropship_profit` | Sum from `universal_wallet_ledger`: `entity_type in ('customer','middleman')`, `metadata->>'transaction_type' = 'dropship_profit'`, `parent_tenant_id` books filter |

**Used by:** `web/src/modules/shop_order/repositories/courierRemittanceRepository.ts`

---

## P8b — Frontend: delete dead files

Verified **no imports** in `web/` (safe to delete in one PR after P5b wires `UniversalWalletPage`):

| File | Reason |
| :--- | :--- |
| `web/src/modules/wallet/components/UniversalWallet.vue` | Superseded by `UniversalWalletPage.vue`; never routed |
| `web/src/modules/wallet/components/WalletDepositModal.vue` | Superseded by `WalletActionModal.vue` |
| `web/src/modules/wallet/components/WalletWithdrawModal.vue` | Superseded by `WalletActionModal.vue` |
| `web/src/modules/wallet/components/WalletTransferModal.vue` | Never imported |
| `web/src/modules/wallet/components/WalletStatementView.vue` | Never imported |
| `web/src/modules/wallet/components/WalletReportsView.vue` | Never imported |

### Trim composables (after deleting `UniversalWallet.vue`)

| File | Remove |
| :--- | :--- |
| `useWalletMutations.ts` | Entire file if nothing left, or drop `useAdjustWalletBalanceMutation` + `useRecordLedgerTransactionMutation` |
| `walletRepository.ts` | `recordTransaction`, `fetchLedgerEntries` (detail page only) |
| `useWalletQuery.ts` | Replace with `list_wallet_ledger_for_staff` query or delete if page uses repository only |

### Keep (still used outside wallet detail)

| File / method | Used by |
| :--- | :--- |
| `walletRepository.fetchLatestBalance` | `InvoiceDetailsPage`, `CreateWholesaleInvoicePage` (store credit) |
| `useWalletAccount` / `useWalletAccounts` | `VendorWalletDialog`, `CustomerGroupWalletDialog`, `MerchantWalletPage`, detail page until P5b |
| `SimplifiedWalletView.vue` | `MerchantWalletPage` — migrate to detail RPCs or thin wrapper later |
| `dispense_middleman_payout_from_tenant` | Finance hub, invoice repo — **keep** |

---

## P8c — Stop client access to internal ledger RPC

After P5b, staff manual writes go through scoped RPCs. Domain modules keep posting via SECURITY DEFINER writers.

### Revoke `authenticated` EXECUTE (keep `service_role`)

| RPC | Why |
| :--- | :--- |
| `record_ledger_transaction` | UI uses `record_wallet_manual_transaction_for_staff`; domain RPCs call as definer |

Optional same treatment if no direct client usage remains:

| RPC | Replace with |
| :--- | :--- |
| Direct `universal_wallet_ledger` SELECT from wallet pages | `list_wallet_ledger_for_staff` |
| `get_wallet_account_balances` from wallet detail mount | `get_wallet_detail_for_staff` |

**Do not revoke** from domain RPCs — they run as `postgres` / definer.

### Repository mapping after P5b

| Remove from `walletRepository` | Add to `walletRepository` or `walletDetailRepository` |
| :--- | :--- |
| `recordTransaction` | `recordManualTransaction` → `record_wallet_manual_transaction_for_staff` |
| `fetchLedgerEntries` | `fetchLedgerForStaff` → `list_wallet_ledger_for_staff` |
| — | `fetchDetail` → `get_wallet_detail_for_staff` |
| — | `reverseEntry` → `reverse_wallet_ledger_entry_for_staff` |

`UniversalWalletPage.vue`: remove `fetchEntityName()`, `useWalletAccounts` + `useWalletQuery` on mount; single `get_wallet_detail_for_staff` load.

---

## P7 — Schema column + overload cleanup

After P0–P6 verified in production:

| Drop | Notes |
| :--- | :--- |
| `wallet_accounts.tenant_id` | Balances keyed on `parent_tenant_id` |
| `universal_wallet_ledger.tenant_id` | Ledger keyed on `parent_tenant_id` + `operating_tenant_id` |
| Unique index on `(tenant_id, entity_type, entity_id, currency_code)` | Replaced by parent unique |
| Deprecated `record_ledger_transaction(p_tenant_id …)` overload | If added for compat |
| `billing_profile_wallet_ledger` | Already dropped — remove any schema references in `public.sql` |

---

## Navigation / module keys (optional P8d)

| Key | Action |
| :--- | :--- |
| `billing_profile_wallet` in `moduleRegistry.ts` | Remove if no routes grant it; universal wallet replaced it |

---

## Master checklist

### P8a — Backend zombies

- [ ] `DROP dispense_middleman_payout`
- [ ] Remove `ensure_dropship_invoice_billed_entry` calls + `DROP FUNCTION`
- [ ] Fix `get_courier_unremitted_financial_summary` → UWL `dropship_profit`
- [ ] Scrub `billing_profile_wallet_ledger` references from `public.sql` schema
- [ ] `pnpm run backend:types`

### P8b — Frontend dead code

- [ ] Delete 6 unused Vue components (see table above)
- [ ] Remove / shrink `useWalletMutations.ts`
- [ ] P5b: `UniversalWalletPage` on new RPCs only
- [ ] Remove `fetchEntityName` direct table queries

### P8c — Grants & repository

- [ ] `REVOKE EXECUTE ON record_ledger_transaction FROM authenticated`
- [ ] Wallet repository uses staff RPCs only for write + ledger list on detail page

### P7 — Schema

- [ ] Drop legacy `tenant_id` columns + old unique constraints
- [ ] Drop deprecated `record_ledger_transaction` overload if any

### Verify

```bash
rg 'dispense_middleman_payout[^_]' web supabase/schemas --glob '!*.bak'
rg 'billing_profile_wallet_ledger' supabase/schemas
rg 'WalletDepositModal|WalletWithdrawModal|UniversalWallet\.vue' web
rg 'record_ledger_transaction' web/src/modules/wallet
pnpm run backend:reset
```

---

## RPC spec index (replacement)

| Doc | RPCs |
| :--- | :--- |
| [`LIST_WALLET_ENTITIES_RPC.md`](./LIST_WALLET_ENTITIES_RPC.md) | `list_wallet_entities_for_staff` |
| [`UNIVERSAL_WALLET_DETAIL_RPC.md`](./UNIVERSAL_WALLET_DETAIL_RPC.md) | Detail, ledger list, manual tx, reversal |
| [`RECORD_LEDGER_SYSTEM_RPC_MIGRATION.md`](./RECORD_LEDGER_SYSTEM_RPC_MIGRATION.md) | Domain writers (keep `record_ledger_transaction` internal) |

---

*Created 2026-08-27 — retirement slice for parent-books + new wallet RPC rollout.*
