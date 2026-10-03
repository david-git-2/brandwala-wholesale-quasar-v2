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

## Status, flags, staff receive (target)

**Statuses (only four):** `draft` | `in_transit` | `received` | `cancelled`. Progress tags are not statuses.

| Status | Ordered extra | Land extras | Post to stock | Warehouse |
| :--- | :--- | :--- | :--- | :--- |
| `draft` | Paste → `ordered` | Yes (paper only: price, qty, weights) | If extras exist | Lots only if posted |
| `in_transit` | Edit paper + land splits | Yes (paper + splits) | Yes | Same |
| `received` | Paper stays | More extras until close | **Again** (delta) | Movements only |
| `cancelled` | No writes | No | No | Do not invent extras |

**`received` is set by** first **Post to stock** of a sellable extra → `status = received`, `stock_ready = true`. **Not** by cloning ordered into extras. **Mark received** without post is forbidden.

| Flag | Means | Not |
| :--- | :--- | :--- |
| `stock_ready` | ≥1 sellable extra has a lot | All posted; closed |
| `costs_locked` | Stamp frozen | Blocks new extras |
| `is_closed` | Read-only ([US-9](01-prd.md)) | Sold out |

**Staff path:** (1) Paste → `ordered` only. (2) Optional `in_transit`. (3) **Add split** on line items — land only (Case A: general / damaged / missing). (4) **Post to stock** → bin; sellable → lot; unsellable → loss. (5) More land splits / qty → post delta. (6) When **`received`**, **Lower vendor price** on line items (Cases C–E) — not Add split; RPC peels or restamps on-hand. (7) Shelf break → warehouse movement (B). (8) Close.

**Verify (tick in app):** Mark received does not clone ordered; no receive-page qty field; post twice grows stock; unsellable extra → no lot; qty down below on-hand → error; Case B does not edit shipment extras.

Live: extras post via `post_shipment_outcome_stock`; put-away page; Mark received does not clone ordered ([PS7](00-gaps.md) partial).

---

## Kind and reason

| Field | Values | Use |
| :--- | :--- | :--- |
| **kind** | `sellable` \| `unsellable` | Stock or loss. Not warehouse grade. |
| **reason** | `ordered` \| `general` \| `vendor_discount` \| `missing` \| `damaged` \| `other` | Why this row. `other` → `description`. |

`ordered` = paper / pro forma snapshot. `general` = default received split. `short_dated` is **not** a kind (warehouse later). Same words (`sellable` / `unsellable`) on lots; **not** one shared row. Warehouse does **not** write splits back onto the shipment.

**UI labels (staff):** shipment extras — **Stock impact** (`kind`: goes to stock / loss at receive), **Land reason** (`reason`, e.g. Normal = `general`). Warehouse lot — **Received as** (read-only `reason`), **Condition** (`grade_tag`), **Sell status** (`availability`: sellable / on hold / unsellable).

**Warehouse conditions** (`stock_grade` / `warehouse` system tags): Standard, Open box, Box damage, Box less, Badly damaged; plus Short dated, Expired, Product damaged, Stolen / shrinkage, Quarantine, Customer return. Tag `metadata.maps_to_availability` suggests default sell status when re-grading (`held` for short dated / quarantine / customer return).

---

## Cases A–E (plain language)

**One rule:** split **once** when goods land (extras on the shipment). Later shelf life = **warehouse movement**. Same words `sellable` / `unsellable` on lots, but **not** one row edited from both screens. Warehouse does **not** write damaged/missing back onto the shipment.

| Case | Story | Staff | System | Shipment paper | Stock |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **A Land** | Paper 100. Truck: 92 good, 5 broken, 3 missing. | Add **extras** beside ordered (92 general, 5 damaged, **3 missing**). **Post to stock**. | Ordered row stays 100. No auto-fill leftover ([PS11](00-gaps.md)). Receive blocked until split qty = 100. | One inbound split only | Sellable extras → lots; unsellable → loss; ordered never posts |
| **B Warehouse** | Six months later one bottle breaks in the bin. | Grade / write-off on **warehouse** page. | Extra rows unchanged. Status unchanged. | Unchanged | Qty down now; not a new inbound row |
| **C–E Vendor cheaper** | Vendor agrees lower price on N units of a land split. | **Record vendor credit** when `received` (qty ≤ split qty). | Inserts `global_shipment_outcome_vendor_credits` only. **No** stock move, **no** outcome peel, **no** restamp. | Land splits unchanged | Lot cost unchanged; credit for finance / profit ([PS8](00-gaps.md)) |

