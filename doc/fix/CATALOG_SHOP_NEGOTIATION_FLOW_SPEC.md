# Catalog Shop Negotiation — Implementation Plan

**File:** `doc/fix/CATALOG_SHOP_NEGOTIATION_FLOW_SPEC.md`  
**Updated:** 2026-07-30  
**Scope:** `vendor_catalog` only · **Do not touch dropship**  

---

## 0. UX rules (locked)

| Actor | Device | Pattern |
|-------|--------|---------|
| **Customer** | Mobile-first | Card list, sticky bottom CTA, large tap targets, one primary action per status. No dense tables. |
| **Staff / admin** | Desktop | Same tabular standard as [`ProductBasedCostingFileDetailsPage.vue`](../../web/src/modules/product_based_costing/pages/ProductBasedCostingFileDetailsPage.vue): header + workflow bar + summary + **items table** + column selector + sticky save. |

Reuse PBC pieces where possible: column preference, workflow bar layout, table cell edit patterns — do **not** import PBC domain logic.

---

## 1. Status ladder (catalog only)

```text
submitted → costing_pending → priced
  Path A: → countered? → final_offered → confirmed
  Path B: → final_offered → confirmed   (never countered)
confirmed → procuring → ordered → delivered
(+ cancelled from pre-ordered states)
```

| Status | Who acts next |
|--------|----------------|
| `submitted` | Staff → costing |
| `costing_pending` | Staff saves offers → `priced` |
| `priced` | A: customer counter/accept · B: staff/customer → final |
| `countered` | Staff finals → `final_offered` |
| `final_offered` | Customer sets `confirmed_quantity` → `confirmed` |
| `confirmed` | Staff → `procuring` |
| `procuring` | Staff `ordered_quantity` → `ordered` (+ backlog if short) |
| `ordered` | Staff `delivered_quantity` → `delivered` (+ invoice) |
| `delivered` | Done |
| `cancelled` | Terminal |

**Gates:** Path A = `is_negotiable` ∧ `can_negotiate`. Submit always → `submitted`.

**Enum add:** `costing_pending`, `countered`, `final_offered`, `procuring`, `ordered`. Reuse `delivered`.

---

## 2. Pages (short contracts)

### S1 — Staff catalog order detail
**File:** `web/src/modules/shop_order/pages/StaffOrderDetailPage.vue`  
**Layout:** PBC-like — header, status workflow bar, rate strip (FX / cargo / profit / basis), `ShopOrderItemsTable` (new), column selector, sticky footer actions by status.

| Status | Table focus | Footer CTA |
|--------|-------------|------------|
| `submitted` / `costing_pending` | Weights + computed offer | Save offers → `priced` |
| `priced` / `countered` | staff vs customer vs final | Save finals → `final_offered` |
| `final_offered` / `confirmed` | read-only finals + confirmed qty | Start procuring |
| `procuring` | edit `ordered_quantity` | Save → `ordered` |
| `ordered` | edit `delivered_quantity` | Save → `delivered` |

**New components (under `web/src/modules/shop_order/components/`):**
- `CatalogOrderWorkflowBar.vue` — status chips
- `CatalogOrderRatesBar.vue` — conversion / cargo / profit / basis
- `CatalogOrderItemsTable.vue` — QTable, inline edit, column selector (mirror PBC table UX)
- `CatalogOrderColumnSelectorDialog.vue`

### S2 — Staff catalog orders list
**File:** `web/src/modules/shop_order/pages/ShopOrdersPage.vue`  
**Change:** Filter `shop_type_snapshot = vendor_catalog` (or tab). Status badges for new enum. Do not mix dropship rows.

### C1 — Customer order detail (mobile)
**File:** `web/src/modules/shop_order/pages/CustomerOrderDetailPage.vue`  
**Layout:** Vertical item **cards** (image, name, qty, prices). Sticky bottom bar for the single primary action. No QTable.

| Status | Card content | Sticky CTA |
|--------|--------------|------------|
| `submitted` / `costing_pending` | Name, qty, optional list price | none / Cancel |
| `priced` (A) | Staff offer + counter input | Submit counter · Accept offer |
| `priced` (B) | Staff offer (read) | Wait / none until final |
| `countered` | Offers read-only | none |
| `final_offered` | Final price + qty stepper (`confirmed_quantity`) | Confirm order |
| `confirmed`+ | Progress: confirmed / ordered / delivered qty | none |

