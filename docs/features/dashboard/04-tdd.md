# Dashboard & Insights — Technical Design Document (TDD)

> **Frontend Module Target**: `web/src/modules/dashboard/`  
> **Registry Target**: `web/src/modules/dashboard/registry/dashboardSlotRegistry.ts`  
> **Resolver Target**: `web/src/modules/dashboard/composables/useDashboardSlots.ts`

---

## 1. Component Architecture & Hierarchy

```text
web/src/modules/dashboard/
├── pages/
│   ├── AdminDashboard.vue                # Operational work desk shell
│   ├── CustomerDashboard.vue             # B2B storefront customer home
│   └── SuperadminDashboard.vue           # Global platform infrastructure monitor
├── components/
│   ├── DashboardAttentionList.vue        # Priority work queue list
│   ├── DashboardPulseCard.vue            # Featured metric pulse cards
│   ├── DashboardSlotHost.vue             # Dynamic widget loader & error boundary
│   └── CustomerDashboardStatusStrip.vue  # Interactive status donut strip
└── registry/
    └── dashboardSlotRegistry.ts          # Central registry of all module slots
```

---

## 2. Server State Management & TanStack Query Keys

```typescript
export const dashboardQueryKeys = {
  all: ['dashboard'] as const,
  customerSummary: (tenantId: string) =>
    [...dashboardQueryKeys.all, 'customerSummary', tenantId] as const,
  attentionQueue: (parentTenantId: string) =>
    [...dashboardQueryKeys.all, 'attentionQueue', parentTenantId] as const,
};
```

---

## 3. UI Implementation Patterns & Guidelines

1. **Operational Work Desk**: The admin dashboard is an action desk, not a vanity image gallery.
2. **Dynamic Slot Mounting**: Never hardcode feature widgets inside `AdminDashboard.vue`. Mount them via `DashboardSlotHost.vue`.
3. **No Fake Stubs**: Modules in development render `DashboardStubBadge` and must not inject fake active counts into the attention list.
