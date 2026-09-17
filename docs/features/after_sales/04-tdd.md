# After-Sales & Returns — Technical Design Document (TDD)

> **Frontend Module Target**: `web/src/modules/after_sales/`  
> **Repository Target**: `web/src/modules/after_sales/repositories/afterSalesRepository.ts`  
> **Query Keys**: `web/src/modules/after_sales/services/afterSalesQueryKeys.ts`

---

## 1. Component Architecture & Hierarchy

```text
web/src/modules/after_sales/
├── pages/
│   ├── ReturnsHubPage.vue                # Main case table with status tabs & search
│   ├── AfterSalesCaseDetailPage.vue      # RMA inspection desk & line outcome router
│   └── AfterSalesPoliciesPage.vue        # Parent return window & fee configuration
├── components/
│   ├── CreateRmaCaseDialog.vue           # Open new wholesale/dropship case modal
│   ├── DropshipIntakeLogDialog.vue       # External complaint logger modal
│   ├── RmaLineInspectionTable.vue        # Arrived quantity & outcome routing grid
│   └── RmaStatusChip.vue                 # Status badge component
└── services/
    ├── afterSalesRepository.ts           # Supabase RPC invocation layer
    └── afterSalesQueryKeys.ts            # TanStack query keys
```

---

## 2. Server State Management & TanStack Query Keys

```typescript
export const afterSalesQueryKeys = {
  all: ['afterSales'] as const,
  cases: (parentTenantId: string, params?: Record<string, unknown>) =>
    [...afterSalesQueryKeys.all, 'cases', { parentTenantId, ...params }] as const,
  caseDetail: (caseId: string) =>
    [...afterSalesQueryKeys.all, 'caseDetail', caseId] as const,
  policies: (parentTenantId: string) =>
    [...afterSalesQueryKeys.all, 'policies', parentTenantId] as const,
};
```

---

## 3. UI Implementation Patterns & Governance Invariants

1. **Hub-First Navigation**: All returns and complaints originate from the Returns Hub (`/app/after-sales`); remove redundant standalone return buttons from invoice view toolbars.
2. **Strict Outcome Execution**: Outcome buttons (`Credit`, `Replace`, `Repair`) are unlocked only after items are received and inspected.
3. **Immutable Policy Snapshot**: Case detail view renders the frozen policy snapshot taken at creation time rather than current live policy settings.
