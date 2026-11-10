# Procurement & Stock — spec

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/procurement_stock/spec.md` + [00-gaps](00-gaps.md) |
| UI | `web/src/modules/procurement_stock/`, `vendor/` |
| SQL | **Split** `supabase/schemas/procurement/` |
| State | Mix of Pinia and Vue Query — copy neighbors |
| Model | **BW** warehouse. [business-models](../../architecture/business-models.md). |
| Access | `app`; company owns stock |

## Where to look

| Need | Path |
| :--- | :--- |
| **Stock spine** (Tier 1/2 warehouse actions, RPC index, dispatch vs issue) | [docs/kernel/stock-spine.md](../../kernel/stock-spine.md) |
| Inbound ↔ money kernel (actions, RPCs, gaps) | [money-kernel-wiring.md](money-kernel-wiring.md) |
| ERD / columns | `/dev/document` → **Schema** → Procurement |
| Tables, types, RLS, RPCs | `supabase/schemas/procurement/` — grep `03_rpcs.sql` for bodies |
| Pages / wiring | `web/src/modules/procurement_stock/pages/` + grep `procurementStockQueryKeys` |
| Full pre-order flow (catalog + PBC → delivery paper) | [preorder-fulfillment-flow](../../preorder-fulfillment-flow.md) |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` only |
| In | Shipments, sections, landed + **local costs**, bins, `global_stocks`, movements, vendors, outcomes, close, Demand / **Delivery paper** |
| Out | Shop/Koba/thrift/PBC formulas; invoice issue; cost entries ≠ wallet pay. Retire allocations ([PS9](00-gaps.md)). Shelf damage = **movement**, not new inbound general row. |

## Status, flags, receive

**Statuses:** `draft` \| `in_transit` \| `received` \| `cancelled` (progress tags ≠ status).

| Status | Post to stock | Notes |
| :--- | :--- | :--- |
| `draft` / `in_transit` | Yes when extras exist | Land splits on line items |
| `received` | Delta posts | More extras until close |
| `cancelled` | No | |

`received` = first **Post to stock** of sellable extra (`stock_ready`). Not clone ordered → general. No mark-received without post.

