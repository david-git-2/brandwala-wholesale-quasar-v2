# Procurement & Stock — API Contract & RPC Signatures

> **RPC Functions Target**: `supabase/schemas/procurement/03_rpcs.sql`  
> **Security Level**: `SECURITY DEFINER` with staff membership check

---

## 1. List / Search RPC: `list_global_shipments_paginated`

Consolidated single RPC to retrieve active or archived shipments, embedding vendor, cargo, progress tag info, and archived totals in a single network roundtrip.

### Signature
```sql
create or replace function public.list_global_shipments_paginated(
  p_tenant_id uuid,
  p_is_archived boolean default false,
  p_search text default null,
  p_status public.global_shipment_status default null,
  p_vendor_id uuid default null,
  p_limit int default 25,
  p_offset int default 0
)
returns table (
  id uuid,
  shipment_no text,
  status public.global_shipment_status,
  vendor_id uuid,
  vendor_name text,
  vendor_code text,
  cargo_company_name text,
  progress_tag_name text,
  progress_tag_color text,
  costs_locked boolean,
  is_archived boolean,
  total_weight_kg numeric,
  landed_cost_total_bdt numeric,
  items_count bigint,
  created_at timestamptz,
  total_count bigint,
  archived_total bigint
)
language plpgsql security definer;
```

---

## 1b. Warehouse stock cursor: `list_global_stocks_cursor`

Infinite scroll on **Warehouse stock**. Order: `global_stocks.id desc`. Pass `p_cursor_id` from prior page `meta.next_cursor.id`. First request only: `p_include_total true` (optional count for empty state; no count on later pages).

**Shared filters** (also used by `list_global_stocks_groups` and aligned with `list_global_stocks_paginated` where noted):

| Arg | Notes |
| :--- | :--- |
| `p_search` | Item name, product code, barcode, shipment name |
| `p_shipment_id` | Shipment FK |
| `p_shipment_status` | `global_shipments.status` |
| `p_availability` | `stock_availability` |
| `p_grade_tag_id` | Warehouse grade tag |
| `p_location_id` | Stock row location matches this node **or any descendant** in `stock_locations` |
| `p_hide_zero_stock` | Default true |
| `p_is_sellable` | Legacy boolean; prefer `p_availability` in UI |
| `p_stock_type_id` | Optional type filter |

**Group slice** (optional): `p_group_by` + `p_group_key` — when both set, only lots in that group. `p_group_by`: `shipment` \| `product` \| `location` \| `grade` \| `availability`. Product key: `trim(product_code)` or `si:{shipment_item_id}`.

Returns `jsonb`: `{ data: GlobalStockRow[], meta: { has_more, next_cursor: { id } | null, total: number | null } }`.

### 1c. Warehouse stock groups: `list_global_stocks_groups`

Group headers for **Warehouse stock** with server `sum(quantity)` and `count(*)` per group. Same filter args as §1b (no cursor). `p_group_by` required (`shipment` \| `product` \| `location` \| `grade` \| `availability`). `p_limit` / `p_offset` paginate groups (default limit 50).

Returns `jsonb`: `{ groups: [{ key, label, quantity, lot_count }], meta: { total, has_more } }`. Expand a group → `list_global_stocks_cursor` with matching `p_group_by` + `p_group_key`.

---

## 2. Post stock: `post_shipment_outcome_stock` (live)

Stamps line + extra outcome costs, posts **delta** sellable extras to lots (`outcome_id` grain). Repeatable after `stock_ready`. `finalize_global_shipment` delegates here.

**Payload:** `{ "outcome_id": 1, "location_id": null }` or `{ "shipment_item_id": 1, "location_id": 2 }` per bin override. Omit array → default put-away for all unposted sellable extras.

**Rules:** `reason <> ordered`; unsellable → no lot; qty down below on-hand → `restamp_global_shipment_on_hand` aborts; cargo unchanged.

## 2a. Vendor credit: `apply_shipment_outcome_vendor_discount` + `list_shipment_outcome_vendor_credits` (live)

When shipment is **`received`**, staff use **Record vendor credit** on line items. Financial record only — **no** outcome peel, **no** stock lot moves, **no** landed restamp.

**Table:** `global_shipment_outcome_vendor_credits` (qty, previous/new purchase price, `credit_amount`, links to shipment / item / outcome).

**Apply args:** `p_shipment_id`, `p_source_outcome_id`, `p_quantity`, `p_new_purchase_price`

**Guards:** `received`; not cancelled / not `is_closed`; source extra sellable, `reason <> ordered`; `1 <= p_quantity <=` split qty.

