# Shop Order & Dropship — Page-to-API Matrix

Mapping of all UI controls, stage actions, dialog triggers, and form submissions to their corresponding Supabase RPCs, database operations, and TanStack Vue Query cache keys.

---

## 📊 Interaction & Endpoint Matrix

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation / Optimistic Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **`ShopOrderDetailHostPage`** | Open `/app/shop/orders/:id` | Loads catalog desk or dropship V2 by `shop_type_snapshot` | Same RPCs as before | Status change stays on this URL |
| **`ShopSettingsPage`** | Update Shop Permissions | `useUpdateShopAccessMutation` | `Table: shop_customer_group_access` | Invalidates shop permissions cache |
| **`DropshipProcessingPage`** | Confirm Line Stock Pick | `useAssignStockPickMutation` | `RPC: assign_dropship_order_stock_pick` | Binds `global_stock_id`, updates order status |
| **`DropshipReadyForPickupPage`**| Issue B2B Invoice | `useIssueB2BInvoiceMutation` | `RPC: create_sales_invoice_from_payload` | Links `global_invoice_id`, freezes stock |
| **`DropshipFinanceHubPage`** | Credit Reseller Profit | `useCreditResellerProfitMutation` | `RPC: transfer_dropship_reseller_profit` | Credits merchant wallet; updates settled flag |
| **`ShopNegotiationDesk`** | Staff Submit First Offer | `useStaffPriceOrderMutation` | `RPC: staff_price_shop_order` | Sets status `priced`; invalidates order cache |
| **`ShopNegotiationDesk`** | Customer Accept / Counter | `useCustomerCounterMutation` | `RPC: customer_counter_shop_order` | Sets status `countered` / `confirmed` |