**Do not**

| Wrong | Why |
| :--- | :--- |
| Mark received → clone ordered qty into a `general` extra | Paper is not landed qty; stock still empty |
| Receive page types a second “received qty” | Fights extras; use Post to stock |
| Auto-fill missing = ordered − sum(extras) | Staff book leftover as Missing/damaged ([PS11](00-gaps.md)) |
| Post to stock while any line’s land-split qty ≠ ordered | Land story incomplete; leftover must be a split |
| Warehouse damage → new shipment `damaged` row | Mixes landing truth with shelf life (Case B) |
| Lower extra qty below qty already in bin without write-off | Error; shrink shelf via movement first |
| Book full vendor credit on shipment profit while goods unsold | Overstates profit ([PS8](00-gaps.md)) |

---

## Receive vs warehouse vs vendor price

Split **once at receive**. Vendor cheaper = credit + restamp **on-hand only**. Cargo/duty never shrink. Not a customer refund. AP/pay later ([WA15](../bills_pays/00-gaps.md)).

**Shipment profit when vendor drops price (target, [PS8](00-gaps.md) — RPC not live).** Example: 100 @ 10, sold 40, 60 in bin, vendor now 8 → total credit **200**.

| Piece | Amount | Count in shipment profit **now**? |
| :--- | :--- | :--- |
| Discount on **sold** 40 | 80 | **Yes** (variance). Those sales stay COGS 10 |
| Discount on **shelf** 60 | 120 | **No** — lower stock value; margin when those 60 sell (COGS 8) |
| All 200 today | — | **Wrong** |
| Cargo / duty / local | — | Cargo unchanged; local costs subtract from profit |

Life of cargo: sales − COGS (40@10 + 60@8) − cargo − duty − local. Same total as “always 8,” honest **timing**.

**Live:** `post_shipment_outcome_stock`; lots `outcome_id`; put-away; warehouse shows inbound `reason`. Profit RPC + close UI still open ([PS8](00-gaps.md), [PS10](00-gaps.md)).

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
- One table `global_shipment_item_outcomes`. Line keeps product, ordered qty (mirrored on the `ordered` outcome), weights, `section_id`.
- First row: qty, **reason `ordered`**, kind `sellable`, purchase price, stamped `cost`. Extra rows: qty, kind, reason (`general` or other), purchase price, stamped `cost`, optional note / batch **text** (no FK). No `stock_id` on the outcome.
- Lots FK **`outcome_id`**. Cargo/duty rows never shrink when vendor price drops.
- Restamp on-hand only. Qty still out/sold: return inbound first, or **stop**.

### US-2 Receive → stock
- Post lots from **sellable** extra outcomes (not `ordered`). Unsellable = loss. Ordered does not create lots.
- Guard: every line with ordered qty &gt; 0 must have land extras (`reason` not `ordered` / not `vendor_discount`) whose qty **sums to ordered**. Block Receive until then. Do not invent leftover rows.

### US-9 Close
- Staff click Close → `is_closed = true`. All shipment screens for that id read-only (lines, outcomes, costs, batch, rates).

### US-5 Archive
- Archive from the list. Purge only `draft` / `cancelled`.

### US-6 Batch code
- Optional. One list per shipment when used. Gear → Batch Code. Independent of paste.

### US-3 Warehouse
- Stock only in **bin** (leaf). Location tree per parent tenant: **warehouse → zone → shelf → level → bin**. Parallel root **returns** uses the same zone → shelf → level → bin chain under it. Location / grade changes → `stock_movements`.
- **Warehouse list:** cursor infinite scroll; filters (location subtree, grade, shipment, sell status); optional **group by** shipment / product / bin / condition / sell status via `list_global_stocks_groups` + grouped row load.

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
