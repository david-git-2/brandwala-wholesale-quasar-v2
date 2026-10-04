# Bills & pays — TDD

Code: **Bills + Payments + Cashbook** `web/src/modules/bills_pays/`. Bill reads/writes reuse `invoiceRepository.ts`. Pays: `paysRepository.ts`. Cashbook: `cashbookRepository.ts` (live RPC names `wallet_*` until BP2). Dropship remittance: `dropshipFinanceRepository.ts`.

## A. Bill desk

---

## 1. Component Architecture & Hierarchy

```text
web/src/modules/bills_pays/
├── pages/
│   ├── BillsPage.vue                     # Ops list browse + status pills
│   └── BillDetailPage.vue                # Read issued bill; void + print
├── components/
│   └── BillListRow.vue                   # List row (profile, sell, status)
├── composables/
│   ├── useBillsListQuery.ts
│   ├── useBillDetailQuery.ts
│   └── useVoidBillMutation.ts
└── services/
    └── billsQueryKeys.ts

# Later slices (not mounted): walk-in composer, returns, branding — reuse sales_invoice/ types + RPCs.
```

## B. Payments desk

```text
web/src/modules/bills_pays/
├── pages/
│   ├── PaymentsPage.vue
│   ├── CollectPayPage.vue
│   ├── RemitPayPage.vue
│   ├── PayoutPayPage.vue
│   └── PayDetailPage.vue
├── components/
│   └── PayListRow.vue
├── composables/
│   ├── usePaysListQuery.ts
│   ├── useCollectPayMutation.ts
│   └── useVoidPayMutation.ts
├── repositories/
│   └── paysRepository.ts
└── services/
    └── paysQueryKeys.ts
```

## C. Cashbook desk (read-only)

```text
web/src/modules/bills_pays/
├── pages/
│   ├── CashbookPage.vue
│   └── CashbookPartyPage.vue
├── components/
│   └── CashbookEntityRow.vue
├── composables/
│   ├── useCashbookEntitiesQuery.ts
│   └── useCashbookPartyQuery.ts
├── repositories/
│   └── cashbookRepository.ts
└── services/
    └── cashbookQueryKeys.ts
```

Ledger rows are not deleted in UI; **reverse** and manual credit/debit stay out of scope until US-6.

---

## 2. Server State Management & TanStack Query Keys

```typescript
export const salesInvoiceQueryKeys = {
  root: ['sales_invoice'] as const,
  list: (parentTenantId: string, params?: Record<string, unknown>) =>
    [...salesInvoiceQueryKeys.root, 'list', parentTenantId, params] as const,
  detail: (invoiceId: string) =>
    [...salesInvoiceQueryKeys.root, 'detail', invoiceId] as const,
  stockSearch: (tenantId: string, query?: string) =>
    [...salesInvoiceQueryKeys.root, 'stock_search', tenantId, query] as const,
  walletBalances: (tenantId: string) =>
    [...salesInvoiceQueryKeys.root, 'wallet_balances', tenantId] as const,
  brands: (tenantId: string) =>
    [...salesInvoiceQueryKeys.root, 'brands', tenantId] as const,
};
```

---

## 3. Implementation Workflow & Interaction Protocol

1. **Atomic Create / Edit**: Create flow targets `create_sales_invoice_from_payload` with the full document; patch updates target `update_sales_invoice_from_payload` sending only changed fields.
2. **Immutable Returns**: Return modal updates line return quantities and invoice header totals without mutating `quantity` sold.
3. **Atomic Collect Modal**: The collect dialog computes real-time maximum allowable amounts for cash, store credit, and settlements before invoking payment allocation.

## B. Pay & cashbook desk

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
2. **Never Shadow-Mutate Balances**: Use server-stamped balances from `cashbook_entries` (live `universal_wallet_ledger`).
3. **No Direct Row Deletion**: Ledger entries cannot be deleted; provide an explicit **Reverse Entry** button invoking `reverse_wallet_ledger_entry_for_staff`.
