# Dashboard & Insights — Page-to-API Matrix

Mapping of all dashboard shells, dynamic slot hosts, operational attention lists, and customer overview cards to their corresponding Supabase RPCs, database operations, and TanStack Vue Query cache keys.

---

## 📊 Interaction & Endpoint Matrix

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation / Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **`AdminDashboard`** | Mount / Workspace Switch | `useDashboardSlots` | Client-side slot resolution | Synchronous computation |
| **`DashboardAttentionList`** | Mount / Refresh | `useDashboardAttentionQuery` | Aggregated attention queries | `staleTime: 30s` |
| **`ProcurementStockCard`** | Mount | `useProcurementDashboardQuery` | `RPC: get_procurement_dashboard_metrics` | Cached on `['procurementStock', 'dashboard']` |
| **`SalesInvoiceCard`** | Mount | `useSalesInvoiceDashboardQuery` | `RPC: get_sales_invoice_dashboard_metrics` | Cached on `['sales_invoice', 'dashboard']` |
| **`CustomerDashboard`** | Mount / Storefront Home | `useCustomerDashboardQuery` | `RPC: get_customer_dashboard_summary` | Cached on `dashboardQueryKeys.customerSummary` |
