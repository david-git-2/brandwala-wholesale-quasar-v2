# Procurement & stock — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| PS1 | doc_wrong | `01-prd` ACs all `[ ]` | Shipment + warehouse shipped; SQL **split** | Tick ACs that match; keep only real misses |
| PS2 | not_built | Archive hub + row Archive (PRD US) | Confirm list vs PRD toolbar | If UI differs, implement or change PRD |
| PS3 | doc_wrong | PRD "4 states: draft, in_transit, received, cancelled" | Live enum may have more progress stages | Align PRD with `01_types.sql` |
| PS4 | ~~not_built~~ | Fulfill picks without vendor PO on Demand | ~~`delivered_quantity <= placed_quantity` blocked stock-only path~~ | **Done (2026-09):** picks cap at confirmed need; mark-ready backlog from picks |
| PS5 | ~~not_built~~ | `01-prd` US-6 Batch Code Analyze | List, details grid, shipment entry, procurement More hub | Shipped (2026-09) |
