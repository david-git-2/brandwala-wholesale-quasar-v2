# Dropship Processing — Stock Pick, Hold & Unavailable Lines

Staff pick physical stock on the **processing desk** and tie it to order lines. One order line can pull from **multiple stock rows / shipments**. Lines with no stock can be **marked unavailable** (delivered qty 0). **Delivered qty** is computed — never typed manually.

**Related:** [`UI_FLOW.md`](./UI_FLOW.md) §11.8 · [`SHOP_ORDER.md`](./SHOP_ORDER.md) §10.2 · [`SHOP_ORDER.md`](./SHOP_ORDER.md) §6.5 · [`DEMAND_BUCKET.md`](./DEMAND_BUCKET.md) · [`PBC_COSTING.md`](../product_based_costing/PBC_COSTING.md) (unavailable pattern)

---

## 1. End-to-end flow (locked)

```text
Customer places order (confirmed)
        │
        │  No stock linked / held yet (target — see §3.3)
        ▼
Staff: Start processing → status = processing
        │
        ▼
Per order line (while processing):
  • Pick stock (dialog) until delivered = ordered     OR
  • Mark unavailable → delivered = 0, no picks
        │
        ▼
Every line resolved?  (fully picked OR marked unavailable)
        │
        ▼
Ready for pickup  →  ship picked qty; customer invoice / COD uses delivered qty only
```

| Stage | Stock linked? | Delivered qty |
| :--- | :--- | :--- |
| After customer order | **No** (target) | 0 |
| During processing picks | Yes — per pick row | `sum(picks)` |
| Line marked unavailable | No picks | **0** |
| Ready for pickup | All lines resolved | Per line as above |

---

## 2. Problem (current state)

| Gap | Detail |
| :--- | :--- |
| **No pick UI** | `DropshipOrderDetailV2ProcessingPage` saves charges, courier, pickup, and **manual** `confirmed_quantity` only. |
| **Single stock pointer** | `shop_order_items.global_stock_id` holds at most one row. Multi-shipment fulfillment is not modeled. |
| **Auto-hold at checkout** | `submit_dropship_order_from_cart` holds stock FIFO by grade before staff pack. |
| **No unavailable path** | Staff cannot mark “stock gone” without typing delivered qty = 0 manually. |
| **Invoice / return assume one stock** | Invoice builders join one `global_stock_id` per line. |

**Reusable today:**

- `list_allocated_stock_for_shop` — search by name, barcode, shipment, grade, ATP
- `create_and_post_stock_movement` — sellable → held, ref `shop_order`
- PBC **`unavailable`** outcome — backlog shortfall pattern in [`PBC_COSTING.md`](../product_based_costing/PBC_COSTING.md)

---

## 3. Target UX (locked)

### 3.1 Per line — processing desk

| Control | When visible | Action |
| :--- | :--- | :--- |
| **Pick stock** | `processing`, line not unavailable | Opens pick dialog (§3.2) |
| **Mark unavailable** | `processing`, no picks on line | Confirm → delivered 0; line resolved |
| **Unavailable badge** | Line marked unavailable | Read-only; hide Pick stock |
| **Delivered qty** | Always | Read-only = `sum(picks)` or **0** if unavailable |

**Pick stock** dialog:

1. Pre-filtered to line `product_id` (+ `grade_tag_id` when set).
2. Search via `list_stock_for_order_item_pick`.
3. Table: shipment name, available ATP, grade, optional cost.
4. Each row: qty input + **Add** → hold + link pick.
5. Linked picks listed under line (shipment, stock id, qty).

Same product from two shipments = two pick rows on one line.

### 3.2 Line resolution states

| State | Condition | Delivered qty | Ready for pickup? |
| :--- | :--- | :--- | :--- |
| **Pending** | Not unavailable; `sum(picks) < quantity` | `sum(picks)` | Order blocked |
| **Picked** | `sum(picks) = quantity` | `quantity` | Line resolved |
| **Unavailable** | `is_fulfillment_unavailable = true`; no picks | **0** | Line resolved |

**Ready for pickup** when **every** line with `quantity > 0` is **Picked** or **Unavailable**.

Banner lists lines still **Pending**.

---

## 4. Data model

### 4.1 New table: `shop_order_item_stock_picks`

