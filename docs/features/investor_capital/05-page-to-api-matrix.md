# Investor capital — page-to-API matrix

## App scope (target)

| Page / component | Action | Client | Backend |
| :--- | :--- | :--- | :--- |
| Investor list | Load | `store.fetchInvestorsByTenant` | `list_investor_profiles` (or balance list RPC) |
| Add / edit profile | Save | `InvestorProfileDialog` | `upsert_investor_profile` |
| Detail | Capital in | `recordCapitalIn` | `record_investor_capital_in` |
| Detail | Withdraw | `recordWithdrawalPaid` | `record_investor_withdrawal_paid` |
| Detail | Load shipments | list action | `list_investor_allocations` (`p_investor_id`) |
| Detail | Save shipment row | `saveShipmentInvestment` | `upsert_shipment_investment` |
| Detail | Refresh batch profit | optional | `refresh_shipment_investor_profits` |

Portal membership: `investor_id` on membership — [tenant_auth](../tenant_auth/01-prd.md).

## App scope (as-built only — IC7)

| Page | Backend |
| :--- | :--- |
| `InvestorProfilesPage` | same list RPC |
| `CapitalLedgerPage` | `list_investor_transactions` |
| `ShipmentAllocationsPage` / `ShipmentAllocationDetailsPage` | `upsert_shipment_investment`, refresh RPC |

## Investor scope (target)

| Page | Action | Backend |
| :--- | :--- | :--- |
| Login | Bootstrap | `get_investor_bootstrap_context` |
| Dashboard | Load | `get_investor_dashboard_summary` |
| Shipments | Load | `list_investor_allocations` |

## Investor scope (as-built only — IC6)

| Page | Notes |
| :--- | :--- |
| `InvestorPortfolioPage`, `InvestorAllocationsPage`, `InvestorProfitReportPage`, `InvestorActivityPage` | Consolidate to dashboard + shipments |
