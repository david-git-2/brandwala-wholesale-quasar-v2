# Bills & pays — page → API

## A. Bills

---

## 📊 Interaction & Endpoint Matrix

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation / Optimistic Update |
| :--- | :--- | :--- | :--- | :--- |
| **`BillsPage`** | Mount / filter / search | `useBillsListQuery` | `Table: bills` (+ `profiles` join) via `invoiceRepository.listGlobalInvoices` | `billsQueryKeys.list` (`staleTime: 30s`) |
| **`BillDetailPage`** | Mount | `useBillDetailQuery` | `Table: bills` + `RPC: list_global_invoice_items` | `billsQueryKeys.detail` / `items` |
| **`BillDetailPage`** | Void (issued, unpaid) | `useVoidBillMutation` | `RPC: void_sales_invoice` | Invalidates `billsQueryKeys` root + detail |
| **`BillDetailPage`** | Print | `window.print()` | — | — |
| *(later)* **`CreateWholesaleInvoicePage`** | Composer / issue | — | `RPC: create_sales_invoice_from_payload` | Not on Bills desk yet |
| *(later)* collect on bill | — | — | `post_customer_receipt_with_allocations` | **Payments** desk, not Bills |
| **`StaffOrderDetailPage`** | Fulfill to invoice (catalog only) | `useFulfillOrderToInvoiceMutation` | `RPC: fulfill_shop_order_to_invoice` → `create_sales_invoice_from_payload` | **Live:** issues bill. **Target:** Delivery paper close ([SI19](00-gaps.md)) |
| **`WholesaleInvoiceReturnPage`** | Submit Credit Return | `useWholesaleReturnMutation`| `RPC: process_wholesale_invoice_return` | Updates `return_quantity`, restocks to `held` |
| **`DropshipOrderDetailV2ReadyForPickupPage`** | Mark as shipped | `shopOrderService.shipDropshipOrderAndIssueMerchantBill` | `RPC: ship_dropship_order_and_issue_merchant_bill` | Merchant bill from picks + `shipped` |
| **`DropshipManagementDetailPage`** | Mark as delivered | `markDropshipOrderDelivered` only | `RPC: mark_dropship_order_delivered` | Does **not** issue invoice or post cash |
| **`shop_order` packing slip preview** | Print packing slip | local snapshot + preview route | No `sales_invoices` row | Recipient COD face lives on order / `channel_meta`, not the merchant bill |

## B. Pays

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
| **`PaymentsMerchantPayoutPanel`** | Cash out → submit payout | `useDropshipFinanceHubMutations.dispenseMiddlemanPayoutMutation` | `dispense_middleman_payout_from_tenant` (shop profile cashbook) | dashboard + hub |
| **`CollectCustomerPaymentPage`** | Post receipt | `usePayments.recordPayment` | `collect_wholesale_invoice_payment` / profile collect RPCs | `financeReportQueryKeys.*` |
| **`CustomerPaymentHistoryDrawer`** | Void receipt | `usePayments.voidCustomerReceipt` | `void_customer_receipt` | Refetch customer summary |
