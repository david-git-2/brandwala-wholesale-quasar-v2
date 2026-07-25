# Dropship Order Detail — UX Plan & Execution Task Matrix

Improving the **Dropship Desk Order Detail Page** (`DropshipOrderDetailPage.vue`).

---

## Context (do not implement from this section alone)

**Overall UX Grade: B+ (84 / 100)** — strong visual hierarchy; weak operational efficiency (missing inline items, manual tracking URLs, scattered CTAs, tall Block C).

### Goals (priority)

| Priority | Goal |
| :--- | :--- |
| **P0** | Inline order items table (thumb, title, SKU, qty, face vs middleman price) |
| **P1** | Auto-generated courier tracking URL from AWB + `tracking_url_template` |
| **P1** | Unified header primary CTA by order lifecycle |
| **P2** | Collapsible merchant pickup (Block C) |
| **P2** | One-click copy for recipient phone & address |

### Out of scope

- No new RPCs, no RLS changes, no README/docs beyond this file
- Do not edit unrelated dropship list/ledger pages unless listed in the active phase
- Do not hand-edit `web/src/types/supabase.ts` (regenerate via script only)

---

## Agent rules (every phase)

1. Touch **only** files listed under **Files to Change** for the active phase.
2. Complete **Specification** bullets exactly; no drive-by refactors or restyles.
3. Stop when the phase is done. Set **Status** to `[Done]` only after a human passes **Review Gate**.
4. If blocked by missing data/ambiguity, stop and ask — do not invent schema or RPCs.
5. Prefer existing helpers: `formatBdt`, `showSuccessNotification` / `showErrorNotification`, Quasar `copyToClipboard`, existing dialog openers (`performHandoff`, `openDualInvoiceDialog`, `openOrderRemittanceDialog`, `settleOrderPayout`).

---

## Execution Task Matrix

## Phase 0: Macro — `tracking_url_template` migration

- **Goal:** Add `tracking_url_template` to `courier_services` and seed templates for Steadfast, Pathao, and RedX.
- **Depends On:** None
- **Priority:** P1 (enables Phase 5)
- **Files to Change:**
  - `supabase/migrations/20261129000000_add_tracking_url_template_to_couriers.sql` (create)
- **Specification:**
  - `ALTER TABLE public.courier_services ADD COLUMN IF NOT EXISTS tracking_url_template text DEFAULT NULL;`
  - Seed (by `code`):
    - `steadfast` → `https://steadfast.com.bd/t/{awb}`
    - `pathao` → `https://pathao.com/tracking?consignment_id={awb}`
    - `redx` → `https://redx.com.bd/track-parcel?trackingId={awb}`
  - Placeholder token must be exactly `{awb}` (no other tokens).
  - Migration must be idempotent (`IF NOT EXISTS` / safe `UPDATE` by code).
- **Rollback:** Drop column `tracking_url_template` from `courier_services` (or revert migration file before deploy).
- **Review Gate:** Column exists; three seeded rows have non-null templates with `{awb}`.
- **Status:** [Done]

---

## Phase 1: Courier types & generated Supabase types

- **Goal:** Expose `tracking_url_template` on the frontend courier row type and regenerate DB types.
- **Depends On:** Phase 0
- **Priority:** P1
- **Files to Change:**
  - `web/src/modules/shop_order/repositories/dropshipCourierRepository.ts`
  - `web/src/types/supabase.ts` (**only** via `npm run backend:types` from `web/` — do not hand-edit)
- **Specification:**
  - Add `tracking_url_template: string | null` to `CourierServiceRow`.
  - Ensure `CreateCourierServicePayload` / `UpdateCourierServicePayload` pick it up via existing `Omit` / `Partial` (no separate payload fields unless needed).
  - Run `npm run backend:types` so generated types include the new column.
  - Do not change list/create/update query logic beyond typing (select remains `*`).
- **Rollback:** Revert repository interface change; re-run types gen after DB rollback, or restore previous `supabase.ts`.
- **Review Gate:** TypeScript compiles against `CourierServiceRow.tracking_url_template`; generated types mention the column.
- **Status:** [Done]

---

## Phase 2: Courier admin — edit tracking URL template

- **Goal:** Operators can set/edit `tracking_url_template` on the Couriers admin page.
- **Depends On:** Phase 1
- **Priority:** P1
- **Files to Change:**
  - `web/src/modules/shop_order/pages/DropshipCouriersPage.vue`
