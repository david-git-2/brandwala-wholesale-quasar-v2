# Procurement & Stock — Product Requirements Document (PRD)

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/procurement_stock/` |
| UI | `web/src/modules/procurement_stock/`, `vendor/` |
| SQL | **Split** `supabase/schemas/procurement/` |
| State | Mix of Pinia and Vue Query — copy neighbors |
| Model | **BW** warehouse. [business models](../../architecture/business-models.md). |
| Access | `app`; company owns stock |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` only |
| In | Shipments, sections, landed cost entries (optional section), **local costs** (optional section, not in unit cost), bins, `global_stocks`, movements, vendors, batch analyze (optional), **receive outcomes**, **close shipment**, Demand / Fulfill / delivery paper |
| Out | Shop cart, Koba, thrift, PBC formulas. Final sales invoice issue. Cost entries are **not** wallet pay/settle. **Child quota allocations** — retire ([PS9](00-gaps.md)). Warehouse damage/expiry after stock is **stock movement**, not a new inbound “general” row. |

---

## Inbound flow (target)

1. Create shipment. **Batch code** list is optional and independent (not required before lines).
2. After pro forma: add / bulk-paste lines (qty, price, product weight, package weight, rough FX on costs). Paste creates the first **outcome**: **kind `sellable`**, **reason `general`**. That row is the record of **what was coming**. It does **not** post stock.
3. After goods land: **add** more outcome rows beside general (received, damaged, missing, …). Do **not** shrink or replace general. Do **not** auto-fill leftover vs general ([PS11](00-gaps.md)).
4. **Stock** comes only from non-general outcomes (or later restamp of those rows): **`sellable` → lot**; **`unsellable` → loss** (no sellable lot). Damaged qty **can** go to stock if that row is sellable.
5. Lock / restamp rates **before or after** stock. Landed rows: goods / cargo / duty. Optional `section_id` (whole shipment if null). Local labor/van/packing: other table, optional section, **not** in landed unit cost.
6. Change kind/reason on those extra rows → restamp **on-hand** lots. Warehouse later damage/expire → **movement / write-off**, not inbound general.
7. Extra batch lines anytime until close. New local costs until close.
8. **Close** is a button + `is_closed`. UI for that shipment becomes **read-only**. Not auto when sold out. No edits after close.

Live today: price/qty on the **line**; finalize from `received_quantity`; no outcomes table; no local-costs table; no `is_closed`; allocations table still in shop/invoice SQL.

---

## Kind and reason

| Field | Values | Use |
| :--- | :--- | :--- |
| **kind** | `sellable` \| `unsellable` | Stock or loss. Not warehouse grade. |
| **reason** | `general` \| `vendor_discount` \| `missing` \| `damaged` \| `other` | Why this row. `other` → `description`. |

`general` = inbound ordered/pro forma snapshot only. `short_dated` is **not** a kind (warehouse later).

---

## User stories

### US-1 Shipment, sections, landed costs
- Create draft, sections (tabs; **All** is UI-only), lines, cost entries (optional `section_id`).
- Cost entries are a **record**. No settlement / ledger pay in this module. Drop `settled_at` from the product story ([PS12](00-gaps.md)).
- Status: `draft` \| `in_transit` \| `received` \| `cancelled`. Progress tags are extra, not extra statuses.
- Stamp landed BDT from FX, weight, duty until `costs_locked` or until **closed**.

### US-8 Local costs
- Many rows: description, amount, currency, optional `section_id`.
- Ignore for stamp / stock value. Subtract from shipment profit.

### US-7 Outcomes + stock
- One table `global_shipment_item_outcomes`. Line keeps product, ordered qty, weights, `section_id`.
- Each extra row: qty, kind, reason, purchase price, stamped `cost`, optional note / batch **text** (no FK). No `stock_id` on the outcome.
- Lots FK **`outcome_id`**. Cargo/duty rows never shrink when vendor price drops.
- Restamp on-hand only. Qty still out/sold: return inbound first, or **stop**.

### US-2 Receive → stock
- Post lots from **sellable** extra outcomes. Unsellable = loss. General does not create lots.

### US-9 Close
- Staff click Close → `is_closed = true`. All shipment screens for that id read-only (lines, outcomes, costs, batch, rates).

### US-5 Archive
- Archive from the list. Purge only `draft` / `cancelled`.

### US-6 Batch code
- Optional. One list per shipment when used. Gear → Batch Code. Independent of paste.

### US-3 Warehouse
- Stock only in **bin**. Location / grade changes → `stock_movements`.

### US-4 Demand & Fulfill (shared desk)

Two **app** routes, one data model (`preorder_demand`). Not a separate module. Not dropship order fulfillment ([shop_order](../shop_order/01-prd.md) US-3).

| Desk | Route | Job |
| :--- | :--- | :--- |
| **Demand** | `/:slug/app/procurement/demand` | See confirmed need. Optional vendor + **placed** qty (PO). Filter by child tenant. |
| **Fulfill** | `/:slug/app/procurement/fulfill` | **Stock picks** from warehouse (`global_stocks`). Mark **ready for shipment**. Pack / bill handoff. |

**Sources (same list):** catalog **shop order** lines (`shop_order_item`) and **PBC** file lines (`pbc_costing_item`) after customer confirm. Pre-order quotes enter via [product_based_costing](../product_based_costing/01-prd.md) → same Demand desk.

**Document status** (on the shop order or PBC file, not on `preorder_demand`): `procuring` → `ready_for_shipment` → `delivered`. Both desks filter by this status tab.

| Field on `preorder_demand` | Demand desk | Fulfill desk |
| :--- | :--- | :--- |
| `vendor_id` | Set per line or bulk for document | Read |
| `placed_quantity` | Vendor PO qty (may be 0 if stock on hand) | Read |
| `stock_picks` / `delivered_quantity` | Read | Write; sum of picks ≤ open need |
| `notes` | Optional | Optional |

**Fulfill → sales:** **Live:** `create_invoice_from_preorder_demand_document` / `sync_…` builds **proforma** from picks when `ready_for_shipment` (not a final take bill). **Target:** **delivery paper** (`held`) + optional proforma; then **take** / **condition** bills — not issue-from-Fulfill ([PS6](00-gaps.md), [bills_pays US-5](../bills_pays/01-prd.md)). Dropship ship+issue stays on the order.

**Out of scope here:** inbound shipment receive, invoice collect, dropship 5-stage desk.

---

## Allocations (retire)

No sister-company quota UI. Target: drop `global_stock_allocations` after shop listings / cart / invoice RPCs use `global_stock_id` only. Live SQL still depends on the table ([PS9](00-gaps.md)).
