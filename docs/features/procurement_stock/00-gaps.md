# Procurement & stock — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| PS1 | doc_wrong | ACs were empty checkboxes | Shipment + warehouse shipped | **Done in docs (2026-10):** [01-prd](01-prd.md) is target vs live. Tick in code when a US ships. |
| PS2 | not_built | Archive hub + row Archive | Confirm list vs PRD toolbar | If UI differs, implement or change PRD |
| PS3 | doc_wrong | Four shipment **statuses** | Progress tags / flows exist besides status | Status stays 4 values; tags are not statuses ([01-prd](01-prd.md) US-1) |
| PS4 | ~~not_built~~ | Delivery paper picks without vendor PO | Done (2026-09) | — |
| PS5 | ~~not_built~~ | Batch Code Analyze | Shipped (2026-09) | Optional / independent ([01-prd](01-prd.md) US-6) |
| PS6 | ~~not_built~~ | Delivery paper close: dropdown take / condition / return → take bill, condition bill, restock | Packed header filter + `close_preorder_demand_document` | **Done (2026-10).** [SI19](../bills_pays/00-gaps.md). |
| PS7 | partial | Outcomes post stock; lots `outcome_id`; incremental Post; **Record vendor credit** when `received` ([01](01-prd.md)) | Shipped: post, credit table + RPC, dialog | Profit/AP consume credits ([PS8](00-gaps.md)); close guard ([PS10](00-gaps.md)) |
| PS8 | partial | Local costs + optional `section_id`; profit minus sum; not in landed. Vendor cheaper: credit on **sold** qty now; on-hand restamp waits until sell ([01 cases](01-prd.md#receive-vs-warehouse-vs-vendor-price-target)) | Table + **Local costs** tab in settings drawer; profit RPC not wired | Profit RPC: do not book full vendor credit while qty still on shelf |
| PS9 | not_built | **Retire** `global_stock_allocations` (no child quota UI) | Shop listings/cart/orders + invoice + procurement RPCs still use the table | Wean to `global_stock_id`, then drop table. Do not drop while FKs live. |
| PS10 | not_built | Close button + `is_closed`; shipment UI read-only | Column `global_shipments.is_closed` (`20271001150000`); no close RPC/UI guard yet | `costs_locked` / archive unchanged |
| PS11 | ~~design~~ | Leftover vs ordered (e.g. 100 − 92 − 5) | Receive blocked until every line’s land-split qty = ordered | **Do not auto-fill.** Staff must add Missing/damaged for leftover. Stock posts only extra (non-ordered) rows. |
| PS12 | partial | Cost entries = record only (no settle/pay in procurement UI) | Columns `settled_at`, `settlement_ledger_id` | Ignore settle columns; AP bills sync via [WA15](../bills_pays/00-gaps.md) |
| PS16 | ~~doc_wrong~~ | Demand/Delivery paper in `02` + `04` + expanded US-4 | Data model only in RPC matrix | **Done (2026-10):** [02 §1b ERD](02-data-model.md#1b-demand--delivery-paper-erd), [01 US-4](01-prd.md), [04-tdd](04-tdd.md) |
| PS17 | ~~partial~~ | Location kinds: warehouse → zone → shelf → level → bin (+ returns root) | Was shelf → slot → box in SQL/UI | **Done (2026-10):** migration `20271004120000`, [02 §1 locations](02-data-model.md#1-inbound--warehouse-stock-locations) |