```sql
CREATE TABLE shop_order_item_stock_picks (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id           bigint NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
  order_id            bigint NOT NULL REFERENCES shop_orders(id) ON DELETE CASCADE,
  order_item_id       bigint NOT NULL REFERENCES shop_order_items(id) ON DELETE CASCADE,
  global_stock_id     bigint NOT NULL REFERENCES global_stocks(id),
  shipment_item_id    bigint NOT NULL REFERENCES global_shipment_items(id),
  shipment_id         bigint NOT NULL REFERENCES global_shipments(id),
  quantity            integer NOT NULL CHECK (quantity > 0),
  held_stock_id       bigint REFERENCES global_stocks(id),
  created_by_email    text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (order_item_id, global_stock_id)
);
```

| Rule | Detail |
| :--- | :--- |
| **Cap** | `sum(quantity)` per line ≤ `shop_order_items.quantity` |
| **Blocked when unavailable** | No picks if `is_fulfillment_unavailable = true` |
| **Product / grade** | Must match line product; grade when line has `grade_tag_id` |

### 4.2 `shop_order_items` — new columns

```sql
ALTER TABLE shop_order_items
  ADD COLUMN is_fulfillment_unavailable boolean NOT NULL DEFAULT false,
  ADD COLUMN unavailable_reason text,
  ADD COLUMN unavailable_at timestamptz,
  ADD COLUMN unavailable_by_email text;
```

| Field | Rule |
| :--- | :--- |
| `is_fulfillment_unavailable` | Set by staff RPC; mutually exclusive with picks |
| `confirmed_quantity` | **Computed**: unavailable → `0`; else `sum(stock_picks.quantity)` |
| `global_stock_id` | Legacy: first pick’s `held_stock_id` only |

Do **not** infer unavailable from `confirmed_quantity = 0` alone (also means “not started”).

### 4.3 Checkout auto-hold & reservation policy

**Target:** No **pick rows** and no **sellable → held** movement until staff act on the processing desk.

**Reservation policy (choose one before Phase 4 — document decision in migration):**

| Option | Behavior | Trade-off |
| :--- | :--- | :--- |
| **A — Soft reserve at order (recommended)** | Keep grade-pool or cart reservation between confirm → processing; **replace** with explicit picks when staff pack; release reservation on pick or cancel | Prevents two orders claiming the last units; slightly more SQL |
| **B — No reserve until processing** | Remove checkout hold entirely; first picker wins at processing desk | Simpler; oversell risk if many orders queue for same SKU |

**Backfill:** Existing orders with `global_stock_id` → one pick row; unavailable lines stay flagged separately.

---

## 5. RPCs

### 5.1 `list_stock_for_order_item_pick`

- Order status `processing`; line not unavailable.
- Returns sellable stock + `meta.already_picked`.

### 5.2 `add_shop_order_item_stock_pick`

- Reject if line unavailable or over cap.
- Hold sellable → held; upsert pick row; recompute `confirmed_quantity`.

### 5.3 `mark_shop_order_item_unavailable`

```sql
mark_shop_order_item_unavailable(
  p_order_item_id bigint,
  p_reason text default null,
  p_add_to_demand_bucket boolean default true   -- default ON; staff can opt out in UI
) returns jsonb
```

Steps:

1. Validate order `processing`; line has **zero** picks (v1) — see §12.1 partial ship for v1.5 exception.
2. Set `is_fulfillment_unavailable = true`, audit fields, `confirmed_quantity = 0`.
3. **Default:** `add_demand_bucket_item` for full ordered qty (shortfall for next order). Opt-out checkbox in confirm dialog.

### 5.4 `clear_shop_order_item_unavailable` (Phase 2 — v1)

- Clears flag; line returns to **Pending**; staff can pick again.
- Audit: clear `unavailable_at` / `unavailable_by_email`; do not delete demand-bucket row (cancel bucket entry separately if needed).

### 5.5 `remove_shop_order_item_stock_pick` (Phase 2 — v1)

- Decrement or delete pick row; held → sellable movement; recompute `confirmed_quantity`.
- Required for ops mistakes — not deferred to Phase 4.

### 5.6 Detail payload — `get_dropship_order_detail_v2`

Per item:

```jsonc
{
  "stock_picks": [ { "shipment_name": "...", "quantity": 3, ... } ],
  "is_fulfillment_unavailable": false,
  "unavailable_reason": null,
  "confirmed_quantity": 3,
  "fulfillment_resolved": true
}
```

