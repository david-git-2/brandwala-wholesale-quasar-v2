# Investor capital — TDD

UI: `web/src/modules/investor_capital/`, `investor_portal/`. State: Pinia `investorCapitalStore` + portal store/repo.

## App scope (target)

```text
investor_capital/pages/admin/
  InvestorManagementListPage.vue   # target; as-built InvestorProfilesPage.vue
  InvestorDetailPage.vue           # target hub — not built
  InvestorProfileDialog.vue
  InvestorTransactionDialog.vue    # capital in / withdraw on detail
investor_capital/components/
  ShipmentShareEditor.vue          # add/edit row on detail shipment table
```

**As-built (legacy nav, IC7):** `CapitalLedgerPage.vue`, `ShipmentAllocationsPage.vue`, `ShipmentAllocationDetailsPage.vue`.

Routes target: `/:tenantSlug/app/capital/investors`, `.../investors/:id`.

## Investor scope (target)

```text
investor_portal/
  InvestorLoginPage.vue
  InvestorDashboardPage.vue        # as-built InvestorPortfolioPage.vue
  InvestorShipmentsPage.vue        # as-built may be InvestorAllocationsPage.vue
```

`InvestorLayout.vue`: two nav items — Dashboard, Shipments.

**As-built (IC6):** routes `portfolio`, `allocations`, `profit`, `activity`.

## Invariants

| # | Rule |
| :--- | :--- |
| 1 | Sum of `cost_share_pct` on one shipment ≤ 100% |
| 2 | Yield from shipment P&amp;L × share |
| 3 | Portal `scope = investor`, module `investor_portal`, read-only |
| 4 | Staff capital actions only on app detail (or dialog from detail) |
| 5 | Wallet is cash source of truth (IC4 for journal cleanup) |

## Store

Pinia `investorCapitalStore` for app list/detail; `investorPortalStore` / repository for portal dashboard + `list_investor_allocations`.
