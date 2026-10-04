# Bills & pays — page → API

## A. Bills

---

## 📊 Interaction & Endpoint Matrix

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation / Optimistic Update |
| :--- | :--- | :--- | :--- | :--- |
| **`BillsPage`** | Mount / filter / search | `useBillsListQuery` | `Table: bills` (+ `profiles` join) via `invoiceRepository.listGlobalInvoices` | `billsQueryKeys.list` (`staleTime: 30s`) |
| **`BillDetailPage`** | Mount | `useBillDetailQuery` | `Table: bills` + `RPC: list_global_invoice_items` | `billsQueryKeys.detail` / `items` |
| **`BillDetailPage`** | Void (issued, unpaid) | `useVoidBillMutation` | `RPC: void_sales_invoice` | Invalidates `billsQueryKeys` root + detail |
| **`BillDetailPage`** | Print | navigate `app-bill-preview-page` | — | — |
| **`BillComposePage`** | Mount draft (`?id=`) | `invoiceRepository.getGlobalInvoiceById` + `listGlobalInvoiceItems` | `Table: bills` / `bill_lines` | — |
| **`BillComposePage`** | FIFO search | `BillStockSearch` | `RPC: search_sales_invoice_stock` | — |
| **`BillComposePage`** | Save draft / issue | `useBillComposeMutation` | `RPC: create_sales_invoice_from_payload` or `update_sales_invoice_from_payload`; issue → `post_sales_invoice` on edits. Paper stays `draft` until issue. **Target:** trade Take/Condition ([BP7](00-gaps.md)); walk-in take only. | `billsQueryKeys` |
| **`BillPreviewPage`** | Mount / brand pick | `useBillDetailQuery` + `listInvoiceBrands` | `Table: invoice_brands` | last brand id in `localStorage` per parent tenant |
| **`BillPreviewPage`** | Print | `window.print()` | — | — |
| **`BillBrandsPage`** | CRUD | direct repository | `Table: invoice_brands` (writes: `invoice_brand` grant + RLS) | `['invoice_brands', parentTenantId]` |
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
| **`PaymentsPage`** | Mount / search / Cash in pill | `usePaysListQuery` | `Table: pays` via `paysRepository.listPays` | `paysQueryKeys.list` (`staleTime: 30s`) |
| **`PaymentsPage`** | Pay out pill | `usePaysListQuery` `side: out` | `Table: pays` where `source = ap_payout` | `paysQueryKeys.list` |
| **`BillsPage`** | They owe / We owe pill | `useBillsListQuery` | `invoice_type` filter (`ap` vs not `ap`) | `billsQueryKeys.list` |
| **`CollectPayPage`** | Post receipt | `useCollectPayMutation` | `RPC: post_customer_receipt_with_allocations` | `paysQueryKeys` + `billsQueryKeys` |
| **`CollectPayPage`** | Pick customer | `paysRepository.listCustomerGroupsPaymentSummary` | `RPC: list_customer_groups_payment_summary` | — |
| **`RemitPayPage`** | Post remittance | `dropshipFinanceRepository.confirmCourierRemittance` | `RPC: record_dropship_courier_remittance` | `paysQueryKeys` |
| **`PayoutPayPage`** | Merchant leftover | `paysRepository.dispenseMiddlemanPayout` | `RPC: dispense_middleman_payout_from_tenant` | `paysQueryKeys` |
| **`PayoutPayPage`** | Shipment AP pay | `paysRepository.postApPayoutWithAllocations` | `RPC: post_ap_payout_with_allocations` | `paysQueryKeys` + `billsQueryKeys` |
| **Procurement shipment save** | After costs / vendor / local | `syncShipmentApBills` | `RPC: sync_shipment_ap_bills` | — |
| **`PayDetailPage`** | Void | `useVoidPayMutation` | `RPC: void_customer_receipt` | `paysQueryKeys` + `billsQueryKeys` |
## C. Cashbook

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation |
| :--- | :--- | :--- | :--- | :--- |
| **`CashbookPage`** | Party type pills / search | `useCashbookEntitiesQuery` | `RPC: list_wallet_entities_for_staff`; **Us** tab → `get_wallet_detail_for_staff` (`tenant`) | `cashbookQueryKeys` |
| **`CashbookPartyPage`** | Mount balances | `useCashbookPartyQuery` → detail | `RPC: get_wallet_detail_for_staff` | `cashbookQueryKeys.detail` |
| **`CashbookPartyPage`** | Ledger list | `useCashbookPartyQuery` → ledger | `RPC: list_wallet_ledger_for_staff` | `cashbookQueryKeys.ledger` |
| *(later)* reverse / manual | — | — | `reverse_wallet_ledger_entry_for_staff` / `record_ledger_transaction` | US-6 / BP2 |