`fulfillment_resolved` = picked **or** unavailable.

---

## 6. Business rules

| Rule | Value |
| :--- | :--- |
| **Delivered qty** | Read-only UI; `0` if unavailable else `sum(picks)` |
| **Ready for pickup** | Every line: `(sum(picks) = quantity) OR (unavailable AND sum(picks) = 0)` |
| **Partial pick (v1)** | Not allowed — pick full qty **or** mark whole line unavailable (see §12.1 for v1.5) |
| **Invoice / COD** | Bill **delivered qty only**; skip unavailable lines; **recalc `cod_collect_amount` live** when picks/unavailable change (Phase 3) |
| **Customer invoice lines** | One line per **pick** (picked lines); unavailable lines omitted |
| **Stock consume** | Held → sold/deduct **per pick qty** at invoice issue (`ready_for_pickup`+), not one row per line |
| **All lines unavailable** | **Block** ready for pickup; prompt staff to **cancel order** or contact merchant — do not ship empty parcel (§12.5) |
| **Cancel / rollback** | Release all picks via `release_dropship_order_stock`; on rollback to `processing`, keep picks editable via undo RPCs. **Cancel order UI** — see §13 |
| **Demand bucket** | **Default ON** when marking unavailable; opt-out in confirm dialog |

---

## 7. Frontend changes

| File | Change |
| :--- | :--- |
| `DropshipOrderConfirmedInvoicePaper.vue` | Read-only delivered qty; pick list; **Pick stock** + **Mark unavailable** per line; unavailable badge |
| **New** `DropshipOrderItemStockPickDialog.vue` | Search, ATP table, qty + Add |
| `useDropshipOrderProcessingDesk.ts` | Remove manual delivered qty form; gate ready-for-pickup on `fulfillment_resolved` per line |
| `shopOrderRepository.ts` | Pick + mark-unavailable + **cancel order** RPCs; stop writing `confirmed_quantity` in desk save |
| **New** `DropshipOrderCancelDialog.vue` | Confirm cancel + optional reason; shows restock summary for current stage |

---

## 8. Downstream RPC updates

| RPC | Change |
| :--- | :--- |
| `get_dropship_order_detail_v2` | `stock_picks[]`, unavailable fields, `fulfillment_resolved` |
| `release_dropship_order_stock` | Release all picks (loop `shop_order_item_stock_picks`) |
| **`cancel_shop_order_dropship`** (new) | Validated cancel + restock + invoice/wallet cleanup — §13 |
| `advance_dropship_order_status` | Keep `cancelled` transition; delegate stock release to shared helper |
| `create_dual_invoice_from_dropship_order` / payload builders | Invoice from picks only; exclude unavailable lines |
| Customer invoice / COD totals | Resell × delivered qty per line |
| `submit_dropship_order_from_cart` | Phase 4: no checkout hold |

---

## 9. Implementation phases

### Phase 1 — Schema + pick RPCs

**Goal:** `shop_order_item_stock_picks`, unavailable columns, pick list/add RPCs, detail RPC.

**Files:** `supabase/schemas/shop_order/02_tables.sql`, `03_rpcs.sql`, `04_rls.sql`, migration + backfill.

---

### Phase 2 — Unavailable RPC + processing UI + undo

**Goal:** Pick dialog, mark unavailable, **undo pick / clear unavailable**, read-only delivered qty, ready-for-pickup gate (incl. all-unavailable block).

**Files:** schema RPCs (`mark_*`, `clear_*`, `remove_*`) + `DropshipOrderItemStockPickDialog.vue`, `DropshipOrderConfirmedInvoicePaper.vue`, `useDropshipOrderProcessingDesk.ts`, repository, types, mapper.

**Change:**

- Demand bucket **default ON** in mark-unavailable dialog.
- Disable ready for pickup when `sum(all line delivered qty) = 0` (§12.5) — offer **Cancel order** as primary action.
- **Cancel order** button + dialog on all dropship detail V2 pages where §13 allows (Phase 2).
- Show computed COD preview when picks change (read-only until Phase 3 persists).

---

### Phase 3 — Invoice + release + COD alignment

**Goal:** Invoice/COD from picks; consume stock per pick; release picks on cancel; **persist COD recalc**.

