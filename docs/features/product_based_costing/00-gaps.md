# Product-based costing (pre-order) — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| PBC1 | ~~not_built~~ | Demand desk: `procuring` → `packed` (no invoice at pack) | `staff_mark_pbc_packed` + Delivery paper close_action | **Done (2026-10):** packed is status only; close on Delivery paper |
| PBC2 | not_built | Auto backlog on `delivered` unfulfilled qty | Composable `usePbcBacklog` exists | Verify auto-insert vs manual; tick or implement |
| PBC3 | sql_split | PBC tables | `public.sql` | Split later |
