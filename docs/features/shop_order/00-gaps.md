# Shop order & dropship — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| SO1 | doc_wrong | ACs `[ ]` | Negotiation + dropship pick RPCs exist | Tick matching ACs |
| SO2 | not_built | Confirm catalog `can_see_buy_price` / floor price on shop | Permissions RPC exists | Verify storefront vs PRD; note miss |
| SO3 | sql_split | `shop/` stub vs **split** `shop_order/` | Shop config may still overlap `public.sql` | Keep objects in one place |
| SO4 | design | COD face on the order; remittance is a **receipt** (wallet) | Finance Hub + management bank transfer; `confirm_dropship_delivered_costing`; profit RPC after remittance | Do not own cash-in. See [wallet 01](../wallet/01-prd.md) and WA4–WA6 |
| SO5 | ~~design~~ | Admin detail is `/:slug/app/shop/orders/:id` | **Done:** `ShopOrderDetailHostPage` loads catalog vs dropship UI from `shop_type_snapshot`. Old `/dropship/:id` URLs redirect. | Keep settlement desk on `/dropship-management/:id` |