### C2 — Customer orders list (mobile)
**File:** `web/src/modules/shop_order/pages/CustomerOrdersPage.vue`  
**Change:** Badge labels for new statuses; tap → C1.

### Routes
**Files:** `web/src/modules/shop_order/routes/adminRoutes.ts`, `shopRoutes.ts`  
No new routes required if S1/C1 already wired; only add query/tab if list splits catalog vs other.

---

## 3. Data (short)

**Migration (new file under `supabase/migrations/`):**
1. `ALTER TYPE shop_order_status ADD VALUE` ×5 (see §1).
2. `shop_orders.profit_basis` text check `purchase|total_cost`.
3. `shop_order_items`: `confirmed_quantity`, weight/cost snapshots, `customer_decision_status`, `negotiation_status`, timestamps.
4. Table `customer_order_backlog_items` + unique `(tenant_id, billing_profile_id, product_id)` + RLS.
5. Catalog RPCs — each checks `shop_type_snapshot = 'vendor_catalog'`.

**Offer formula (staff table computes client-side; persist on save):**  
`RoundUpToNearestFive(ceil(profit_base + profit_base × pct/100))` in sell currency.  
`profit_base` = total_cost_sell or purchase×FX per `profit_basis`.

**Types:** `web/src/modules/shop_order/types/index.ts` + regen `web/src/types/supabase.ts`.

---

## 4. Phases for low-context AI

Each phase = one PR-sized job. Agent should open **only listed files**.

---

### Phase P0 — Schema + types
**Goal:** DB supports ladder + line fields. No UI behavior yet.

| File | What to change |
|------|----------------|
| `supabase/migrations/YYYYMMDDHHMMSS_catalog_negotiation_schema.sql` | **Create:** enum values, columns, backlog table, RLS, stub RPC signatures if needed |
| `web/src/modules/shop_order/types/index.ts` | Add statuses + item fields to `ShopOrderStatus` / order item type |
| Run `npm run backend:types` | Refresh `web/src/types/supabase.ts` only via script |

**Done when:** migration applies; types compile; dropship migrations untouched.

---

### Phase P1 — Submit + costing RPC + Path B confirm chain
**Goal:** Non-negotiate path works API-first: `submitted → costing_pending → priced → final_offered → confirmed`.

| File | What to change |
|------|----------------|
| `supabase/migrations/…_catalog_negotiation_rpcs_p1.sql` | Fix `submit_shop_order_from_cart` catalog → always `submitted`. Extend/replace `staff_price_shop_order` for rates/weights/`priced`. Add `staff_finalize_catalog_prices`, `customer_confirm_shop_order`. All guard `vendor_catalog`. |
| `web/src/modules/shop_order/repositories/shopOrderRepository.ts` | Wire new RPC names/params |
| `web/src/modules/shop_order/services/shopOrderService.ts` | Thin passthrough methods |

**Done when:** Path B can be exercised via RPC/SQL; Path A counter still unused; dropship submit unchanged.

---

### Phase P2 — Staff tabular UI (PBC pattern) for costing + finals
**Goal:** Admin costing/final screens match project table standard.

| File | What to change |
|------|----------------|
| `web/src/modules/shop_order/components/CatalogOrderItemsTable.vue` | **Create** — QTable, editable cells by status, column visibility |
| `web/src/modules/shop_order/components/CatalogOrderColumnSelectorDialog.vue` | **Create** — copy UX from PBC column selector |
| `web/src/modules/shop_order/components/CatalogOrderRatesBar.vue` | **Create** — FX, cargo, profit %, basis |
| `web/src/modules/shop_order/components/CatalogOrderWorkflowBar.vue` | **Create** — status steps |
| `web/src/modules/shop_order/pages/StaffOrderDetailPage.vue` | Compose S1 layout; status-gated footer; call P1 RPCs |
| `web/src/modules/shop_order/composables/useCatalogOrderMutations.ts` | **Create** — TanStack mutations, invalidate detail query |
| Optional: `…/composables/useCatalogOrderDetailQuery.ts` | Detail query key + fetch |

**Done when:** Staff can cost → `priced` and finalize → `final_offered` on desktop table UI.

