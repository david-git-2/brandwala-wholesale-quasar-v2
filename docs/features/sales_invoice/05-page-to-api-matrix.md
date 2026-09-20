# Sales Invoice — Page-to-API Matrix

Mapping of all UI controls, interactive buttons, modal triggers, and form submissions to their corresponding Supabase RPCs, database operations, and TanStack Vue Query cache keys.

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
| **`StaffOrderDetailPage`** | Fulfill to invoice (catalog only) | `useFulfillOrderToInvoiceMutation` | `RPC: fulfill_shop_order_to_invoice` → `create_sales_invoice_from_payload` | Links `shop_orders.global_invoice_id`; not dropship |
| **`WholesaleInvoiceReturnPage`** | Submit Credit Return | `useWholesaleReturnMutation`| `RPC: process_wholesale_invoice_return` | Updates `return_quantity`, restocks to `held` |
| **`DropshipOrderDetailV2ReadyForPickupPage`** | Mark as shipped | `shopOrderService.shipDropshipOrderAndIssueMerchantBill` | `RPC: ship_dropship_order_and_issue_merchant_bill` | Merchant bill from picks + `shipped` |
| **`DropshipManagementDetailPage`** | Mark as delivered | `markDropshipOrderDelivered` only | `RPC: mark_dropship_order_delivered` | Does **not** issue invoice or post cash |
| **`shop_order` packing slip preview** | Print packing slip | local snapshot + preview route | No `sales_invoices` row | Recipient COD face lives on order / `channel_meta`, not the merchant bill |
