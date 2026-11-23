# Shop order & dropship — spec

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/shop_order/spec.md` |
| UI | `web/src/modules/shop_order/` |
| SQL | **Split** `supabase/schemas/shop_order/` |
| State | Vue Query + `shopOrderQueryKeys` |
| Model | BW shop + dropship; catalog quotes = pre-order — [business-models](../../architecture/business-models.md) |
| Access | `shop` + `app`; admin order `/:slug/app/shop/orders/:id` |

## Where to look

| Need | Path |
| :--- | :--- |
| Tables, RPCs | `supabase/schemas/shop_order/` |
| Resell discount review (planned) | [dropship-resell-discount-approval.md](dropship-resell-discount-approval.md) |
| Dropship ship/issue | `ship_dropship_order_and_issue_merchant_bill`, remittance RPCs |
| Courier AR redesign (target) | [dropship-courier-ar-redesign.md](dropship-courier-ar-redesign.md) — gap **SO-CA1** |
| Picking | `add_shop_order_item_stock_pick` |
| Pages | `web/src/modules/shop_order/pages/` |

## Scope

| | |
| :--- | :--- |
| Surfaces | `shop` storefront; `app` config + dropship desk |
| In | Shops, carts, catalog/dropship orders, pricing, stock pick, pickup locations, reseller payout, dropship gifts, shop customer stock, auto gifts |
| Out | Warehouse receive; Koba/thrift; wholesale invoice desk; catalog pack-out on **Delivery paper**; parent invoice engine for dropship |

Dropship: pick → ship+issue both bills → deliver → remittance pay in. Later amount changes = credit/debit notes. Packing slip ≠ `sales_invoices` row. Catalog delivery: Delivery paper + optional proforma; close take/condition/return; then bills. Numbers: [atlas](../money_bill_bridge/spec.md#atlas). End-to-end map: [preorder-fulfillment-flow](../../preorder-fulfillment-flow.md).

**Money target (locked, not built):** at ship create **draft** **customer AR + courier AR (net remittance)** — not issued, not courier AP. See [dropship-courier-ar-redesign.md](dropship-courier-ar-redesign.md). **As-built code** still issues courier AP until SO-CA1 ships.

## Terminology (UI & docs)

| Plain language | Meaning | Legacy code names (unchanged) |
| :--- | :--- | :--- |
| **Supplier** | Logged-in **tenant** — fulfills stock, issues B2B invoice | `tenant`, `company` (charge payer) |
| **Dropshipper** | **Customer** on the dropship shop — buys at wholesale, resells to recipient | `merchant`, `reseller`, `middleman`, shop profile |
| **End customer** (UI) | Delivery + COD face; code still `recipient_*` | `recipient_*` |

- **Customer invoice** (**draft** at ship; issue later) = supplier → dropshipper; not COD face. **Target note:** amount dropshipper **gets after all payment**. [Redesign](dropship-courier-ar-redesign.md).
- **Courier receivable (target)** = **draft** at ship; **lines** COD − rate − delivery → net; replaces courier AP.
- **End customer delivery slip** = ops paper; not the customer invoice to the dropshipper.
- **Dropshipper profit** owed after remittance = profile **cashbook** + payout; not a second AR invoice (shown as customer AR note at ship).

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

### US-1b: Dropship resell discount review (pre-confirm)

**Built (SO-DR4 totals nuance optional)** — [dropship-resell-discount-approval.md](dropship-resell-discount-approval.md). Open gap: spec.md SO-DR4.

- [x] Place with any line resell discount request → order `resell_discount_requested` (not `confirmed`).
- [x] Staff **approve** (per line accept / adjust) → apply resell → `confirmed` → US-4+ pipeline.
- [x] Staff **deny** (per line keep listed) **or** cancel order with reason.

### US-1: Storefront types & tiers
- [x] `vendor_catalog` / `fixed_price` / `dropship` with group price flags.
- [x] Dropship enforces `minimum_sell_price_amount`.
- [x] **Custom override display qty:** `shops.display_quantity_add` (default 6). Real ≤2 → show real; real >2 → show real + pad. `recalc_shop_display_quantities` on admin storefront tab. Customer catalog never shows 0 when real stock >0 (stale override fallback).
- [x] **Dropship listing visibility by group:** Access row **Products** button opens a dialog with show checkboxes. No hide row = shown. `shop_listing_group_hides` + `list_shop_listing_group_visibility` / `set_shop_listing_group_visibility`. Customer browse, product, and cart respect hides.

### US-2: Catalog negotiation
- [x] `submitted` → `priced` → `countered` → `final_offered` → `confirmed`.
- [x] Confirmed qty locks for demand desk.
- [x] Staff catalog order detail (`app/shop/orders/:id`, vendor catalog): **Download Excel** exports the same PBC-format costing workbook client-side (mapped from order lines + rates). Menu: **With images** / **Without images**. Workbook includes a **Product ID** column (all PBC-format Excel exports).

### US-3: Dropship fulfillment
- [x] Pick at `processing` → `shop_order_item_stock_picks`.
- [x] `ship_dropship_order_and_issue_merchant_bill` at ship — **as-built:** customer AR + **courier AP** (issued). **Target:** **draft** customer AR + **draft** courier AR (net) — [redesign](dropship-courier-ar-redesign.md) / SO-CA1.
- [x] Deliver: parcel + COD face; remittance remainder → merchant wallet. Amount changes after issue = notes.

Post-ship: **Dropship management** list (`/:slug/app/shop/dropship-management`) — money columns, **Bills** links (**Dropshipper** / **Courier** → bill detail), status actions; **no** per-order settlement detail route. Remittance: `record_dropship_courier_remittance` / finance hub.

**Mark as delivered:** From the management list (`shipped` row) **only** advances `shop_orders.status` → `delivered` (set `delivered_at` if still null). No settlement save or bill side effects on deliver (SO-DL5).

**Delivered-row settlement:** On the management list, `delivered` rows edit **Collected COD**, **Delivery**, and **COD rate**; **Save** calls `save_dropship_management_list_settlement` → `save_dropship_settlement_draft` + `sync_dropship_draft_bills_after_settlement` (draft customer + courier AR only). **Block save** when linked papers are issued (use pay-in / bill adjustments).

### US-4: Recipient confirmation call
- [x] While dropship `status = confirmed`, staff call `recipient_name` / `recipient_phone` (app log only; no auto-dial).
- [x] **No answer** → `recipient_call_attempt_count += 1`; stay `confirmed` (no auto-cancel).
- [x] **Recipient confirmed** → `recipient_verified_at` set; `confirm_dropship_recipient_call` advances to `processing`.
- [x] **Recipient cancelled** → required `cancel_reason`; `cancel_shop_order_dropship` with reason.
- [x] `advance_dropship_order_status` to `processing` blocked until `recipient_verified_at` is set.
- [x] Reseller sees `cancel_reason` on shop order detail when `cancelled`.

### US-5: Dropship money layers

**Target (locked):** [dropship-courier-ar-redesign.md](dropship-courier-ar-redesign.md) — two **draft** ARs at ship; remittance auto-clears customer AR. Gap **SO-CA1**.

- [x] **Recipient** — COD face on order only; not a `bills` row ([atlas](../money_bill_bridge/spec.md#atlas)).
- [ ] **Customer invoice at ship** — **target:** **draft** AR to dropshipper (B2B, not COD). **As-built:** issued at ship via `ship_dropship_order_and_issue_merchant_bill`.
- [ ] **Customer AR note** — **target:** note on that paper = amount dropshipper **gets after all payment**. Not a second AR.
- [ ] **Courier AR (net) at ship** — **target:** **draft** AR with lines **COD − rate − delivery**. **As-built:** issued courier **AP** via `upsert_dropship_courier_ap_bill` + remittance AP retention.
- [x] **Alloc / remittance** — pay in (`record_dropship_courier_remittance`); remainder → dropshipper **cashbook**. Remittance requires papers **issued** (drafts from ship must be issued first). Desk: settlement → Courier pay in or Payments → Pay in → Courier.
- [ ] **Auto customer AR on remittance** — **target:** remittance closes courier AR and **auto allocates** to customer AR. **As-built:** alloc to customer AR + AP retention close.
- [x] **Fee / settlement deltas** — adjusted fees at pay in; issued papers stay; deltas → **credit/debit notes** (`create_bill_adjustment`), not silent rewrite. Preview: `preview_dropship_courier_payin_settlement`.
- [x] **Management list** — post-ship orders: COD/fees/B2B bill columns; **Dropshipper** / **Courier** bill links; **`shipped` → Delivered** (status only) or **Returned** (return flow); **`delivered` → Save** settlement (draft bills resync).
- [x] **Mark as delivered** — status → `delivered` only via `mark_dropship_order_delivered` (**SO-DL5** built). Legacy settlement detail page retired.

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

### US-10: Staff manual vendor catalog (backfill / on behalf)
- [x] App **Create catalog order** (`/:slug/app/shop/orders/create-catalog`) — **two tabs**: **Create order** (standard) and **Old order** (backfill).
- [x] **Create order** tab: `vendor_catalog` shop (optional filter), customer group, product search, line qty only; `staff_create_vendor_catalog_order` with `p_create_mode = standard`; order `submitted`, negotiable per shop × group.
- [x] **Old order** tab: same headers + **order rates** (FX, cargo, **profit rate %**, profit basis), **initial status** default `procuring` (select `procuring` \| `delivered` \| `closed`), per-line **qty + sell price to customer**; `p_create_mode = old_order`; **`is_negotiable_snapshot = false`**, **`catalog_manual_price_entry = true`**; RPC stamps `profit_rate`, `first_offer_rate`, and `final_offer_rate` from that single %; lines get manual final/customer sell prices.
- [x] **`hidden_from_customer`** (default **true** on manual create): customer list/detail omit; staff list “Staff only” chip; detail **Settings → Actions** toggle via `update_shop_order_hidden_from_customer_for_staff`.
- [x] **`catalog_manual_price_entry`**: staff list “Manual prices” chip when set from old-order tab.
- [x] **`placement_scope`** (`shop` \| `app`) on `shop_orders`: `shop` = customer cart checkout; `app` = staff manual catalog or dropship create. **`created_by_email`** = logged-in user at create. Exposed on customer shop list/detail (when not `hidden_from_customer`) and staff orders list.
- [x] Required **order date** (`p_recorded_at`) for sort/backfill timestamps; bulk add on each tab (old tab: code, qty, sell price).

### US-11: Delete cancelled orders (staff)
- [x] Hard delete only when `status = cancelled` (`delete_shop_order`); blocks replacement targets and non-cancelled rows.
- [x] Cascade: financial purge, preorder demand for order lines, customer backlog rows, stock un-allocation, picks/items/order (dropship restock trigger unchanged).
- [x] Staff orders list header **Delete** → `/:slug/app/shop/orders/cancelled` page (cancelled-only list, select + confirm + `delete_shop_orders_for_staff`, batch max 100). Detail and dropship list delete aligned to cancelled-only.
