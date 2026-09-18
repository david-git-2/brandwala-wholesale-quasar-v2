# Shop order & dropship — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| SO1 | doc_wrong | ACs `[ ]` | Negotiation + dropship pick RPCs exist | Tick matching ACs |
| SO2 | not_built | Confirm catalog `can_see_buy_price` / floor price on shop | Permissions RPC exists | Verify storefront vs PRD; note miss |
| SO3 | sql_split | `shop/` stub vs **split** `shop_order/` | Shop config may still overlap `public.sql` | Keep objects in one place |
| SO4 | design | COD face on the order; remittance is a **receipt** (wallet) | Finance Hub + management bank transfer; `confirm_dropship_delivered_costing`; profit RPC after remittance | Do not own cash-in. See [wallet 01](../wallet/01-prd.md) and WA4–WA6 |
| SO10 | ~~not_built~~ | One RPC: ship + issue merchant bill from **picks** (`held_stock_id`, pick qty). Order `billing_profile_id` required. Unique `sales_invoices.shop_order_id`. | ~~Ready-for-pickup UI: advance then issue; order-line qty/stock~~ | **Done (2026-09):** `ship_dropship_order_and_issue_merchant_bill`; picks payload; unique `shop_order_id`; ready-for-pickup one button |
| SO11 | ~~design~~ | Deliver = parcel only; remittance pays the issued bill | ~~Deliver / costing booked cash; profit second RPC~~ | **Done (2026-09):** deliver requires issued bill; costing fields only; remittance allocates bill + merchant remainder |
| SO5 | ~~design~~ | Admin detail is `/:slug/app/shop/orders/:id` | **Done:** `ShopOrderDetailHostPage` loads catalog vs dropship UI from `shop_type_snapshot`. Old `/dropship/:id` URLs redirect. | Keep settlement desk on `/dropship-management/:id` |
| SO6 | ~~design~~ | Sender pickup is the warehouse / courier pickup point | **Done:** table `pickup_locations` (was misnamed `merchant_profiles`). Desk copies name/phone/address onto `shop_orders`. Reseller payouts stay on billing profiles. | Hub: More → shop setup & shipping |
| SO7 | ~~design~~ | Courier catalog is name + code only | **Done:** Couriers page has no return-policy tab / fee form. Extra columns on `courier_services` stay for order charges. | Do not put fee/policy editors back on that page |
| SO8 | ~~sql_wrong~~ | Staff charge save uses `delivery_charge_amount` on `shop_orders` | **Done:** `update_shop_order_charges_for_staff` no longer writes `recipient_delivery_charge` | Keep payload keys matching the table |
| SO9 | ~~design~~ | Ready for pickup = courier + pickup address + every line picked or cancelled | **Done:** Processing desk enables the button on those three. No extra “must have delivered qty”. | Keep gating on the desk, not a hidden RPC flag |
| SO12 | ~~not_built~~ | Catalog fulfill → `create_sales_invoice_from_payload`; dropship raises; `collection_source=billing_profile` | ~~Legacy create_global_invoice + post_global_invoice~~ | **Done (2026-09):** payload issue; dropship raises; billing_profile collection_source |
