# Procurement & stock — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| PS2 | not_built | Archive hub + row Archive | Confirm list vs spec toolbar | If UI differs, implement or change spec |
| PS3 | doc_wrong | Four shipment **statuses** | Progress tags / flows exist besides status | Status stays 4 values; tags are not statuses ([spec](spec.md)) |
| PS7 | partial | Outcomes post stock; lots `outcome_id`; incremental Post; **Record vendor credit** when `received` ([spec](spec.md)) | Shipped: post, credit table + RPC, dialog | Profit/AP consume credits ([PS8](00-gaps.md)); close guard ([PS10](00-gaps.md)) |
| PS8 | partial | Local costs + optional `section_id`; profit minus sum; vendor credit timing ([spec](spec.md)) | Table + **Local costs** tab; profit RPC not wired | Do not book full vendor credit while qty still on shelf |
| PS9 | not_built | **Retire** `global_stock_allocations` | Shop/invoice/procurement RPCs still use table | Wean to `global_stock_id`, then drop |
| PS10 | not_built | Close button + `is_closed`; shipment UI read-only | Column exists; no close RPC/UI guard yet | `costs_locked` / archive unchanged |
| PS12 | partial | Cost entries = record only | Columns `settled_at`, `settlement_ledger_id` | Ignore settle columns; AP via [WA15](../bills_pays/00-gaps.md) |
