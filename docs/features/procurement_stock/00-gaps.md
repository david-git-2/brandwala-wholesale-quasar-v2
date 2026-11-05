# Procurement & stock — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| PS2 | not_built | Archive hub + row Archive | Confirm list vs spec toolbar | If UI differs, implement or change spec |
| PS3 | doc_wrong | Four shipment **statuses** | Progress tags / flows exist besides status | Status stays 4 values; tags are not statuses ([spec](spec.md)) |
| PS7 | partial | Outcomes post stock; lots `outcome_id`; incremental Post; **Record vendor credit** when `received` ([spec](spec.md)) | Shipped: post, credit table + RPC, dialog | Profit/AP consume credits ([PS8](00-gaps.md)); close guard ([PS10](00-gaps.md)) |
| PS8 | partial | Non-capitalizable cost rows + optional `section_id`; profit minus sum; vendor credit timing ([spec](spec.md)) | Bucket/component columns + **Local costs** tab (`cost_type = local`); profit RPC not wired | Subtract `is_capitalizable = false` in profit RPC; do not book full vendor credit while qty still on shelf |
| PS9 | not_built | **Retire** `global_stock_allocations` | Shop/invoice/procurement RPCs still use table | Wean to `global_stock_id`, then drop |
| PS10 | not_built | Close button + `is_closed`; shipment UI read-only | Column exists; no close RPC/UI guard yet | `costs_locked` / archive unchanged |
| PS12 | ~~partial~~ | Cost entries = record only; AP on bucket bills | **Done (2026-10):** settle columns dropped; `pay_settle_shipment_costs` stub; FX from AP pays ([WA15](../bills_pays/00-gaps.md)) |
| PS13 | partial | Unit stamp = capitalizable rows, split per [spec US-1](spec.md) | `stamp_global_shipment_landed_costs` / `calculate_landed_unit_cost` use only material + freight + blended FX | Add customs/handling/finance/other BDT pools; section-scoped rows; UI `calculateLineLandedCostBdt` same formula |
| PS14 | not_built | AP sync: one bill per bucket **× currency** ([spec US-1](spec.md), [WA15](../bills_pays/00-gaps.md)) | One AP bill per bucket; multi-currency bucket → mixed invoice | Same as WA15 SQL/UI; shipment summary copy (“one bill per bucket”) |
| PS15 | design | Customer delivery / FO entity (trips) | Header + `stock_picks` JSON only | target: [preorder-fulfillment-flow Ch 4–6 § G1](../../preorder-fulfillment-flow.md) |
| PS16 | design | Mark delivered guards open picks / bills | `staff_set_catalog_delivered_qty` whole order | target: [Ch 8 § G2](../../preorder-fulfillment-flow.md) |
| PS17 | design | Partially delivered header / customer state | `procuring` \| `packed` \| `delivered` only | target: [Ch 8–9 § G3](../../preorder-fulfillment-flow.md) |
| PS18 | design | Rename or split allocated vs customer-delivered qty | `preorder_demand.delivered_quantity` = pick sum | target: [App B § G4](../../preorder-fulfillment-flow.md) |
| PS19 | design | Delivered queue on Delivery paper UI | RPC `delivered`; fulfill tabs procuring+packed only | target: [Ch 8 § G5](../../preorder-fulfillment-flow.md) |
| PS29 | doc_wrong | Delivery paper **v2** outcome close is **paper-scoped** (`apply_delivery_paper_outcome`; column qty + grade on reject) | Shipped on detail page; fulfill desk still **document** `close_preorder_demand_document` | Align [preorder-fulfillment-flow](../../preorder-fulfillment-flow.md) / PS19 if it reads doc-only for DP |
| PS20 | design | Promise date / ATP on backorder | Demand bucket + PBC backlog; no dates | target: [Ch 2 § G6](../../preorder-fulfillment-flow.md) |
| PS21 | partial | Short-pick / WMS exception on Delivery paper | RPC + table shipped ([PS32](00-gaps.md)); pick UI only | FE short-pick on delivery paper detail |
| PS22 | design | Partial line cancel after partial close | No flow in catalog/PBC close path | target: [Ch 8.2 § G8](../../preorder-fulfillment-flow.md) |
| PS23 | design | Partial customer pay (no installment schedule) | Bills support `partially_paid`; no plan entity | target: [Ch 9 § G9](../../preorder-fulfillment-flow.md) |
| PS24 | design | Trace picked stock to inbound shipment | No FK on delivery line | target: [Ch 3.4 / App B § G10](../../preorder-fulfillment-flow.md) |
| PS25 | design | Condition consignment at customer | Condition bill at close only | target: [Ch 10 § G11](../../preorder-fulfillment-flow.md) |
| PS26 | design | Same-trip door return + invoice for accepted | Return → sellable in as-built | target: [Ch 7 § G12](../../preorder-fulfillment-flow.md) |
| PS27 | design | Customer notification per delivery trip | Order-level notify only | target: [Ch 6–7 § G13](../../preorder-fulfillment-flow.md) |
| PS28 | design | Investor profit visible in fulfillment story | `shipment_investments` on inbound only | target: [Ch 3.5 § G14](../../preorder-fulfillment-flow.md) · [investor_capital spec](../investor_capital/spec.md) |
| PS30 | partial | Cycle count UI + blind / location-scoped workflows | RPCs `create_stock_physical_count` … `approve_stock_physical_count` | Warehouse count pages; optional `receive_rollback` RPC |
| PS31 | partial | Dispatch stock-out + COGS snapshot on trip line | **`dispatch_delivery_paper`** + line `unit_cost_landed_snapshot`; idempotent bill commit | **Done (2026-11):** RPCs shipped; FE dispatch button pending |
| PS32 | partial | Short-pick exception on delivery paper | `record_delivery_paper_short_pick` + `delivery_paper_pick_exceptions` | FE short-pick dialog ([PS21](00-gaps.md) backend done) |
| PS33 | ~~partial~~ | RTV uses `vendor_return` movement type | **Done:** `post_stock_movement` + `return_shipment_to_vendor` | — |
| PS34 | doc_wrong | Inbound QC as separate WMS module | QC = shipment extras + `post_shipment_outcome_stock` | [stock-spine Tier 2](../../kernel/stock-spine.md) |
| PS35 | design | `customer_deliveries` entity vs delivery paper | Paper is as-built trip; no `customer_deliveries` table | target: [PS15](00-gaps.md) · rename docs only |
