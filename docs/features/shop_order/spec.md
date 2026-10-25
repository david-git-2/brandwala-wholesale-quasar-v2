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
| In | Shops, carts, catalog/dropship orders, pricing, stock pick, pickup locations, reseller payout, dropship gifts, shop customer stock, auto gifts |
| Out | Warehouse receive; Koba/thrift; wholesale invoice desk; catalog pack-out on **Delivery paper**; parent invoice engine for dropship |

Dropship: pick → ship+issue both bills → deliver → remittance pay in. Later amount changes = credit/debit notes. Packing slip ≠ `sales_invoices` row. Catalog delivery: Delivery paper + optional proforma; close take/condition/return; then bills. Numbers: [money-story](../bills_pays/money-story.md).

## Terminology (UI & docs)

| Plain language | Meaning | Legacy code names (unchanged) |
| :--- | :--- | :--- |
| **Supplier** | Logged-in **tenant** — fulfills stock, issues B2B invoice | `tenant`, `company` (charge payer) |
| **Dropshipper** | **Customer** on the dropship shop — buys at wholesale, resells to recipient | `merchant`, `reseller`, `middleman`, shop profile |
| **End customer** (UI) | Delivery + COD face; code still `recipient_*` | `recipient_*` |

- **Customer invoice** (issued at ship) = supplier → dropshipper; not COD face; not a bill to the recipient.
- **End customer delivery slip** = ops paper; not the customer invoice to the dropshipper.
- **Dropshipper profit** owed after remittance = profile **cashbook** + payout; not a second AR invoice.

## Personas

| Role | Actions |
| :--- | :--- |
| Storefront customer | Cart, negotiate quotes, confirm qty |
| Dropshipper | Orders for recipients, track delivery, profit balance / payout |
| Fulfillment | Pick, packing slip, courier; catalog via Delivery paper |
| Shop admin | Shop types, price visibility, categories |

## Stories

### US-1a: Shop dropship checkout (recipient)
- [x] **Required (UI: end customer):** `recipient_name`, `recipient_phone`, `shipping_address` (`submit_dropship_order_from_cart` + shop delivery page).
- [x] **Optional:** `shipping_district`, `shipping_thana`, `shipping_post_code`.

### US-1: Storefront types & tiers
- [x] `vendor_catalog` / `fixed_price` / `dropship` with group price flags.
- [x] Dropship enforces `minimum_sell_price_amount`.
- [x] **Custom override display qty:** `shops.display_quantity_add` (default 6). Real ≤2 → show real; real >2 → show real + pad. `recalc_shop_display_quantities` on admin storefront tab. Customer catalog never shows 0 when real stock >0 (stale override fallback).
- [x] **Dropship listing visibility by group:** Access row **Products** button opens a dialog with show checkboxes. No hide row = shown. `shop_listing_group_hides` + `list_shop_listing_group_visibility` / `set_shop_listing_group_visibility`. Customer browse, product, and cart respect hides.

### US-2: Catalog negotiation
- [x] `submitted` → `priced` → `countered` → `final_offered` → `confirmed`.
- [x] Confirmed qty locks for demand desk.

### US-3: Dropship fulfillment
- [x] Pick at `processing` → `shop_order_item_stock_picks`.
- [x] `ship_dropship_order_and_issue_merchant_bill` at ship (issued customer AR + issued courier AP).
- [x] Deliver: parcel + COD receivable; remittance remainder → merchant wallet. Amount changes after issue = notes.

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
- [x] **Customer invoice** (UI; RPC `ship_dropship_order_and_issue_merchant_bill`) — issued AR to dropshipper at ship. Amount = B2B total, not COD.
- [x] **Courier AP** — issued we-owe at ship (`upsert_dropship_courier_ap_bill`, `source_type = dropship_courier`). COD receivable still at deliver; tenant cash on **net** remittance pay in (`record_dropship_courier_remittance` → `post_customer_receipt_with_allocations`, `source = courier_remittance`). Remittance requires the customer bill **issued**.
- [x] **Alloc** — remittance pays customer invoice; remainder → dropshipper **cashbook** (profit), pay out later — not a second AR bill. `payout_settlement_status` stays unpaid until `dispense_middleman_payout_from_tenant`. Money is **bills + pays + cashbook** only (settlement table is ops paper). Post remittance from **settlement desk → Courier pay in** or **Payments → Pay in → Courier**; same `record_dropship_courier_remittance`.
- [x] **Courier pay in fees** — adjusted delivery/COD at pay in persist on order/settlement (`patch_dropship_courier_fees_for_remittance`). If issued bills differ, `apply_dropship_issued_bill_notes_at_deliver` runs in the same transaction before cash moves. Net allocates to customer AR on **due after notes**; courier AP closes up to retained fees (`settle_dropship_courier_ap_via_cod_retention`, no second cash out), including **debit/credit notes** on the AP paper. UI confirms via `preview_dropship_courier_payin_settlement` (notes + customer cleared + AP settled + **dropshipper receives**). After remittance, settlement desk shows **credited wallet profit** (net remittance − AR cleared); COD-margin on the paper may differ until pay-in.
- [x] **Settlement desk vs bills** — settlement desk **Save** updates the draft only (no autosave). **Mark as delivered** runs `apply_dropship_issued_bill_notes_at_deliver`: issued customer AR and courier AP stay on the original paper; charge deltas vs settlement become **credit/debit notes** (`create_bill_adjustment`), not a silent rewrite of issued totals.

### US-6: Dropship gifts
- [x] Many **gift** lines per order (`is_gift`); recipient sell/COD unchanged (excluded from resell total).
- [x] **Add gift item** on processing desk while `processing`, before ship; remove until ship.
- [x] **Cost on** (`gift_source = stock`): warehouse pick; entered `gift_cost_amount` charged to **reseller** or **tenant** (not SKU landed cost).
- [x] **Customer provided** (`gift_source = customer_stock`): from `shop_customer_stocks`; cost 0; no warehouse pick.
- [x] Merchant bill includes warehouse gifts charged to reseller only (issued at ship).

### US-7: Shop customer stock
- [x] Per-shop `shop_customer_stocks` (product + qty); **Receive** on shop settings (app). Not `global_stocks`.

### US-8: Auto gifts
- [x] Per-shop `shop_auto_gift_items` (active rows); `apply_shop_auto_gift_items` once when order enters `processing` (`auto_gifts_applied_at`). Short customer stock → skip row, show on desk.

### US-9: Staff manual dropship (off-channel)
- [x] App **Create dropship order** (`/:slug/app/shop/orders/create`): dropship shop, customer group (billing profile from group via `resolve_customer_profile_for_group`), search-add lines, recipient address; `staff_create_dropship_order` on behalf of group.
- [x] Order enters same workflow as customer dropship (recipient call → processing → ship/issue → deliver).
- [x] COD/delivery charge amounts remain on processing desk, not on create page.