- **Specification:**
  - Add a dense outlined `q-input` bound to `form.tracking_url_template` in the courier create/edit dialog (near Notes).
  - Label: `Tracking URL Template`; hint/caption: use `{awb}` where the consignment number goes (e.g. `https://steadfast.com.bd/t/{awb}`).
  - Initialize `tracking_url_template: null` (or `''`) in `form` reset and map it when loading a row for edit.
  - Persist via existing `createCourier` / `updateCourier` — no new repository methods.
- **Rollback:** Revert `DropshipCouriersPage.vue` changes.
- **Review Gate:** Create/edit a courier with a template; reload page; value persists.
- **Status:** [Done]

---

## Phase 3: Enrich order items with SKU

- **Goal:** `getShopOrderById` returns product SKU on each line item for desk display.
- **Depends On:** None (independent of Phase 0–2)
- **Priority:** P0
- **Files to Change:**
  - `web/src/modules/shop_order/repositories/shopOrderRepository.ts`
  - `web/src/modules/shop_order/types/index.ts`
- **Specification:**
  - Add optional `sku: string | null` to `ShopOrderItem` in `types/index.ts`.
  - In `getShopOrderById`, change the items query from `select('*')` to a select that still returns all `shop_order_items` columns and joins product SKU, e.g. `select('*, products(sku)')` (or equivalent PostgREST embed), then map each row so `sku` is a flat field on the item (`row.products?.sku ?? null`) and strip the nested `products` object before returning.
  - Do not change order header select (`shop_orders` `select('*')`).
  - Do not add migrations; use existing `products.sku` (or the project’s actual SKU column name if different — verify with a quick grep on `products` schema before coding).
- **Rollback:** Revert the two files.
- **Review Gate:** Fetching an order with items returns `sku` populated when the product has one; orders still load if SKU is null.
- **Status:** [Done]

---

## Phase 4: Block F — inline order items table (P0)

- **Goal:** Show purchased line items on the desk page so operators stop context-switching.
- **Depends On:** Phase 3
- **Priority:** P0
- **Files to Change:**
  - `web/src/modules/shop_order/pages/DropshipOrderDetailPage.vue`
- **Specification:**
  - Insert a new `<q-card>` **Block F: Ordered Items** on the main (left) column **above Block B** (Parcel & COD). Prefer placement after Block A or immediately before Block B — must be above Block B.
  - Use existing `orderItems` ref (already hydrated from `getShopOrderById`); do not add a new fetch.
  - Table/list columns:
    - Thumbnail: `item.image_url` (small `q-img` or placeholder icon if null)
    - Title: `item.name`
    - SKU: `item.sku` (show `—` if null)
    - Qty: `item.quantity`
    - Customer price: `item.customer_sell_price_amount ?? item.final_price_amount ?? 0` via `formatBdt`
    - Cost (middleman): `item.unit_sell_price_amount ?? 0` via `formatBdt`
    - Line subtotal: customer unit price × `item.quantity` via `formatBdt`
  - Empty state: short caption if `orderItems.length === 0`.
  - Match existing card chrome (`flat bordered`, `form-card`, subtitle header with `q-icon`).
- **Rollback:** Revert Block F markup/logic in the page.
- **Review Gate:** Open a dropship order with items; thumbs, SKUs, qty, and both prices visible without leaving the page.
- **Status:** [Done]

---

## Phase 5: Auto-generate tracking URL from AWB

- **Goal:** Typing AWB / changing courier auto-fills `form.tracking_url` from the courier’s template.
- **Depends On:** Phase 1 (Phase 2 optional but recommended for ops)
- **Priority:** P1
- **Files to Change:**
  - `web/src/modules/shop_order/pages/DropshipOrderDetailPage.vue`
- **Specification:**
  - Add a `watch` on `[form.courier_awb_number, form.courier_service_id]` (and/or call from `onCourierChange`).
  - Resolve template from `selectedCourier` / `couriers` → `tracking_url_template`.
  - If template is null/empty, do nothing to `form.tracking_url`.
  - If template exists and AWB is non-empty after trim, set `form.tracking_url` to template with every `{awb}` replaced by the trimmed AWB.
  - If AWB becomes empty, do not clear a URL that was loaded from the server on hydrate; only clear/replace when the user is actively changing AWB/courier after hydrate (use a small flag or skip while `hydratingForm` is true).
  - Dirty tracking for Block E must still treat auto-filled URL as dirty vs `originalBlockE` (existing behavior is fine).
