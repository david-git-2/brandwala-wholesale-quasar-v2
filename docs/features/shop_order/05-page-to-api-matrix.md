# Shop Order & Dropship — Page-to-API Matrix

Mapping of all UI controls, stage actions, dialog triggers, and form submissions to their corresponding Supabase RPCs, database operations, and TanStack Vue Query cache keys.

---

## 📊 Interaction & Endpoint Matrix

| Page / Component | UI Control / Action | Triggered Hook / Method | Backend RPC / Operation | Cache Invalidation / Optimistic Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **`ShopOrderDetailHostPage`** | Open `/app/shop/orders/:id` | Loads catalog desk or dropship V2 by `shop_type_snapshot` | Same RPCs as before | Status change stays on this URL |
| **`ShopSettingsPage`** | Update Shop Permissions | `useUpdateShopAccessMutation` | `Table: shop_customer_group_access` | Invalidates shop permissions cache |
| **`DropshipOrderDetailV2ProcessingPage`** | Confirm line stock pick | Pick dialog | `RPC: add_shop_order_item_stock_pick` | Held lot + pick row; COD recompute |
| **`DropshipOrderDetailV2ProcessingPage`** | Ready for pickup | Desk gate (courier + pickup + lines) | `RPC: advance_dropship_order_status` → `ready_for_pickup` | Does **not** issue the merchant bill |
| **`DropshipOrderDetailV2ReadyForPickupPage`** | Mark as shipped | `shopOrderService.shipDropshipOrderAndIssueMerchantBill` | `RPC: ship_dropship_order_and_issue_merchant_bill` | Issued merchant bill + `shipped` |
| **`DropshipManagementDetailPage`** | Mark as delivered | `markDropshipOrderDelivered` | `RPC: mark_dropship_order_delivered` | Parcel only. Require `global_invoice_id`. No cash |
| **`DropshipFinanceHubPage` / remittance** | Record courier bank in | remittance mutation | `RPC: record_dropship_courier_remittance` (target: same receipt path as wholesale collect) | Allocate to merchant bill; leftover → merchant wallet (WA4–WA6) |
| **`DropshipPickupLocationsPage`** | Add / edit pickup location | `pickupLocationRepository` | `Table: pickup_locations` | Invalidates pickup-locations list |
| **`DropshipOrderConfirmedInvoicePaper`** | Pickup location select | Copies onto order sender fields | `RPC: update_dropship_consignment` | Saves `sender_name` / `pickup_phone` / `pickup_address` |
| **`ShopNegotiationDesk`** | Staff Submit First Offer | `useStaffPriceOrderMutation` | `RPC: staff_price_shop_order` | Sets status `priced`; invalidates order cache |
| **`ShopNegotiationDesk`** | Customer Accept / Counter | `useCustomerCounterMutation` | `RPC: customer_counter_shop_order` | Sets status `countered` / `confirmed` |
| **`StaffOrderDetailPage`** | Fulfill to invoice | `useFulfillOrderToInvoiceMutation` | `RPC: fulfill_shop_order_to_invoice` | Catalog fixed_price/checkout_wholesale only; payload issue; not dropship |
