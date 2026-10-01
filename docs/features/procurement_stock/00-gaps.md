# Procurement & stock — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| PS1 | doc_wrong | ACs were empty checkboxes | Shipment + warehouse shipped | **Done in docs (2026-10):** [01-prd](01-prd.md) is target vs live. Tick in code when a US ships. |
| PS2 | not_built | Archive hub + row Archive | Confirm list vs PRD toolbar | If UI differs, implement or change PRD |
| PS3 | doc_wrong | Four shipment **statuses** | Progress tags / flows exist besides status | Status stays 4 values; tags are not statuses ([01-prd](01-prd.md) US-1) |
| PS4 | ~~not_built~~ | Fulfill picks without vendor PO | Done (2026-09) | — |
| PS5 | ~~not_built~~ | Batch Code Analyze | Shipped (2026-09) | Optional / independent ([01-prd](01-prd.md) US-6) |
| PS6 | not_built | Fulfill pack → delivery paper; take + condition bills | Create invoice / one proforma from picks | [SI19](../bills_pays/00-gaps.md) |
| PS7 | not_built | Outcomes: `general` snapshot + extra rows; kind sellable/unsellable; lots `outcome_id` | Qty/price on the line; lots `shipment_item_id` | [US-7](01-prd.md). Paste → general/sellable. Extra rows post stock. No sum-to-ordered. |
| PS8 | not_built | Local costs + optional `section_id`; profit minus sum; not in landed | No table | `global_shipment_local_costs` |
| PS9 | not_built | **Retire** `global_stock_allocations` (no child quota UI) | Shop listings/cart/orders + invoice + procurement RPCs still use the table | Wean to `global_stock_id`, then drop table. Do not drop while FKs live. |
| PS10 | not_built | Close button + `is_closed`; shipment UI read-only | `costs_locked` / archive only | Flag + guard writes |
| PS11 | design | Leftover vs general (e.g. 100 − 92 − 5) | n/a | **Do not auto-fill.** Staff add a missing/unsellable row if they want it on the book. Stock posts only extra rows. |
| PS12 | not_built | Cost entries = record only (no settle/pay) | Columns `settled_at`, `settlement_ledger_id` | Ignore in UI; do not build pay-from-entry in this module |
| PS16 | ~~doc_wrong~~ | Demand/Fulfill in `02` + `04` + expanded US-4 | Data model only in RPC matrix | **Done (2026-10):** [02 §1b ERD](02-data-model.md#1b-demand--fulfill-erd), [01 US-4](01-prd.md), [04-tdd](04-tdd.md) |