**Returns:** `{ mode: 'record', id, credit_amount, ... }`

**List:** `list_shipment_outcome_vendor_credits(p_shipment_id)` → jsonb array (newest first).

**Delete:** `delete_shipment_outcome_vendor_credit(p_credit_id)` — same shipment guards as apply; removes the financial row only.

Cargo/duty and land splits unchanged. Shipment profit / AP may consume credits later ([PS8](00-gaps.md)).

## 2b. Legacy alias: `finalize_global_shipment`

Same as `post_shipment_outcome_stock`.

---

## 2b. Local costs (target, [US-8](01-prd.md) / [PS8](00-gaps.md))

Procurement only. Does **not** call `stamp_global_shipment_landed_costs`.

| Op | Intent |
| :--- | :--- |
| List by `shipment_id` | Rows for the shipment |
| Upsert row | `description`, `amount`, `currency_id` (null → shipment cost currency) |
| Delete row | Staff remove one cost |
| Profit | Subtract sum from shipment GP (treasury P&L when that report is next edited) |

---

## 3. Books Lock RPC: `lock_global_shipment_costs`

Freezes landed cost calculations, preventing any further edits to line prices, weight entries, or freight charges.

### Signature
```sql
create or replace function public.lock_global_shipment_costs(
  p_shipment_id uuid
)
returns jsonb
language plpgsql security definer;
```

---

## 4. Archiving Governance RPCs

### 4.1 Archive Shipment: `archive_shipment`
```sql
create or replace function public.archive_shipment(
  p_shipment_id uuid
)
returns jsonb
language plpgsql security definer;
```

### 4.2 Unarchive / Restore: `unarchive_shipment`
```sql
create or replace function public.unarchive_shipment(
  p_shipment_id uuid
)
returns jsonb
language plpgsql security definer;
```

### 4.3 Permanent Purge (Draft/Cancelled Only): `purge_archived_shipment`
```sql
create or replace function public.purge_archived_shipment(
  p_shipment_id uuid
)
returns jsonb
language plpgsql security definer;
```
*(Fails with error `CANNOT_PURGE_COMMITTED_SHIPMENT` if status is `in_transit` or `received`).*

---

## 5. Pre-order demand RPCs

