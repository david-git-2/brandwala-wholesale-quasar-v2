# Sales Invoice — Technical Design Document (TDD)

> **Frontend Module Target**: `web/src/modules/sales_invoice/`  
> **Repository Target**: `web/src/modules/sales_invoice/repositories/salesInvoiceRepository.ts`  
> **Query Keys**: `web/src/modules/sales_invoice/services/salesInvoiceQueryKeys.ts`

---

## 1. Component Architecture & Hierarchy

```text
web/src/modules/sales_invoice/
├── pages/
│   ├── InvoicesListPage.vue              # Ops table with filters and payment status badges
│   ├── CreateWholesaleInvoicePage.vue    # Full desk with FIFO stock picker & bulk paste
│   ├── InvoiceDetailsPage.vue            # Invoice breakdown, payment history & return activity
│   ├── WholesaleInvoiceReturnPage.vue    # Return line items with restocking fee deduction
│   ├── InvoicePreviewPage.vue            # Clean print voucher preview with barcode
│   └── InvoiceBrandsPage.vue             # Invoice branding & print template settings
├── components/
│   ├── NetworkStockSearchPanel.vue       # Live FIFO stock selector with ATP badges
│   ├── InvoiceBulkPasteDialog.vue        # Fast tab-delimited batch item paste
│   ├── WholesaleIssueConfirmDialog.vue   # Stock commitment & AR confirmation
│   ├── InvoicePaymentCollectDialog.vue   # Atomic cash + wallet credit collection
│   └── InvoiceStatusBadge.vue            # Lifecycle & payment status chip
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
