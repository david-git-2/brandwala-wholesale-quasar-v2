# Reporting & Treasury — Page-to-API Matrix

Mapping of all financial dashboards, treasury reports, payment desks, and CSV exports to their corresponding Supabase RPCs, database operations, and TanStack Vue Query cache keys.

---

## 📊 Interaction & Endpoint Matrix

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation / Optimistic Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **`ParentDashboardPage`** | Mount / Month Change | `useDashboardKpisQuery` | `RPC: get_tenant_month_snapshot_report` | Cached on `treasuryQueryKeys.reports('monthSnapshot')` |
| **`InvoiceMarginReportPage`** | Mount / Date Range Filter | `useInvoiceMarginReportQuery` | `RPC: list_invoice_margin_report` | Cached on `treasuryQueryKeys.invoicesMargin` |
| **`InvoiceMarginDetailPage`** | Mount / Detail Inspect | `useInvoiceMarginDetailQuery` | `RPC: get_invoice_margin_detail` | Cached on invoice margin key |
| **`ShipmentPnLDetailsPage`** | Mount / Shipment Select | `useShipmentPnLQuery` | `RPC: get_tenant_shipment_profit_report` | Cached on `treasuryQueryKeys.shipmentPnL` |
| **`CashInReportPage`** | Mount / Payment Method Filter | `useCashInReportQuery` | `RPC: get_tenant_cash_in_report` | Cached on `walletQueryKeys.cashIn` |
| **`BillingBalancesPage`** | Settle Customer Invoices | `useAllocatePaymentMutation` | `RPC: create_billing_profile_payment_with_allocations` | Invalidates balances & invoice caches |
| **`PaymentsListPage`** | Mount / Search Payments | `usePaymentsListQuery` | `Table: global_payments` | Cached on `treasuryQueryKeys.payments` |