**Table:** `preorder_demand` — one row per `shop_order_item` or `pbc_costing_item`. **Groups:** `document_type` + `document_id` in list RPCs. ERD: [02-data-model §1b](02-data-model.md#1b-demand--fulfill-erd).

**Helper:** `get_procurement_demand_open_qty(p_source_type, p_source_id)` — confirmed need still open for picks / placement caps.

### 5.1 `upsert_preorder_demand`

Updates vendor PO (`placed_quantity`), warehouse picks (`stock_picks` → `delivered_quantity`), or both.

- `placed_quantity` = vendor PO qty (Demand desk). May be 0.
- `delivered_quantity` / picks = warehouse allocation (Delivery paper desk). Capped at confirmed need (`get_procurement_demand_open_qty.open_qty`), **not** placed qty.

### 5.1b `fill_preorder_demand_placed_quantities_for_document`

Sets `placed_quantity` on **every** demand line for one document group (`p_document_type` + `p_document_id`) to that line’s need qty (same rules as item list). Document must be `procuring`. Existing `vendor_id`, picks, and delivered qty on conflict are unchanged. Returns `{ updated_count }`.

### 5.1d `fill_preorder_demand_oldest_stock_for_document`

FIFO warehouse picks for **every line** on one document (`p_document_type` + `p_document_id`). Document must be `procuring` or `packed`. For each line with `product_id` and need qty &gt; 0: skip if picks already exist; skip if pickable ATP (minus existing `preorder_demand` picks and picks assigned earlier in this run) cannot cover the **full** need; otherwise write `stock_picks` and `delivered_quantity`. Returns `{ updated_count, skipped_count }`.

### 5.1c `set_preorder_demand_vendor_for_document`

Sets `vendor_id` on **every** demand line for one document (`p_document_type` + `p_document_id` + `p_vendor_id`). Document must be `procuring`. Does not change `placed_quantity`, picks, or delivered qty on existing rows. Returns `{ updated_count, vendor_id }`.

### 5.2 `create_invoice_from_preorder_demand_document`

**Live today:** builds proforma (`issue: false`) from stock picks. Document must be `packed`. Idempotent if a linked invoice exists.

**Target:** this desk **is** the delivery paper. Close writes take / condition / return; then take and/or condition bills. See [01-prd US-4](01-prd.md) and [bills_pays US-5](../bills_pays/01-prd.md). Gap [PS6](00-gaps.md).

### 5.2b `sync_invoice_from_preorder_demand_document`

Rebuilds bill lines on an existing linked invoice from current `preorder_demand.stock_picks`. Document must be `packed` and have `invoice_id`. Invoice must be `draft` or `proforma_generated`. Replaces all invoice lines with pick-derived lines (same sell prices as create).

### 5.3 `list_procurement_demand_groups`

Paginated **group headers** only (no nested `items`). Each group includes `document_name` (PBC file name or shop order title), `item_count`, `unallocated_item_count` (lines where `quantity > delivered_quantity`), `invoice_id`, `invoice_status`, and `invoice_stale` (picks differ from linked bill lines).

### 5.4 `list_procurement_demand_group_items`

Cursor-paginated lines for one group (`p_document_type`, `p_document_id`). Keyset on `source_id` (`p_cursor_source_id`). Response: `items` (same shape as former nested group items) + `meta.has_more` + `meta.next_cursor: { source_id }`.

Line fields include `barcode`, `product_code`, `vendor_code`, `market_code`, `brand`, `category`, `available_units`, `languages`, `country_of_origin`, `product_id`, qty/placement fields, and `stock_picks`. `remaining_to_deliver` = `greatest(quantity - delivered_quantity, 0)`. Catalog meta (`available_units`, `languages`, `country_of_origin`) comes from `products`.

### 5.5 `list_procurement_fulfill_groups`

Delivery paper desk group headers. Same JSON shape as `list_procurement_demand_groups`, but **no** `p_child_tenant_id`. Default `p_procurement_status` = `procuring` (also accepts `packed`, `delivered`). RPC name stays `list_procurement_fulfill_groups`.

### 5.6 `list_procurement_fulfill_group_items`

Delivery paper desk lines for one expanded group. Same request/response contract as `list_procurement_demand_group_items` (implementation delegates to that RPC). RPC name stays `list_procurement_fulfill_group_items`.

---

## 6. Stock Movement RPC: `create_and_post_stock_movement`

```sql
create or replace function public.create_and_post_stock_movement(
  p_tenant_id uuid,
  p_stock_id uuid,
  p_movement_type public.stock_movement_type,
  p_quantity numeric,
  p_to_location_id uuid default null,
  p_to_availability public.stock_availability default null,
  p_notes text default null
)
returns jsonb
language plpgsql security definer;
```

---

## 7. Batch Code Analyze

Client CRUD on `batch_code_lists` / `batch_code_items` under RLS. Bulk paste uses one RPC.

| Action | Operation |
| :--- | :--- |
| Open page | Select list by `shipment_id`; if none, insert list (`parent_tenant_id`, `shipment_id`) |
| Add line dialog | Insert one `batch_code_items` row by `list_id` |
| Grid cell blur | Update / delete `batch_code_items` by `list_id` |
| Grid **Arrived** checkbox | Update `is_arrived` on `batch_code_items` (not part of paste/CSV payload) |
| Paste grid / column | `paste_batch_code_items(p_list_id, p_start_row_index, p_rows jsonb)` — creates missing rows, merges fields, default expire server-side; **does not** change `is_arrived` |
| Import CSV dialog | Parse client-side; append with `paste_batch_code_items` at `p_start_row_index = current line count` |
| Shipment line batch dialog — add missing | Ensure `batch_code_lists` by `shipment_id`; insert `batch_code_items` with line barcode/product code |
| Default expire | RPC + client: if mfg set and expire empty, expire = mfg + 36 calendar months |

---

## 8. Shipment sections (line-item tabs)

Table: `global_shipment_sections`. See [02-data-model §3c](02-data-model.md#3c-global_shipment_sections-shipment-line-item-tabs).

| Action | Operation |
| :--- | :--- |
| Create draft shipment | `create_shipment_draft` also inserts **Section 1** for the new `global_shipments` row |
| Load line-items page | `get_shipment_overview_details(p_shipment_id)` → JSON `sections` + `items` (and boxes, cost entries, flow stages) |
| List / add / update / delete tab | Direct `global_shipment_sections` CRUD via client (`shipmentSectionRepository`) under RLS |
| Reorder tabs after drag | `reorder_shipment_sections(p_shipment_id, p_section_ids bigint[])` — sets `sort_order` 0…n−1 |
| Add line to active tab | Item RPCs / inserts accept optional `section_id` on `global_shipment_items` |
| Scoped landed cost row | Optional `section_id` on `global_shipment_cost_entries` |
| Scoped local cost row | Optional `section_id` on `global_shipment_local_costs` ([PS8](00-gaps.md)) |
