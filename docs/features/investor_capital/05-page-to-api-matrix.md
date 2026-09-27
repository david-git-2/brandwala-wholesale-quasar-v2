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
| `CapitalLedgerPage` | `list_investor_wallet_activity`, `record_investor_*` |
| `ShipmentAllocationsPage` / `ShipmentAllocationDetailsPage` | `upsert_shipment_investment`, refresh RPC |
| Shipment gear → More → **Investor investment** (`ShipmentInvestorInvestmentPage`) | `list_investor_profiles`, `shipment_investments` by shipment, `upsert_shipment_investment` (amount → cost share %) |

## Investor scope (as-built)

| Route | Page | Action | Backend |
| :--- | :--- | :--- | :--- |
| `/:slug/investor/login` | `InvestorLoginPage` | Bootstrap | `get_investor_bootstrap_context` |
| `/:slug/investor` | `InvestorPortfolioPage` (Dashboard) | Load totals | `get_investor_portfolio_summary` |
| `/:slug/investor/shipments` | `InvestorAllocationsPage` (Shipments) | Load list | `list_investor_allocations` |

Legacy paths `/portfolio`, `/allocations`, `/profit`, `/activity` redirect to dashboard or shipments.

## Investor scope (target — aligned)

| Page | Action | Backend |
| :--- | :--- | :--- |
| Login | Bootstrap | `get_investor_bootstrap_context` |
| Dashboard | Load | `get_investor_dashboard_summary` or portfolio summary RPC |
| Shipments | Load | `list_investor_allocations` |
