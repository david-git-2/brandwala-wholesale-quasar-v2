# Shop order & dropship — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| SO1 | doc_wrong | ACs `[ ]` | Negotiation + dropship pick RPCs exist | Tick matching ACs |
| SO2 | not_built | Confirm catalog `can_see_buy_price` / floor price on shop | Permissions RPC exists | Verify storefront vs PRD; note miss |
| SO3 | sql_split | `shop/` stub vs **split** `shop_order/` | Shop config may still overlap `public.sql` | Keep objects in one place |
