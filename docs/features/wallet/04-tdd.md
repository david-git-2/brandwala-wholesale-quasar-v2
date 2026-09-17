# Universal Wallet & Ledger — Technical Design Document (TDD)

> **Frontend Module Target**: `web/src/modules/wallet/`  
> **Repository Target**: `web/src/modules/wallet/repositories/walletRepository.ts`  
> **Query Keys**: `web/src/modules/wallet/shared/queryKeys/walletQueryKeys.ts`

---

## 1. Component Architecture & Hierarchy

```text
web/src/modules/wallet/
├── pages/
│   ├── WalletHomePage.vue                # Entity category selector cards
│   ├── WalletEntityListPage.vue          # Directory list with search & balances
│   └── UniversalWalletPage.vue           # Detail view: running balances, ledger & actions
├── components/
│   ├── UniversalWalletLedgerTable.vue    # Chronological ledger table with audit badges
│   ├── WalletActionModal.vue             # Manual credit/debit adjustment modal
│   ├── WalletTransferModal.vue           # Inter-wallet funds transfer dialog
│   └── WalletBalanceHeader.vue           # Multi-currency current/unsettled chips
└── repositories/
    └── walletRepository.ts               # Supabase RPC invocation client
```

---

## 2. Server State Management & TanStack Query Keys

```typescript
export const walletQueryKeys = {
  all: ['wallet'] as const,
  entityDirectory: (parentTenantId: string, entityType: string, params?: Record<string, unknown>) =>
    [...walletQueryKeys.all, 'entityDirectory', { parentTenantId, entityType, ...params }] as const,
  detail: (parentTenantId: string, entityType: string, entityId: string) =>
    [...walletQueryKeys.all, 'detail', { parentTenantId, entityType, entityId }] as const,
  ledgerList: (parentTenantId: string, entityType: string, entityId: string, params?: Record<string, unknown>) =>
    [...walletQueryKeys.all, 'ledgerList', { parentTenantId, entityType, entityId, ...params }] as const,
  balance: (params: Record<string, unknown>) =>
    [...walletQueryKeys.all, 'balance', params] as const,
  cashIn: (parentTenantId: string, params?: Record<string, unknown>) =>
    [...walletQueryKeys.all, 'cashIn', { parentTenantId, ...params }] as const,
};
```

---

## 3. Key Design Rules & Conventions

1. **Books Tenant Scoping**: UI components must always query with `wallet_books_tenant_id = parent_id ?? id`.
2. **Never Shadow-Mutate Balances**: Do not manually calculate `balance_after` in the frontend; always reflect the server-stamped authoritative balances from `universal_wallet_ledger`.
3. **No Direct Row Deletion**: Ledger entries cannot be deleted; provide an explicit **Reverse Entry** button invoking `reverse_wallet_ledger_entry_for_staff`.
