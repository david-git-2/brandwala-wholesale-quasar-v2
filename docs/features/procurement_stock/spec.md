# Procurement & Stock — spec

## As-built

| | |
| :--- | :--- |
| Spec | `docs/features/procurement_stock/spec.md` |
| UI | `web/src/modules/procurement_stock/`, `vendor/` |
| SQL | **Split** `supabase/schemas/procurement/` |
| State | Mix of Pinia and Vue Query — copy neighbors |
| Model | **BW** warehouse. [business-models](../../architecture/business-models.md). |
| Access | `app`; company owns stock |

## Where to look

| Need | Path |
| :--- | :--- |
| **Stock spine** (Tier 1/2 warehouse actions, RPC index, dispatch vs issue) | [stock-spine.md](stock-spine.md) |
| Inbound ↔ money kernel | Below **Inbound ↔ money**; AP shape [bills § Shipment cost AP](../bills/spec.md#shipment-cost-ap); see bills_pays desks + money bridge spec |
| ERD / columns | `/dev/document` → **Schema** → Procurement |
| Tables, types, RLS, RPCs | `supabase/schemas/procurement/` — grep `03_rpcs.sql` for bodies |
| Pages / wiring | `web/src/modules/procurement_stock/pages/` + grep `procurementStockQueryKeys` |

## Scope

| | |
| :--- | :--- |
| Surfaces | `app` only |
| In | Shipments, sections, landed + **local costs**, bins, `global_stocks`, movements, vendors, outcomes, close, **Demand buy** (`preorder_demand`) |
| Out | Shop/Koba/thrift/PBC formulas; invoice issue; cost entries ≠ wallet pay. Retire allocations (PS9). Shelf damage = **movement**, not new inbound general row. |

## Inbound ↔ money

Procurement never DMLs kernel tables. Wrappers: `supabase/schemas/bills_pays/07_shipment_money_wrappers.sql`. Product: [bridge § Atlas](../money_bill_bridge/spec.md#atlas).

| Job | RPC / layer |
| :--- | :--- |
| Sync / issue AP drafts | `sync_shipment_ap_bills`, `issue_shipment_ap_bills` |
| Costs tab draft CRUD | `create_shipment_ap_bill_v2`, `update_shipment_ap_bill_v2`, `void_shipment_ap_bill_v2` |
| Read balances + AP list | `get_shipment_money_kernel_bundle` |
| Pay vendor on shipment | `post_shipment_ap_money_out` (via `apPayoutService`) |
| Bill shape / `source_*` | [bills § Shipment cost AP](../bills/spec.md#shipment-cost-ap) |
| Web entry | `shipmentMoneyKernelRepository`, `globalShipmentStore.loadSettingsFinanceBundle` |
| Header save → AP sync | `sync_shipment_ap_bills` only when header touches payee/cost fields or `status = cancelled`; workflow-only `draft` / `in_transit` status PATCH does not sync |
| Costs AP tenant | `money_kernel.bills.tenant_id` = workspace header (`current_tenant_id` / `x-selected-tenant-id`); shipment must match that tenant; `rpc_get_bill(p_tenant_id, …)` is SECURITY DEFINER + membership check (kernel RLS still keys on JWT `tenant_id`) |
| Cutover gaps | bills_pays desks (see money bridge atlas) WA15, BP8, BP9 |

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

**Staff path:** ordered paste → optional `in_transit` → land splits (Case A) → `post_shipment_outcome_stock` → vendor credit when `received` (C–E) → warehouse movement (B) → close. Live partial: PS7.

## Kind and reason

| Field | Values |
| :--- | :--- |
| **kind** | `sellable` \| `unsellable` |
| **reason** | `ordered` \| `general` \| `vendor_discount` \| `missing` \| `damaged` \| `other` |

Lots mirror kind/reason; warehouse grades via tags — do not write splits back onto shipment.

## Cases A–E

| Case | Where | Rule |
| :--- | :--- | :--- |
| **A Land** | Shipment extras | Split at receive; sum land qty = ordered (PS11); post sellable → lots |
| **B Warehouse** | Stock movement | Shelf life after receive; shipment paper unchanged |
| **C–E Vendor credit** | When `received` | `global_shipment_outcome_vendor_credits`; profit timing PS8; AP WA15 |

**Do not:** clone ordered on mark received; auto-fill missing; warehouse damage as new shipment extra; lower extra qty below on-hand without write-off.

## User stories

### US-1 Shipment, sections, landed costs
- Four statuses; sections optional. **International Costs tab = kernel AP bill list** per bucket (`create_shipment_ap_bill_v2`, draft Issue/Edit/Delete; `global_shipments.buckets` index). Lock → `issue_shipment_ap_drafts_v2`. Landed stamp reads capitalizable **bill lines** ([bills spec § Shipment cost AP](../bills/spec.md#shipment-cost-ap)). Local/domestic shipments may still use legacy cost rows until cutover. After a bucket bill is **issued**, money changes go through bills/pays (credit/debit notes), not worksheet edits.
- **AP bills:** one bill per **cost bucket × currency**, not one bill per bucket. Cost lines in the same bucket with different `currency_id` (or shipment default currency) become separate AP bills. Do **not** create a single “mixed currency” invoice for one bucket. Kernel plug: `source_key` = `{bucket}:{currency_code}`; `ap_kind` stays the bucket name for pays and landed-cost ([bridge § Atlas](../money_bill_bridge/spec.md#atlas)).
- Each row is `global_shipment_cost_entries`: **bucket** (`material` \| `freight` \| `customs` \| `handling` \| `finance` \| `other`) × **component** (`subtotal` \| `carriage` \| `vat_tax` \| `misc`), plus `description`, `amount` in the row’s currency, optional `currency_id`, `section_id`, `metadata`.
- **`is_capitalizable`:** `true` → included in landed unit cost (BDT stamp); `false` → shipment P&L / local opex only (fines, refundable VAT, misc tips when not capitalized). No extra VAT leftover rule — leftover on stock only if that row’s flag is on.
- Matrix examples: material+subtotal = goods invoice; freight+subtotal = ocean/air base; customs+`vat_tax` = CD/RD/AIT; handling+`misc` = gate labor; finance+`misc` = SWIFT; other+`misc` = dock tips (cap flag per row). Cash settlement is on bills/pays only (not on cost rows).
- **FX (not stored on `global_shipments`):** from AP **pays** on capitalizable bucket bills (`shipment_ap_bucket_paid_totals` / `_global_shipment_landed_fx_inputs`). **Product rate** = material BDT pool ÷ material foreign paid only. **Freight** = BDT pool ÷ kg basis (`freight_bdt_per_kg`); never stack GBP/kg cargo rate with the freight BDT pool. **All-foreign average** = reporting only — not stamped on SKUs. **Unit landed** = goods + material surplus + freight + customs + handling + finance + other BDT (algorithm order): [shipment-rate-calculations.md](shipment-rate-calculations.md). Pays store allocations in **bill/foreign** units; BDT = books allocation. `post_ap_payout_with_allocations` restamps after pay.
- **Unit stamp:** SKU `purchase_price` × **product rate** + weight share of freight foreign × **cargo FX**. Do **not** convert the whole line at the blended transaction rate. Do **not** run customs/handling/finance/other through the goods+cargo blend.

| Bucket | Split onto SKUs |
| :--- | :--- |
| `material` | Already on the line (`purchase_price`). Header `carriage` on material → add to **goods value**, not kg. |
| `freight` | **Gross kg** (product + package); fallback **qty** if weight is 0. |
| `customs` | **CIF Taka** on the line (goods Taka + freight Taka share). |
| `handling` | **Qty**. |
| `finance` | **Goods Taka**. |
| `other` | **Qty** when capitalized. |

Stamp and FE preview follow [shipment-rate-calculations.md](shipment-rate-calculations.md) (see PS13).

### US-7 Outcomes + stock
- `global_shipment_item_outcomes`; lots FK `outcome_id`. Restamp on-hand only when vendor price drops.

### US-2 Receive → stock
- Post from sellable extras; guard land qty = ordered per line.

### US-8 Local costs
- Rows with `is_capitalizable = false` subtract from shipment profit; they do not affect unit stamp. (Often `other` bucket or customs VAT; not limited to a single legacy `local` type.)

### US-9 Close
- `is_closed` → read-only shipment UI (PS10).

### US-3 Warehouse
- Bins leaf; tree warehouse → zone → shelf → level → bin (+ returns root). `list_global_stocks_groups` for grouped list.

### US-4 Demand buy & catalog delivery
- **Demand buy:** Route `procurement/demand`. Sources: vendor-catalog shop order + PBC lines in **procuring**. List RPC `list_procurement_demand_buy_documents`; detail `get_procurement_demand_buy_document`. Vendor placements on `preorder_demand.vendor_placements`; bulk paste via **`bulk_upsert_preorder_demand_vendor_placements`**. Document-level close remains **`close_preorder_demand_document`** when appropriate. Not dropship desk ([shop_order](../shop_order/spec.md) US-3).
- **Customer delivery (catalog / PBC):** No delivery-paper product surface. Staff bill and stock-issue through the money desk and warehouse flows when ready (no dedicated line-level delivery jsonb).
- **Pick matching (demand buy):** **`ProcurementDemandStockPickDialog`** lists sellable lots via **`search_stock_network`** (product id, then name/barcode). Demand pick save stores **`global_stock_id`** only.

### US-5 Archive / US-6 Batch code
- List archive; optional batch analyze per shipment.
- **Archive** hides shipment and related `global_stocks` from operational views (`archive_shipment` / `unarchive_shipment`).
- **Purge** (`purge_archived_shipment`): only when `is_archived`; any status; deletes shipment and cascaded stock. Bill lines unlink via `shipment_item_id = null` and clearing `line_meta.stock_ref` so issued invoices keep line snapshots; return items still null physical `global_stock_id`.

## Allocations (retire)

Drop `global_stock_allocations` after shop/invoice use `global_stock_id` only (PS9).
