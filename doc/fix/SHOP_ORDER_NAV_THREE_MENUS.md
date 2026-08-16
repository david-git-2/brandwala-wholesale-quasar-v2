# Shop & Order — three staff menus

Staff sidebar under **Shop & Order** is **Shops / Orders / Shipping**. Dropship is a **shop type** (selling method). Courier is **shared delivery**, used by dropship and by retail shops with `allow_delivery`.

Backend tables stay one stack (`shops`, cart, `shop_orders`). This change is keys + nav + docs.

## Staff nav

| Menu | Key | Home |
|------|-----|------|
| Shops | `shop_config` | `/app/shop/shops` |
| Orders | `shop_order_mgmt` | `/app/shop/orders` |
| Shipping | `shop_shipping` | `/app/shop/shipping` |

Customer shop nav is unchanged: Browse / Cart / My Orders (`shop_storefront`, `shop_cart`, `shop_order_mgmt`).

## Keys

| Key | Role |
|-----|------|
| `shop_order` | Parent. Assign this on the tenant. |
| `shop_config` | Staff **Shops** menu. |
| `shop_order_mgmt` | Staff **Orders** + customer My Orders. Dropship process-order lives here. |
| `shop_shipping` | Staff **Shipping** menu. Couriers, COD remittance. |
| `shop_permissions` | Page guard (customer groups / access matrix). Not a sidebar item. |
| `shop_pricing` | Page guard (listings). Not a sidebar item. |
| `shop_category` | Page guard (categories). Not a sidebar item. |
| `shop_storefront` / `shop_cart` | Customer shop scope. |
| `shop_dropship` | **Legacy.** Hidden from catalog. Invoice `source_module` may still say this. |
| `shop_fulfillment` | **Legacy.** Hidden from catalog. Fulfill on the order page. |

Do not grant `shop_dropship` to new tenants. Courier rights are `shop_shipping`, not dropship.

## Where Dropship Desk went

| Old | New |
|-----|-----|
| Dropship order list | **Orders**, filter shop type = dropship |
| Process Order page | **Orders** → that order (`/app/shop/dropship/:id` still works) |
| Couriers | **Shipping** |
| Finance / COD remittance | **Shipping** |
| Merchants / reseller wallets | **Billing Profiles** + **Shipping** Finance Hub (not a shop tab) |
| Fulfillment menu | Removed; actions on the order |

## Shops landing (locked)

Sidebar **Shops** opens a **setup hub**, not the shop list.

| Card | Page | Why here |
|------|------|----------|
| **Shops** | `/app/shop/shops/list` | Create storefronts |
| **Categories** | `/app/shop/categories` | Shared — how shops group on browse |
| **Customer groups** | `/app/shop/customer-groups` | Shared — who can log in |

Pricing is **not** a hub card. Dropship shop access is **Customer access**. Middle-man wallets are **Billing Profiles** + Finance Hub — not a shop tab.

### Under each shop (list)

| Action | Catalog | Retail | Dropship |
|--------|---------|--------|----------|
| Who can access | yes | yes | yes |
| Prices | no | yes | yes (incl. min floor) |

Couriers stay under **Shipping**.
