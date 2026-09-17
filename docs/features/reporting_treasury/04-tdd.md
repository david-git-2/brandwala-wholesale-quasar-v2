# Reporting & Treasury — Technical Design Document (TDD)

> **Frontend Module Target**: `web/src/modules/reporting_treasury/`  
> **Repository Target**: `web/src/modules/reporting_treasury/repositories/treasuryRepository.ts`  
> **Query Keys**: `web/src/modules/reporting_treasury/`

---

## 1. Component Architecture & Hierarchy

```text
web/src/modules/reporting_treasury/
├── pages/
│   ├── ParentDashboardPage.vue           # Executive KPI tiles & revenue charts
│   ├── InvoiceMarginReportPage.vue       # Net revenue vs unit landed cost margins
│   ├── InvoiceMarginDetailPage.vue       # Line-by-line margin audit breakdown
│   ├── ShipmentsListPage.vue             # Shipment batch profitability register
│   ├── ShipmentPnLDetailsPage.vue        # Landed cost vs realized GP & shrinkage
│   ├── BillingBalancesPage.vue           # Customer AR dues & bulk payment desk
│   ├── PaymentsListPage.vue              # Received payment register & allocations
│   ├── PaymentDetailPage.vue             # Payment allocation breakdown across invoices
│   └── CashInReportPage.vue              # Liquid cash till view by payment method
├── components/
│   ├── TreasuryStatGrid.vue              # High-level financial metric cards
│   ├── TreasuryFilterBar.vue             # Date range, tenant & channel filter bar
│   └── TreasuryTableWrap.vue             # Compact financial data grid wrapper
└── repositories/
    └── treasuryRepository.ts             # Supabase RPC invocation client
```

---

## 2. Server State Management & TanStack Query Keys

```typescript
export const treasuryQueryKeys = {
  all: ['treasury'] as const,
  reports: (type: string, params?: Record<string, unknown>) =>
    [...treasuryQueryKeys.all, 'reports', type, params] as const,
  invoicesMargin: (tenantId: string, params?: Record<string, unknown>) =>
    [...treasuryQueryKeys.all, 'invoicesMargin', { tenantId, ...params }] as const,
  shipmentPnL: (shipmentId: string) =>
    [...treasuryQueryKeys.all, 'shipmentPnL', shipmentId] as const,
  billingBalances: (tenantId: string, search?: string) =>
    [...treasuryQueryKeys.all, 'billingBalances', { tenantId, search }] as const,
  payments: (tenantId: string, params?: Record<string, unknown>) =>
    [...treasuryQueryKeys.all, 'payments', { tenantId, ...params }] as const,
};
```

---

## 3. UI Design Standards & CSV Exporting

1. **KPI Stat Grid**: Metric summary cards use flat styling with soft tinted accent indicators.
2. **Dynamic Range Filtering**: Report query parameters are debounced and synced to URL query strings for shareable links.
3. **CSV Export Utility**: All report tables include a top toolbar `Export CSV` button for offline spreadsheets.
