# Investor capital — API contract

`SECURITY DEFINER` RPCs. Signatures in `supabase/schemas/` / migrations — intent only here.

## App — profile

| RPC | Purpose |
| :--- | :--- |
| `list_investor_profiles` | Staff investor list (aggregates from wallet + batches **target**) |
| `upsert_investor_profile` | Create/update identity; syncs portal `memberships` (`role = investor` or links `investor_id` on existing email) |

## App — detail (capital + shipments)

| RPC | Purpose |
| :--- | :--- |
| `record_investor_capital_in` | Investment in → tenant + investor UWL (`jsonb` result) |
| `record_investor_withdrawal_paid` | Withdraw paid → debit investor + tenant cash (`jsonb`) |
| `record_investor_capital_adjustment` | Staff correction (`jsonb`) |
| `list_investor_wallet_activity` | Capital ledger history (UWL, staff or own investor) |
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
| `list_investor_wallet_activity` | Activity ledger (chronological UWL) |
| `get_investor_portfolio_summary` | Bootstrap + portal dashboard cards; totals from UWL + wallet + `shipment_investments` (not legacy journal) |

## Not in this module

Receipts → [bills_pays](../bills_pays/03-api-contract.md). Membership → [tenant_auth](../tenant_auth/03-api-contract.md).