**Files:** `release_dropship_order_stock`, `sales_invoice/03_rpcs.sql` invoice builders, `update_shop_order_charges_for_staff` or dedicated `recompute_dropship_cod_collect_amount`.

**Change:**

- RPC or trigger: on pick add/remove/unavailable → recompute `shop_orders.cod_collect_amount` from delivered resell + charge rows.
- Align invoice auto-create timing with `advance_dropship_order_status` → `ready_for_pickup` (verify against current schema drift).
- `post_sales_invoice` / consume: one movement per pick row qty.

---

### Phase 4 — Reservation policy at checkout

**Goal:** Implement §4.3 option A or B; remove duplicate hold when picks are written.

**Files:** `submit_dropship_order_from_cart`, `shop_stock_reservations`, grade hold helpers.

---

### Phase 5 — Partial ship & returns (v1.5 / v2)

**Goal:** Partial line fulfillment and pick-aware returns (§12.1, §12.6).

**Files:** extend mark-unavailable / new `mark_shop_order_item_shortfall`; return RPCs; demand bucket qty = shortfall not full line.

---

## 10. Out of scope (later phases — see §12)

- Camera / hardware barcode scan (§12.4)
- Pick before `processing`
- Fixed-price / vendor_catalog desks
- Batch / wave pick across multiple orders
- Product substitution (different SKU replaces ordered SKU)
- Customer SMS/email notification on shortfall (§12.3)
- Customer portal “packed 2 of 3” status

---

## 11. Verification checklist

- [ ] Order confirmed → no pick rows until processing starts
- [ ] Pick shipment A + B on one line → delivered = sum; two pick rows
- [ ] Mark unavailable → delivered 0, demand bucket row created (default), line resolved
- [ ] Mixed order: line A fully picked + line B unavailable → ready for pickup enabled
- [ ] **All lines unavailable → ready for pickup blocked**; cancel or fix lines
- [ ] Ready blocked while any line still pending
- [ ] Remove pick → hold released, delivered qty drops
- [ ] Clear unavailable → line pending again, can pick
- [ ] COD preview / persisted total matches delivered resell only after Phase 3
- [ ] Cancel → all pick holds released; status `cancelled` (§13)
- [ ] Cancel blocked after shipped
- [ ] Invoice lines match pick rows (count + qty), not order lines
- [ ] `backend:reset` clean

---

## 12. Recommended additions (gap closure)

Review against a typical OMS/WMS. Items below were missing from v1; **priority** guides phase placement.

### 12.1 Partial ship on one line (Phase 5 — high business value)

**Gap:** v1 forces whole line unavailable when only part of stock exists (ordered 5, have 3).

**Target behavior:**

- Pick 3 from stock → delivered = 3; line **still pending** until staff either:
  - pick remaining 2 when stock arrives, **or**
  - **Mark shortfall** on remaining 2 (new action or extend unavailable to `p_shortfall_qty` only).
- `confirmed_quantity = sum(picks)`; shortfall qty optional → demand bucket.
- Ready for pickup when `sum(picks) + shortfall_qty = quantity` (resolved with partial).

**Schema option:** `shop_order_items.shortfall_quantity integer default 0` or reuse unavailable with partial flag.

---

### 12.2 Undo pick & clear unavailable (Phase 2 — v1, ops critical)

**Gap:** Staff mis-clicks Add or Mark unavailable.

**Already in plan:** §5.4, §5.5 — implement in **Phase 2**, not optional Phase 4.

---

### 12.3 Customer / merchant communication (Phase 6 — medium)

**Gap:** No notify when lines marked unavailable or short.

**Target:**

- Optional webhook / manual “Notify merchant” on processing desk when any line has `delivered < ordered`.
- Future: SMS/email to recipient before `ready_for_pickup` when COD total changed.
- Out of scope until notification infra exists; log `unavailable_reason` for merchant review on order detail.

---

### 12.4 Barcode scan at pick (Phase 6 — medium)

**Gap:** Search-only pick dialog; Thrift has `resolve_thrift_barcode`.

**Target:**

- Scan field in pick dialog → filter `list_stock_for_order_item_pick` by barcode / stock id token.
- Future: encode `GS:{global_stock_id}` on warehouse labels.
- Reuse Thrift scan UX pattern; no camera requirement in v1 web.

---

### 12.5 All-unavailable order edge case (Phase 2 — v1)

**Gap:** Every line unavailable → ready for pickup would ship nothing.

