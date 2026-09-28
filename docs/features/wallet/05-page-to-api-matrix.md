# Universal Wallet & Ledger — Page-to-API Matrix

Mapping of all UI views, actions, modals, and adjustments to their corresponding Supabase RPCs, database operations, and TanStack Vue Query cache keys.

---

## 📊 Interaction & Endpoint Matrix

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation / Optimistic Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **`WalletEntityListPage`** | Mount / Filter Change | `useWalletEntityDirectoryQuery` | `RPC: list_wallet_entities_for_staff` | Cached on `walletQueryKeys.entityDirectory` (`staleTime: 30s`) |
| **`UniversalWalletPage`** | Mount / Entity Select | `useWalletDetailQuery` | `RPC: get_wallet_detail_for_staff` | Cached on `walletQueryKeys.detail` |
| **`UniversalWalletPage`** | Ledger Pagination / Filter | `useWalletLedgerQuery` | `RPC: list_wallet_ledger_for_staff` | Cached on `walletQueryKeys.ledgerList` |
| **`WalletActionModal`** | Submit Manual Credit / Debit | `useRecordManualTxMutation` | `RPC: record_ledger_transaction` | Refetches detail balances & ledger history |
| **`WalletTransferModal`** | Submit Inter-Wallet Transfer | `useTransferFundsMutation` | `RPC: transfer_wallet_funds` | Invalidates source and destination wallet caches |
| **`UniversalWalletLedgerTable`**| Click "Reverse Transaction"| `useReverseTxMutation` | `RPC: reverse_wallet_ledger_entry_for_staff` | Appends reversing entry; updates balances |
| **`MerchantWalletPage`** | Storefront Reseller Statement | `useMerchantWalletSummaryQuery`| `RPC: get_my_dropship_wallet_summary` | Cached on `shopOrderQueryKeys.merchantWallet` |
| **`PaymentsPage`** | Parent tenant cash (cash in / cash out toolbar) | `useWalletAccounts` → `fetchDashboardSummary` | `get_wallet_dashboard_summary` (`tenant_cash_total`, parent books) | `walletQueryKeys.dashboardSummary` |
| **`PaymentsPage`** | Tab Cash in / Cash out | `side` query `in` \| `out` | — | — |
| **`PaymentsPage`** | Cash in → Customer / Invoice row actions | `router.push` → collect route | — | — |
| **`PaymentsPage`** | Cash in → Courier remittance submit | `useDropshipFinanceHubMutations.confirmCourierRemittanceMutation` | `record_dropship_courier_bank_transfer` (via hub repository) | Finance hub query keys |
| **`PaymentsPage`** | Cash out → search customer group | `paymentsRepository.listCustomerGroupsPayoutSummary` | `list_customer_groups_payout_summary` | `financeReportQueryKeys` + `payout-groups` |
| **`PaymentsMerchantPayoutPanel`** | Cash out → submit payout | `useDropshipFinanceHubMutations.dispenseMiddlemanPayoutMutation` | `dispense_middleman_payout_from_tenant` (per billing profile wallet) | dashboard + hub |
| **`CollectCustomerPaymentPage`** | Post receipt | `usePayments.recordPayment` | `collect_wholesale_invoice_payment` / billing-profile collect RPCs | `financeReportQueryKeys.*` |
| **`CustomerPaymentHistoryDrawer`** | Void receipt | `usePayments.voidCustomerReceipt` | `void_customer_receipt` | Refetch customer summary |
