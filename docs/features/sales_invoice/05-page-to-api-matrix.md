# Sales Invoice — Page-to-API Matrix

Mapping of all UI controls, interactive buttons, modal triggers, and form submissions to their corresponding Supabase RPCs, database operations, and TanStack Vue Query cache keys.

---

## 📊 Interaction & Endpoint Matrix

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation / Optimistic Update |
| :--- | :--- | :--- | :--- | :--- |
| **`InvoicesListPage`** | Mount / Filter Change | `useInvoicesListQuery` | `Table: sales_invoices` | Cached on `salesInvoiceQueryKeys.list` (`staleTime: 30s`) |
| **`CreateWholesaleInvoicePage`** | Search Stock Barcode/Name | `useStockSearchQuery` | `RPC: search_sales_invoice_stock` | Debounced query on `salesInvoiceQueryKeys.stockSearch` |
| **`CreateWholesaleInvoicePage`** | Save Draft / Proforma | `useCreateInvoiceMutation` | `RPC: create_sales_invoice_from_payload` | Appends to list cache, redirects to detail |
| **`CreateWholesaleInvoicePage`** | Submit "Save & Issue" | `useCreateInvoiceMutation` (with `issue=true`) | `RPC: create_sales_invoice_from_payload` | Deducts warehouse ATP, sets AR balance |
| **`InvoiceDetailsPage`** | Mount / Refresh | `useInvoiceDetailQuery` | `Table: sales_invoices` + lines join | Cached on `salesInvoiceQueryKeys.detail(id)` |
| **`InvoiceDetailsPage`** | Click "Void Invoice" | `useVoidInvoiceMutation` | `RPC: void_sales_invoice` | Restores stock; invalidates detail & list |
| **`InvoiceDetailsPage`** | Apply Settlement Write-off | `useApplySettlementMutation` | `RPC: apply_global_invoice_settlement_discount` | Updates `due_amount` only; invalidates detail |
| **`InvoicePaymentCollectDialog`** | Submit Payment Allocation | `useCollectPaymentMutation` | `RPC: create_billing_profile_payment_with_allocations` | Updates `paid_amount`, credits tenant cash |
| **`WholesaleInvoiceReturnPage`** | Submit Credit Return | `useWholesaleReturnMutation`| `RPC: process_wholesale_invoice_return` | Updates `return_quantity`, restocks to `held` |
| **`DropshipOrderDetailV2ReadyForPickupPage`** | Mark as shipped | `advance_dropship_order_status` then `issueDropshipTenantB2bInvoice` | `RPC: advance_dropship_order_status`, `RPC: issue_dropship_tenant_b2b_invoice` | Merchant bill at ship; idempotent if already issued |
| **`DropshipManagementDetailPage`** | Mark as delivered | `markDropshipOrderDelivered` only | `RPC: mark_dropship_order_delivered` | Does **not** issue invoice (bill issued at ship) |
| **`shop_order` packing slip preview** | Print packing slip | local snapshot + preview route | No `sales_invoices` row | Recipient COD face lives on order / `channel_meta`, not the merchant bill |
