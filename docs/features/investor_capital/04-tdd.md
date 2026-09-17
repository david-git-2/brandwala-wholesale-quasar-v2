# Investor Portal & Capital — Technical Design Document (TDD)

> **Frontend Module Target**: `web/src/modules/investor_capital/` and `web/src/modules/investor_portal/`  
> **Repository Target**: `web/src/modules/investor_capital/repositories/investorCapitalRepository.ts`  
> **Store Target**: `web/src/modules/investor_capital/stores/investorCapitalStore.ts`

---

## 1. Component Architecture & Hierarchy

```text
web/src/modules/investor_capital/
├── pages/admin/
│   ├── InvestorProfilesPage.vue          # Managing partners & active balances list
│   ├── CapitalLedgerPage.vue             # Financial ledger of all deposits and payouts
│   ├── ShipmentAllocationsPage.vue       # Inbound shipment batch allocation desk
│   └── ShipmentAllocationDetailsPage.vue # Per-shipment investor share editor & yield tracker
├── components/
│   ├── InvestorProfileDialog.vue         # Create/edit partner profile modal
│   ├── InvestorTransactionDialog.vue     # Deposit/withdrawal recording modal
│   └── ShipmentShareEditor.vue           # Percentage allocation sliders
└── stores/
    └── investorCapitalStore.ts           # Client state for profiles and investments

web/src/modules/investor_portal/
└── pages/
    └── InvestorPortalOverviewPage.vue    # External partner portfolio glance
```

---

## 2. Server State Management & Store Design

```typescript
export const useInvestorCapitalStore = defineStore('investorCapital', {
  state: () => ({
    investors: [] as InvestorProfile[],
    transactions: [] as InvestorTransaction[],
    shipmentInvestments: [] as ShipmentInvestment[],
    isLoading: false,
  }),
  actions: {
    async fetchInvestorsByTenant(parentTenantId: string) {
      this.isLoading = true;
      try {
        this.investors = await investorCapitalRepository.listInvestors(parentTenantId);
      } finally {
        this.isLoading = false;
      }
    },
  },
});
```

---

## 3. UI Implementation Patterns & Governance Invariants

1. **Strict 100% Allocation Limit**: Total `cost_share_pct` across all investors for a shipment cannot exceed 1.0 (100%).
2. **Read-Side Profit Derivation**: Yields update dynamically based on live shipment sales margins without posting synthetic accounting entries.
3. **Portal Route Scoping**: External investors are routed strictly to `/:slug/investor/*` under `InvestorLayout.vue`.
