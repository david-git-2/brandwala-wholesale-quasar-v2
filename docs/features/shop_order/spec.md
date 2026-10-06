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

### US-4: Recipient confirmation call
- [x] While dropship `status = confirmed`, staff call `recipient_name` / `recipient_phone` (app log only; no auto-dial).
- [x] **No answer** → `recipient_call_attempt_count += 1`; stay `confirmed` (no auto-cancel).
- [x] **Recipient confirmed** → `recipient_verified_at` set; `confirm_dropship_recipient_call` advances to `processing`.
- [x] **Recipient cancelled** → required `cancel_reason`; `cancel_shop_order_dropship` with reason.
- [x] `advance_dropship_order_status` to `processing` blocked until `recipient_verified_at` is set.
- [x] Reseller sees `cancel_reason` on shop order detail when `cancelled`.

### US-5: Dropship money layers
- [x] **Recipient** — COD face on order only; not a `bills` row ([money-story](../bills_pays/money-story.md)).
- [x] **Merchant bill** — one issued bill to shop profile at ship (`ship_dropship_order_and_issue_merchant_bill`); amount = merchant total, not COD.
- [x] **Courier** — COD receivable at deliver; tenant cash on **net** remittance pay in (`record_dropship_courier_remittance` → `post_customer_receipt_with_allocations`, `source = courier_remittance`).
- [x] **Alloc** — remittance pays merchant bill; remainder → shop **cashbook** (profit), pay out later — not a second AR bill.
