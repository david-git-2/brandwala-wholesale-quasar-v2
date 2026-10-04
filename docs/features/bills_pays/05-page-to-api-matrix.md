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
| **`PaymentsPage`** | Mount / search / Cash in pill | `usePaysListQuery` | `Table: pays` via `paysRepository.listPays` | `paysQueryKeys.list` (`staleTime: 30s`) |
| **`PaymentsPage`** | Cash out pill | — | Empty list (payouts are cashbook-only today) | — |
| **`CollectPayPage`** | Post receipt | `useCollectPayMutation` | `RPC: post_customer_receipt_with_allocations` | `paysQueryKeys` + `billsQueryKeys` |
| **`CollectPayPage`** | Pick customer | `paysRepository.listCustomerGroupsPaymentSummary` | `RPC: list_customer_groups_payment_summary` | — |
| **`RemitPayPage`** | Post remittance | `dropshipFinanceRepository.confirmCourierRemittance` | `RPC: record_dropship_courier_remittance` | `paysQueryKeys` |
| **`PayoutPayPage`** | Submit payout | `paysRepository.dispenseMiddlemanPayout` | `RPC: dispense_middleman_payout_from_tenant` | `paysQueryKeys` |
| **`PayDetailPage`** | Void | `useVoidPayMutation` | `RPC: void_customer_receipt` | `paysQueryKeys` + `billsQueryKeys` |
## C. Cashbook

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation |
| :--- | :--- | :--- | :--- | :--- |
| **`CashbookPage`** | Party type pills / search | `useCashbookEntitiesQuery` | `RPC: list_wallet_entities_for_staff`; **Us** tab → `get_wallet_detail_for_staff` (`tenant`) | `cashbookQueryKeys` |
| **`CashbookPartyPage`** | Mount balances | `useCashbookPartyQuery` → detail | `RPC: get_wallet_detail_for_staff` | `cashbookQueryKeys.detail` |
| **`CashbookPartyPage`** | Ledger list | `useCashbookPartyQuery` → ledger | `RPC: list_wallet_ledger_for_staff` | `cashbookQueryKeys.ledger` |
| *(later)* reverse / manual | — | — | `reverse_wallet_ledger_entry_for_staff` / `record_ledger_transaction` | US-6 / BP2 |