**Rule (locked):**

- If `sum(all line confirmed_quantity) = 0` → **disable** ready for pickup.
- Show banner: “Nothing to ship — cancel order or pick stock.”
- Do not create invoice with zero item lines unless order cancelled.

---

### 12.6 Returns per pick row (Phase 5 — medium)

**Gap:** `mark_dropship_order_returned` matches one `global_stock_id` per line; multi-pick lines need return qty per pick/shipment.

**Target:**

- Return payload references `shop_order_item_stock_picks.id` + qty.
- Restock to correct shipment batch / grade.

---

### 12.7 COD & summary live recalc (Phase 3 — high)

**Gap:** Processing desk edits charges but COD may stay stale when delivered qty changes.

**Target:**

- After every pick add/remove/unavailable: recompute `items_resell_delivered_total` and `cod_collect_amount` (same formula as `get_dropship_order_detail_v2` `computed.recipient_grand_total` but using delivered qty).
- Persist on `shop_orders.cod_collect_amount` before ready for pickup.
- Customer invoice print uses persisted value.

---

### 12.8 Demand bucket default (Phase 2 — medium)

**Gap:** Optional flag easy to forget; shortfall lost.

**Rule:** `p_add_to_demand_bucket default true`; UI checkbox “Add to customer demand bucket” pre-checked; staff unchecks only when intentional.

---

### 12.9 Coverage matrix (typical OMS vs this plan)

| Capability | v1 plan | Later §12 |
| :--- | :---: | :---: |
| Order capture & status workflow | Existing app | — |
| Pick + hold + multi-shipment | Phase 1–2 | — |
| Mark line unavailable | Phase 2 | — |
| Undo pick / unavailable | Phase 2 | §12.2 |
| Soft reservation confirm→processing | Phase 4 | §4.3 option A |
| Partial ship same line | — | §12.1 Phase 5 |
| COD recalc on delivered qty | Phase 3 | §12.7 |
| All-unavailable guard | Phase 2 | §12.5 |
| Demand bucket on shortfall | Phase 2 default | §12.8 |
| Barcode scan | — | §12.4 |
| Customer notify | — | §12.3 |
| Returns per pick | — | §12.6 |
| Cancel order (detail UI + restock) | Phase 2–3 | §13 |
| Substitute SKU | — | Out of scope |
| Wave / batch pick | — | Out of scope |
| **Cancel after shipped** | — | Use **returned** flow, not cancel (§13) |

---

## 13. Cancel order (UI + restock by stage)

**Gap today:** Dropship detail V2 pages (`confirmed`, `processing`, `ready-for-pickup`) have **no cancel button**. `DropshipOrdersPage` list uses **`delete_shop_order`** (hard delete + legacy qty bump on `global_stocks`), not status `cancelled` + proper stock movements. Catalog staff detail has delete; dropship paper workflow does not.

**Policy:** Prefer **cancel** (soft, `status = cancelled`, audit trail) on detail pages. Reserve **hard delete** for list/admin cleanup of mistaken drafts only — not the primary ops path once picks exist.

### 13.1 RPC: `cancel_shop_order_dropship`

```sql
cancel_shop_order_dropship(
  p_order_id bigint,
  p_reason text default null
) returns jsonb
```

Single transaction:

1. Lock order; validate dropship + `is_tenant_staff`.
2. Validate status ∈ **cancel allowlist** (§13.3) — reject with clear error otherwise.
3. **Restock / release** per §13.2 (stage-specific).
4. Delete `shop_order_item_stock_picks` rows (after holds released).
5. Clear `is_fulfillment_unavailable` on all lines (audit kept via order status + optional `p_reason` on order note field if exists).
6. `advance_dropship_order_status(p_order_id, 'cancelled')` — or inline status update + shared release helper (avoid double release).
7. Return `{ success, new_status, restock_summary }` for UI toast.

**Do not** use raw `delete_shop_order` from dropship detail UI — it bypasses held→sellable movements and will not know about pick rows.

Extend `release_dropship_order_stock` to release **each pick row** qty (Phase 3), not only `shop_order_items.global_stock_id`.

### 13.2 Restock / cleanup by order status

