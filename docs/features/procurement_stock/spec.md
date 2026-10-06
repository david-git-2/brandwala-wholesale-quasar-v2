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
| ERD / columns | `/dev/document` → **Schema** → Procurement |
| Tables, types, RLS, RPCs | `supabase/schemas/procurement/` — grep `03_rpcs.sql` for bodies |
| Pages / wiring | `web/src/modules/procurement_stock/pages/` + grep `procurementStockQueryKeys` |

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
- Four statuses; sections + cost entries (`section_id` optional). Record only — `sync_shipment_ap_bills` after save ([WA15](../bills_pays/00-gaps.md)).

### US-7 Outcomes + stock
- `global_shipment_item_outcomes`; lots FK `outcome_id`. Restamp on-hand only when vendor price drops.

### US-2 Receive → stock
- Post from sellable extras; guard land qty = ordered per line.

### US-8 Local costs
- Subtract from shipment profit; not in unit stamp.

### US-9 Close
- `is_closed` → read-only shipment UI ([PS10](00-gaps.md)).

### US-3 Warehouse
- Bins leaf; tree warehouse → zone → shelf → level → bin (+ returns root). `list_global_stocks_groups` for grouped list.

### US-4 Demand & Delivery paper
- Routes: `procurement/demand`, `procurement/fulfill` (`preorder_demand`). Sources: shop order + PBC lines. **Packed** close: take / condition / return → bills via `close_preorder_demand_document` ([PS6](00-gaps.md) done). Not dropship desk ([shop_order](../shop_order/spec.md) US-3).

### US-5 Archive / US-6 Batch code
- List archive; optional batch analyze per shipment.
- **Archive** hides shipment and related `global_stocks` from operational views (`archive_shipment` / `unarchive_shipment`).
- **Purge** (`purge_archived_shipment`): only when `is_archived`; any status; deletes shipment and cascaded stock. Bill lines and similar FKs use `ON DELETE SET NULL` on `global_stock_id` so issued invoices keep line snapshots.

## Allocations (retire)

Drop `global_stock_allocations` after shop/invoice use `global_stock_id` only ([PS9](00-gaps.md)).
