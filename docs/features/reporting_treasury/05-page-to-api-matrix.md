# Reporting & Treasury — Page-to-API Matrix

As-built wiring. **Target:** report pages read only. `BillingBalancesPage` collect is wallet ([01-prd](01-prd.md) US-3). Snapshot/profit RPCs must follow money layers ([00-gaps](00-gaps.md)).

## Interaction matrix

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation / Optimistic Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **`ParentDashboardPage`** | Mount / Month Change | `useDashboardKpisQuery` | `RPC: get_tenant_month_snapshot_report` | Cached on `treasuryQueryKeys.reports('monthSnapshot')` |
| **`InvoiceMarginReportPage`** | Mount / Date Range Filter | `useInvoiceMarginReportQuery` | `RPC: list_invoice_margin_report` | Cached on `treasuryQueryKeys.invoicesMargin` |
| **`InvoiceMarginDetailPage`** | Mount / Detail Inspect | `useInvoiceMarginDetailQuery` | `RPC: get_invoice_margin_detail` | Cached on invoice margin key |
| **`ShipmentPnLDetailsPage`** | Mount / Shipment Select | `useShipmentPnLQuery` | `RPC: get_tenant_shipment_profit_report` | Cached on `treasuryQueryKeys.shipmentPnL` |
| **`CashInReportPage`** | Mount / Payment Method Filter | `useCashInReportQuery` | `RPC: get_tenant_cash_in_report` | Cached on `walletQueryKeys.cashIn` |
| **`BillingBalancesPage`** | Settle Customer Invoices | `useAllocatePaymentMutation` | `RPC: create_billing_profile_payment_with_allocations` | Invalidates balances & invoice caches |
| **`PaymentsPage`** | Settle Dues / Pay | Navigate collect page | — | — |
| **`PaymentsPage`** | History | Open `CustomerPaymentHistoryDrawer` | `RPC: list_customer_group_receipts` | `financeReportQueryKeys.customerGroupReceipts` |
| **`CollectCustomerPaymentPage`** | Post Payment | `usePayments.recordPayment` | `RPC: record_batch_customer_payment` | Invalidates `financeReportQueryKeys` |
| **`CustomerPaymentHistoryDrawer`** | Fix instrument details | `usePayments.updateInstrumentDetails` | `RPC: update_payment_instrument_details` | Invalidates receipt history + finance root |
| **`CustomerPaymentHistoryDrawer`** | Void & re-enter | `usePayments.voidCustomerReceipt` | `RPC: void_customer_receipt` | Invalidates finance root; parent navigates to collect |
