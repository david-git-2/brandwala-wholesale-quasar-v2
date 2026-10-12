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
