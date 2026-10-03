# Bills & pays — page → API

## A. Bills

---

## 📊 Interaction & Endpoint Matrix

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation / Optimistic Update |
| :--- | :--- | :--- | :--- | :--- |
| **`InvoicesListPage`** | Mount / Filter Change | `useInvoicesListQuery` | `Table: sales_invoices` | Cached on `salesInvoiceQueryKeys.list` (`staleTime: 30s`) |
| **`CreateWholesaleInvoicePage`** (UI: **Trade / Retail** composer, route `/create`) | Search Stock Barcode/Name | `useStockSearchQuery` | `RPC: search_sales_invoice_stock` | Debounced query on `salesInvoiceQueryKeys.stockSearch` |
| **`CreateWholesaleInvoicePage`** | Save draft / proforma (chrome) | `handleSaveInvoice` → payload RPC | `RPC: create_sales_invoice_from_payload` / `update_sales_invoice_from_payload` | Appends to list cache; `?id=` on persist. `invoice_type=wholesale` or `retail` (`retail_billing_mode=account`) |
| **`CreateWholesaleInvoicePage`** | Issue (chrome dropdown or confirm) | `handleSaveInvoice('issued')` / `issue_wholesale_invoice` | `RPC: create_sales_invoice_from_payload` (`issue=true`) or `issue_wholesale_invoice` | Trade/B2B only. Deducts sellable ATP. Does **not** create dropship bills |
| **`InvoiceDetailsPage`** (UI: Invoice + type chip chrome) | Mount / Refresh | `loadInvoice` | `Table: sales_invoices` + lines join | Cached on `salesInvoiceQueryKeys.detail(id)` |
| **`InvoiceDetailsPage`** | Chrome **Issue** | `changeInvoiceStatus('issued')` | Issue / post RPCs as today | Deducts stock; does **not** post cash |
| **`InvoiceDetailsPage`** | Menu Void (if still wired) | `useVoidInvoiceMutation` | `RPC: void_sales_invoice` | Restores stock; invalidates detail & list |
| **`InvoiceDetailsPage`** | Apply Settlement Write-off | `useApplySettlementMutation` | `RPC: apply_global_invoice_settlement_discount` | Updates `due_amount` only; invalidates detail |
| **`WholesaleCollectPaymentDialog`** (create + detail) | Submit cash / store credit / settlement | `invoiceRepository.collectWholesaleInvoicePayment` | `RPC: collect_wholesale_invoice_payment` | Wholesale/retail cash-in on **this** bill. Not courier remittance |
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
