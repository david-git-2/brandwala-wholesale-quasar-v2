# Investor capital — API contract

`SECURITY DEFINER` RPCs. Signatures in `supabase/schemas/` / migrations — intent only here.

## App — profile

| RPC | Purpose |
| :--- | :--- |
| `list_investor_profiles` | Staff investor list (aggregates from wallet + batches **target**) |
| `upsert_investor_profile` | Create/update identity |

## App — detail (capital + shipments)

| RPC | Purpose |
| :--- | :--- |
| `record_investor_capital_in` | Investment in → tenant + investor UWL (+ `investor_transactions` as-built IC4) |
| `record_investor_withdrawal_paid` | Withdraw paid → debit investor + tenant cash |
| `record_investor_capital_adjustment` | Staff correction |
| `list_investor_allocations` | Shipment table for one investor (`p_tenant_id`, `p_investor_id`) |
| `upsert_shipment_investment` | Amount + `cost_share_pct` on a shipment |
| `update_shipment_investment_cost_share` | Adjust % |
| `refresh_shipment_investor_profits` | Recompute profit; post pending credit when realized |
| `get_investor_capital_report` | Optional detail history / report range |

## Investor scope — read

| RPC | Purpose |
| :--- | :--- |
| `get_investor_bootstrap_context` | Login session + tenant + investor id |
| `get_investor_dashboard_summary` | Dashboard totals |
| `list_investor_allocations` | Shipment list (investment + profit) |
| `get_investor_portfolio_summary` | As-built bootstrap helper; prefer dashboard summary in UI target |

## Not in this module

Receipts → [wallet](../wallet/03-api-contract.md). Membership → [tenant_auth](../tenant_auth/03-api-contract.md).
