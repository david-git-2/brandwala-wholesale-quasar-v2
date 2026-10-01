# Bills & pays — TDD

Code: `web/src/modules/sales_invoice/` and `web/src/modules/wallet/`.

## A. Bill desk

---

## 1. Component Architecture & Hierarchy

```text
web/src/modules/sales_invoice/
├── pages/
│   ├── InvoicesListPage.vue              # Row list browse + filters (not q-table)
│   ├── CreateWholesaleInvoicePage.vue    # Trade/retail composer desk
│   ├── InvoiceDetailsPage.vue            # Issued/read desk + walk-in draft edit
│   ├── WholesaleInvoiceReturnPage.vue    # Return line items with restocking fee deduction
│   ├── InvoicePreviewPage.vue            # Clean print voucher preview with barcode
│   └── InvoiceBrandsPage.vue             # Invoice branding & print template settings
├── components/
│   ├── InvoiceListRow.vue                # Browse list row (customer, money, status)
│   ├── InvoiceDeskChrome.vue             # Shared sticky chrome (create + details)
│   ├── InvoicePartiesStrip.vue           # Brand + bill-to cards
│   ├── InvoiceStockSearchBar.vue         # FIFO search + inline results list
│   ├── InvoiceLinesTable.vue             # Dense line grid (edit + read modes)
│   ├── InvoiceTotalsPanel.vue            # Sticky totals sidebar
│   ├── NetworkStockSearchPanel.vue       # Walk-in draft stock dialog (shows cost)
│   ├── InvoiceBulkPasteDialog.vue        # Walk-in bulk paste
│   ├── WholesaleCollectPaymentDialog.vue # Multi-instrument collect
│   └── WholesaleIssueConfirmDialog.vue   # Stock commitment confirm
└── services/
    ├── salesInvoiceRepository.ts         # Supabase RPC invocation layer
    └── salesInvoiceQueryKeys.ts          # TanStack query keys
```

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