**Copy from (read-only reference):**  
`product_based_costing/pages/ProductBasedCostingFileDetailsPage.vue`, `ProductBasedCostingItemsTable.vue`, `ProductBasedCostingPreviewColumnSelectorDialog.vue`, `ProductBasedCostingFileWorkflowBar.vue`.

---

### Phase P3 — Customer mobile Path A + Path B
**Goal:** Mobile cards + sticky CTAs for offer/counter/confirm.

| File | What to change |
|------|----------------|
| `web/src/modules/shop_order/pages/CustomerOrderDetailPage.vue` | Status switch; card list; sticky CTA; no table |
| `web/src/modules/shop_order/components/CustomerCatalogOrderItemCard.vue` | **Create** — one card: image, name, offers, counter input / qty stepper |
| `web/src/modules/shop_order/components/CustomerOrderStickyActions.vue` | **Create** — bottom bar actions by status |
| `web/src/modules/shop_order/pages/CustomerOrdersPage.vue` | New status badges/labels |
| `supabase/migrations/…_catalog_counter_rpc.sql` | Extend `customer_counter_offer` → `countered`; reject if not negotiable |
| `web/src/modules/shop_order/repositories/shopOrderRepository.ts` | Counter + accept-offer calls |

**Done when:** Path A counter→final→confirm and Path B final→confirm work on narrow viewport.

---

### Phase P4 — Native procuring / ordered / delivered + backlog
**Goal:** Phase 2 ops on same staff table; backlog upsert; invoice on deliver.

| File | What to change |
|------|----------------|
| `supabase/migrations/…_catalog_procurement_rpcs.sql` | `staff_start_catalog_procurement`, `staff_set_catalog_ordered_qty` (+ `upsert_order_backlog_from_item`), `staff_set_catalog_delivered_qty` (+ invoice hook). Guard vendor_catalog only. |
| `web/src/modules/shop_order/pages/StaffOrderDetailPage.vue` | Table modes for ordered/delivered qty; CTAs |
| `web/src/modules/shop_order/components/CatalogOrderItemsTable.vue` | Columns for ordered/delivered |
| `web/src/modules/shop_order/components/CatalogBacklogDrawer.vue` | **Create** — list open backlog (pattern: `PbcBacklogSuggestDrawer.vue`) |
| `web/src/modules/shop_order/repositories/shopOrderRepository.ts` | Procurement RPCs |
| Customer C1 | Read-only progress row on cards post-`confirmed` |

**Done when:** Shortfall creates backlog; deliver sets `delivered` + invoice; dropship QA green.

---

### Phase P5 — Lists, badges, polish
**Goal:** Lists/filters/i18n only.

| File | What to change |
|------|----------------|
| `web/src/modules/shop_order/pages/ShopOrdersPage.vue` | Catalog filter; status chips |
| `web/src/modules/shop_order/components/ShopOrdersFilters.vue` | New status options |
| `web/src/modules/shop_order/components/CustomerOrderHeader.vue` | Badge map for new statuses |
| `web/src/modules/shop_order/components/StaffOrderHeader.vue` / `StaffOrderStatusWorkflow.vue` | Align or replace with CatalogOrderWorkflowBar |
| Locale files under `web/src/i18n/` (shop_admin keys) | Labels for statuses/CTAs |

**Done when:** Staff/customer can filter and read every status; no dropship desk regression.

---

## 5. Dropship isolation

- Do **not** edit dropship pages, dropship migrations, or dropship advance/wallet RPCs.
- Catalog RPCs: `IF shop_type_snapshot <> 'vendor_catalog' THEN raise`.
- List UIs: filter by `shop_type_snapshot`.

---

## 6. Verify checklist (per phase)

| Phase | Quick verify |
|-------|----------------|
| P0 | `\dT+ shop_order_status` shows new values; backlog table exists |
| P1 | SQL/RPC Path B → `confirmed` |
| P2 | Desktop: table edit weights → status `priced` |
| P3 | Mobile width: counter + confirm CTAs |
| P4 | ordered < confirmed → backlog row; deliver → `delivered` |
| P5 | Catalog list badges; dropship list unchanged |

---

## 7. Out of scope

Dropship · fixed_price checkout · Firestore migration · changing PBC module code (reference only).