| Flag | Means |
| :--- | :--- |
| `stock_ready` | ≥1 sellable extra has a lot |
| `costs_locked` | Stamp frozen |
| `is_closed` | Read-only ([US-9](#us-9-close)) |

**Staff path:** ordered paste → optional `in_transit` → land splits (Case A) → `post_shipment_outcome_stock` → vendor credit when `received` (C–E) → warehouse movement (B) → close. Live partial: [PS7](00-gaps.md).

## Kind and reason

| Field | Values |
| :--- | :--- |
| **kind** | `sellable` \| `unsellable` |
| **reason** | `ordered` \| `general` \| `vendor_discount` \| `missing` \| `damaged` \| `other` |

Lots mirror kind/reason; warehouse grades via tags — do not write splits back onto shipment.

## Cases A–E

| Case | Where | Rule |
| :--- | :--- | :--- |
| **A Land** | Shipment extras | Split at receive; sum land qty = ordered ([PS11](00-gaps.md)); post sellable → lots |
| **B Warehouse** | Stock movement | Shelf life after receive; shipment paper unchanged |
| **C–E Vendor credit** | When `received` | `global_shipment_outcome_vendor_credits`; profit timing [PS8](00-gaps.md); AP [WA15](../bills_pays/00-gaps.md) |

**Do not:** clone ordered on mark received; auto-fill missing; warehouse damage as new shipment extra; lower extra qty below on-hand without write-off.

## User stories

### US-1 Shipment, sections, landed costs
- Four statuses; sections + cost entries (`section_id` optional). Record only — `sync_shipment_ap_bills` after save ([WA15](../bills_pays/00-gaps.md)). After a bucket bill is **issued**, money changes go through bills/pays (credit/debit notes), not cost-row edits.
- **AP bills:** one bill per **cost bucket × currency**, not one bill per bucket. Cost lines in the same bucket with different `currency_id` (or shipment default currency) become separate AP bills. Do **not** create a single “mixed currency” invoice for one bucket. Kernel plug: `source_key` = `{bucket}:{currency_code}`; `ap_kind` stays the bucket name for pays and landed-cost ([money-spine](../bills_pays/money-spine.md)).
- Each row is `global_shipment_cost_entries`: **bucket** (`material` \| `freight` \| `customs` \| `handling` \| `finance` \| `other`) × **component** (`subtotal` \| `carriage` \| `vat_tax` \| `misc`), plus `description`, `amount` in the row’s currency, optional `currency_id`, `section_id`, `metadata`.
- **`is_capitalizable`:** `true` → included in landed unit cost (BDT stamp); `false` → shipment P&L / local opex only (fines, refundable VAT, misc tips when not capitalized). No extra VAT leftover rule — leftover on stock only if that row’s flag is on.
- Matrix examples: material+subtotal = goods invoice; freight+subtotal = ocean/air base; customs+`vat_tax` = CD/RD/AIT; handling+`misc` = gate labor; finance+`misc` = SWIFT; other+`misc` = dock tips (cap flag per row). Cash settlement is on bills/pays only (not on cost rows).
- **FX (not stored on `global_shipments`):** from AP **pays** on bucket bills `material` and `freight` (`shipment_ap_bucket_paid_totals` / `_global_shipment_landed_fx_inputs`). Product rate = Taka ÷ foreign on material pays. Cargo FX = same on freight pays. Cargo **per kg** = freight foreign ÷ shipment kg. Transaction rate = (material Taka + freight Taka) ÷ (material foreign + freight foreign). FX pays store allocations in **bill/foreign** units; Taka = alloc × `pays.exchange_rate`. `post_ap_payout_with_allocations` restamps landed cost after pay.
- **Unit stamp:** SKU `purchase_price` × **product rate** + weight share of freight foreign × **cargo FX**. Do **not** convert the whole line at the blended transaction rate. Do **not** run customs/handling/finance/other through the goods+cargo blend.

| Bucket | Split onto SKUs |
| :--- | :--- |
| `material` | Already on the line (`purchase_price`). Header `carriage` on material → add to **goods value**, not kg. |
| `freight` | **Gross kg** (product + package); fallback **qty** if weight is 0. |
| `customs` | **CIF Taka** on the line (goods Taka + freight Taka share). |
| `handling` | **Qty**. |
| `finance` | **Goods Taka**. |
| `other` | **Qty** when capitalized. |

Code today stamps only material+freight ([PS13](00-gaps.md)).

### US-7 Outcomes + stock
- `global_shipment_item_outcomes`; lots FK `outcome_id`. Restamp on-hand only when vendor price drops.

### US-2 Receive → stock
- Post from sellable extras; guard land qty = ordered per line.

### US-8 Local costs
- Rows with `is_capitalizable = false` subtract from shipment profit; they do not affect unit stamp. (Often `other` bucket or customs VAT; not limited to a single legacy `local` type.)

### US-9 Close
- `is_closed` → read-only shipment UI ([PS10](00-gaps.md)).

### US-3 Warehouse
- Bins leaf; tree warehouse → zone → shelf → level → bin (+ returns root). `list_global_stocks_groups` for grouped list.

### US-4 Demand & Delivery paper
- Routes: `procurement/demand` (buy), `procurement/fulfill` (delivery paper / picks). Sources: vendor-catalog shop order + PBC lines in **procuring**.
- **Delivery paper (2026-11):** While a catalog order or PBC file is **procuring** (or lines still have quantity to deliver), staff see **Create** + chips (`DP-{id}`) on the order/file page. Chip opens **delivery paper detail** (shop/PBC routes): all document lines, stock picks, qty + take/condition/return splits, top **Save** → `save_delivery_paper_detail` (draft header only; **`delivery_paper_line.splits`** jsonb `[{ quantity, status, invoice_id?, returned_at? }]` per stock lot). Picks live on paper lines only (not mirrored into `preorder_demand.stock_picks` on save).
- **Status edit rules:** **draft** — pick stock only; **packed** / **dispatched** — edit Accepted / Condition / Rejected column qty (Save required); **delivered** / **cancelled** — line/outcome columns read-only; **header status** may still change on **delivered** (not on **cancelled**). From **packed** onward, unpicked lines are hidden.
- **Outcome buttons (packed / dispatched):** **Accept**, **Condition**, **Reject** use the matching **column qty** on each visible row (staff must **Save** unsaved column edits first). FE FIFO-allocates column qty across **packed** lots on each line, then RPC **`apply_delivery_paper_outcome`** (paper-scoped; not `close_preorder_demand_document` on the whole document). **Accept** → draft bill (`take`); **Condition** → draft condition bill; **Reject** → warehouse return via stock movement with **warehouse grade per returned lot** (`grade_tag_id` on each allocation). Accept/condition stamp `invoice_id` on the outcome split in jsonb. **Qty cap:** only **pending** planned outcome qty (column minus already-applied splits with `invoice_id` / `returned_at`) must fit **remaining packed**; applied qty is locked. **Save** (packed/dispatched) writes planned qty on the null-stock planning row; **apply** reconciles that row after each outcome action.
- **Demand buy page** (`ProcurementDemandBuyDesk`): list RPC `list_procurement_demand_buy_documents` (procuring only; `has_under_ordered_lines` / `under_ordered_line_count` computed in SQL). Expand one document → detail RPC `get_procurement_demand_buy_document` (paginated items). **Need** = confirmed qty on shop/PBC line; **vendor orders** = `preorder_demand.vendor_placements` jsonb `[{ vendor_code, quantity }]`. Save via `upsert_preorder_demand(p_vendor_placements)` — **manual Save only**; route / document switch confirms discard if dirty.
- Entering **procuring** still seeds `preorder_demand` per line (`ensure_preorder_demand_for_procuring_document`). **Fulfill desk** still closes at **document** scope via **`close_preorder_demand_document`** (Packed tab). **Delivery paper v2** closes outcomes per paper via **`apply_delivery_paper_outcome`**. Not dropship desk ([shop_order](../shop_order/spec.md) US-3).

### US-5 Archive / US-6 Batch code
- List archive; optional batch analyze per shipment.
- **Archive** hides shipment and related `global_stocks` from operational views (`archive_shipment` / `unarchive_shipment`).
- **Purge** (`purge_archived_shipment`): only when `is_archived`; any status; deletes shipment and cascaded stock. Bill lines unlink via `shipment_item_id = null` and clearing `line_meta.stock_ref` so issued invoices keep line snapshots; return items still null physical `global_stock_id`.

## Allocations (retire)

Drop `global_stock_allocations` after shop/invoice use `global_stock_id` only ([PS9](00-gaps.md)).