| Order status | Cancel allowed? | Stock / listing actions | Invoice & money |
| :--- | :---: | :--- | :--- |
| `submitted`, `draft`, `placed` | Yes | No picks yet; restore listing `display_quantity_override` if checkout hold ran (legacy); release cart reservations | None |
| `confirmed` | Yes | Release checkout grade-hold / reservation (Phase 4 policy); no pick rows | None |
| `processing` | Yes | Release **all pick holds** (held → sellable per pick qty); restore listing display qty for ordered lines | Delete draft invoice if `global_invoice_id` set and status draft; purge wallet ledger rows tied to order (same as rollback-to-processing path) |
| `ready_for_pickup` | Yes (warn) | Same as processing — release picks + holds | **Unpost** issued invoice if present (`unpost_global_invoice`); delete invoice lines + header if draft; reverse profit ledger if posted |
| `shipped` | **No** | Parcel with courier — use operational recall or **returned** status | — |
| `delivered` | **No** | Use **return** / `mark_dropship_order_returned` | — |
| `payment_received`, `returned` | **No** | Financially closed | — |
| `cancelled` | — | Already cancelled | — |

**After cancel:** order stays in DB with `status = cancelled` (list filter, audit). Stock back in sellable pool; listings display qty restored where applicable.

### 13.3 When the Cancel button appears (UI rules)

Expose **`can_cancel_order`** on `get_dropship_order_detail_v2.permissions`:

```jsonc
"permissions": {
  "can_cancel_order": true,
  "cancel_blocked_reason": null
}
```

| Condition | `can_cancel_order` | Button placement |
| :--- | :---: | :--- |
| Status in §13.2 allowlist | `true` | Danger zone footer on detail V2 pages |
| Status `shipped` / `delivered` / `payment_received` / `returned` | `false` | Hidden; tooltip “Use return flow” if needed |
| Already `cancelled` | `false` | Show cancelled badge only |
| Issued invoice + status beyond allowlist | `false` | `cancel_blocked_reason` explains why |

**Promoted cancel (UX):**

- When §12.5 **all lines unavailable** banner shows → primary CTA **Cancel order** (secondary: go back and pick).
- Processing desk danger zone: outline negative **Cancel order** always when `can_cancel_order`.

**Not on happy-path status strip** — separate danger action to avoid mis-clicks.

### 13.4 UI components & wiring

| Surface | Change |
| :--- | :--- |
| `DropshipOrderDetailV2Page.vue` | Footer danger zone: Cancel + confirm dialog |
| `DropshipOrderDetailV2ProcessingPage.vue` | Same; include in banner when nothing to ship |
| `DropshipOrderDetailV2ReadyForPickupPage.vue` | Cancel with extra warning if invoice exists |
| `DropshipOrderConfirmedInvoicePaper.vue` | Optional shared slot `#danger-actions` or sibling footer |
| `DropshipOrdersPage.vue` | Keep row delete for **draft/submitted only** OR replace with cancel — document: list **Cancel** calls `cancel_shop_order_dropship`; **Delete** only when never processed |
| `useDropshipOrderMutations.ts` | `useCancelDropshipOrderMutation` → `cancel_shop_order_dropship` |
| Post-success | Redirect to `DropshipOrdersPage` with filter `cancelled` or stay on read-only cancelled view |

**Dialog copy (example):**

- Title: “Cancel this order?”
- Body: lists restock effect (“2 pick holds will be released back to sellable stock”).
- Optional reason field → `p_reason`.
- Confirm → RPC; toast with `restock_summary`.

### 13.5 Phase placement

| Phase | Cancel work |
| :--- | :--- |
| **Phase 2** | UI button + dialog + `can_cancel_order`; RPC v1 for `confirmed` / `processing` using extended `release_dropship_order_stock` |
| **Phase 3** | Cancel from `ready_for_pickup` with invoice unpost; pick-table-aware release |
| **Phase 4** | Align checkout reservation release on cancel at `confirmed` |

### 13.6 Verification (cancel)

- [ ] Cancel at `confirmed` → no pick rows; listing display restored if hold existed
- [ ] Cancel at `processing` with picks → all holds released; picks deleted; status `cancelled`
- [ ] Cancel at `ready_for_pickup` with draft/issued invoice → invoice cleaned; stock released
- [ ] Cancel blocked at `shipped` / `delivered`
- [ ] All-unavailable banner → Cancel enabled; Ready for pickup disabled
- [ ] Detail pages show button; list page does not rely on hard delete for in-flight orders