- **Rollback:** Remove the watch / related helpers.
- **Review Gate:** Select Steadfast (or seeded courier), type an AWB; tracking URL updates. Courier with null template leaves URL unchanged.
- **Status:** [Done]

---

## Phase 6: Collapsible Block C (merchant sender)

- **Goal:** Reduce vertical scroll by collapsing merchant pickup defaults when a merchant is already selected.
- **Depends On:** None (UI-only; can run after Phase 4 preferred for less merge conflict)
- **Priority:** P2
- **Files to Change:**
  - `web/src/modules/shop_order/pages/DropshipOrderDetailPage.vue`
- **Specification:**
  - Wrap Block C body in `<q-expansion-item>` (or equivalent Quasar expansion) keeping the existing card shell or converting header into the expansion header.
  - Default **expanded** when `selectedMerchantId` is null; default **collapsed** when a merchant is selected.
  - All fields remain editable when expanded (merchant select, sender name, pickup phone, pickup address).
  - Do not change save/dirty logic for Block C.
- **Rollback:** Restore Block C to non-collapsible `q-card` layout.
- **Review Gate:** Order with merchant selected opens with Block C collapsed; expanding shows fields; dirty bar still works on edits.
- **Status:** [Done]

---

## Phase 7: Address / phone quick-copy

- **Goal:** One-click copy of recipient phone and shipping address for pasting into courier portals.
- **Depends On:** None (UI-only)
- **Priority:** P2
- **Files to Change:**
  - `web/src/modules/shop_order/pages/DropshipOrderDetailPage.vue`
- **Specification:**
  - On Block A recipient **phone** and **address** inputs, add append/dense icon buttons `ph ph-copy`.
  - On click: `copyToClipboard` from Quasar with the current field value; on success call `showSuccessNotification` (or `$q.notify`) with a short message (`Phone copied` / `Address copied`).
  - No-op or error notify if value is empty.
  - Do not copy other fields in this phase.
- **Rollback:** Remove copy buttons and helpers.
- **Review Gate:** Click copy on phone and address; clipboard contains the values; toast appears.
- **Status:** [Done]

---

## Phase 8: Unified header primary CTA

- **Goal:** One prominent header action that advances the current lifecycle step.
- **Depends On:** None (uses existing handlers; best after Phases 4–7 to avoid header merge thrash)
- **Priority:** P1
- **Files to Change:**
  - `web/src/modules/shop_order/pages/DropshipOrderDetailPage.vue`
- **Specification:**
  - Add a computed primary CTA in the page header (`col-auto` action group), unelevated `color="primary"`, driven by order state:
    - `status === 'confirmed'` → label **Add to Dropship Desk** → `performHandoff` (loading: `handingOff`)
    - `status` in processing path **and** no `global_invoice_id` **and** dual-invoice is allowed by current rules → **Create Dual Invoice** → `openDualInvoiceDialog`
    - `delivered` (or settlement-visible) **and** `canRecordRemittance` → **Record Courier Remittance** → `openOrderRemittanceDialog`
    - `canSettlePayout` → **Settle Middle-Man Payout** → `settleOrderPayout` (loading: `settlingPayout`)
  - Show **at most one** primary CTA; priority if multiple match: handoff > dual invoice > remittance > settle payout.
  - Keep secondary actions as outline/secondary: Print Recipient Invoice, View Accounting Invoice (existing).
  - Do not remove the confirmed handoff banner in this phase unless it duplicates the header CTA awkwardly — if both would show the same action, keep banner text but you may remove the banner’s duplicate button **only** if the header CTA is always visible for `confirmed`.
  - Wire only existing functions; no new RPCs.
- **Rollback:** Remove primary CTA computed + button; restore any banner button if removed.
- **Review Gate:** Walk an order through confirmed → processing → delivered; header primary label/action matches each step; secondary buttons still work.
- **Status:** [Done]

---

## Suggested execution order

```
Phase 0 → Phase 1 → Phase 2
Phase 3 → Phase 4
Phase 5 (after Phase 1)
Phase 6, Phase 7 (anytime UI; prefer after Phase 4)
Phase 8 (last on DropshipOrderDetailPage.vue)
```

## Verification checklist (after all phases)

1. Inline items: thumbs, SKU, qty, customer vs cost prices on desk page.
2. AWB + Steadfast/Pathao/RedX auto-builds tracking URL.
3. Dirty bar still appears on edits; Save persists.
4. Phone/address copy works.
5. Header primary CTA matches lifecycle; remittance/payout still succeed.
