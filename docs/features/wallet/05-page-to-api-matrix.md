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
