# Shop order & dropship — spec

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/shop_order/spec.md` + [00-gaps](00-gaps.md) |
| UI | `web/src/modules/shop_order/` |
| SQL | **Split** `supabase/schemas/shop_order/` |
| State | Vue Query + `shopOrderQueryKeys` |
| Model | BW shop + dropship; catalog quotes = pre-order — [business-models](../../architecture/business-models.md) |
| Access | `shop` + `app`; admin order `/:slug/app/shop/orders/:id` |

## Where to look

| Need | Path |
| :--- | :--- |
| Tables, RPCs | `supabase/schemas/shop_order/` |
| Dropship ship/issue | `ship_dropship_order_and_issue_merchant_bill`, remittance RPCs |
| Picking | `add_shop_order_item_stock_pick` |
| Pages | `web/src/modules/shop_order/pages/` |

## Scope

| | |
| :--- | :--- |
| Surfaces | `shop` storefront; `app` config + dropship desk |
| In | Shops, carts, catalog/dropship orders, pricing, stock pick, pickup locations, reseller payout |
| Out | Warehouse receive; Koba/thrift; wholesale invoice desk; catalog pack-out on **Delivery paper**; parent invoice engine for dropship |

Dropship: pick → ship+issue RPC → deliver → remittance pay in. Packing slip ≠ `sales_invoices` row. Catalog delivery: Delivery paper + optional proforma; close take/condition/return; then bills. Numbers: [money-story](../bills_pays/money-story.md).

## Personas

| Role | Actions |
| :--- | :--- |
| Storefront customer | Cart, negotiate quotes, confirm qty |
| Dropship reseller | Orders for recipients, track delivery, wallet profit |
| Fulfillment | Pick, packing slip, courier; catalog via Delivery paper |
| Shop admin | Shop types, price visibility, categories |

## Stories

### US-1: Storefront types & tiers
- [x] `vendor_catalog` / `fixed_price` / `dropship` with group price flags.
- [x] Dropship enforces `minimum_sell_price_amount`.

### US-2: Catalog negotiation
- [x] `submitted` → `priced` → `countered` → `final_offered` → `confirmed`.
- [x] Confirmed qty locks for demand desk.

### US-3: Dropship fulfillment
- [x] Pick at `processing` → `shop_order_item_stock_picks`.
- [x] `ship_dropship_order_and_issue_merchant_bill` at ship.
- [x] Deliver: parcel only; remittance remainder → merchant wallet.

Post-ship: **Dropship settlement** desk; `record_dropship_courier_remittance` is single remittance writer.
