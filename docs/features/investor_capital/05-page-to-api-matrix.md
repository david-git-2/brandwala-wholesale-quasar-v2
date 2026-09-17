# Investor Portal & Capital — Page-to-API Matrix

Mapping of all capital partner profiles, ledger records, shipment batch allocations, and investor portal views to their corresponding Supabase RPCs, database operations, and Pinia stores.

---

## 📊 Interaction & Endpoint Matrix

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation / State Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **`InvestorProfilesPage`** | Mount / Refresh | `store.fetchInvestorsByTenant` | `RPC: list_investor_profiles` | Pinia `investors` list update |
| **`InvestorProfileDialog`** | Save Partner Profile | `store.createInvestor` | `RPC: upsert_investor_profile` | Refetches profile list on success |
| **`CapitalLedgerPage`** | Mount / Filter by Type | `store.fetchTransactions` | `RPC: list_investor_transactions` | Pinia `transactions` state update |
| **`InvestorTransactionDialog`**| Submit Capital Deposit | `store.recordCapitalIn` | `RPC: record_investor_capital_in` | Refetches transactions & balance chips |
| **`InvestorTransactionDialog`**| Submit Withdrawal Payout | `store.recordWithdrawalPaid` | `RPC: record_investor_withdrawal_paid` | Debits investor & tenant liquid wallet |
| **`ShipmentAllocationDetails`**| Save Share Percentage | `store.saveShipmentInvestment`| `RPC: upsert_shipment_investment` | Refetches batch investment allocations |
| **`InvestorPortalOverview`** | Mount / Inspect Portfolio | `useInvestorPortalQuery` | `RPC: get_investor_portal_summary` | Cached on `['investorPortal', 'summary']` |
