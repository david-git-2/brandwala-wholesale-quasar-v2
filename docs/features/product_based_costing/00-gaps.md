# Product-based costing (pre-order) — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| PBC1 | not_built | Demand desk: `procuring` → invoice at `ready_for_shipment` | PBC files + backlog exist; confirm handoff to procurement demand | User: mark done or list missing status UI |
| PBC2 | not_built | Auto backlog on `delivered` unfulfilled qty | Composable `usePbcBacklog` exists | Verify auto-insert vs manual; tick or implement |
| PBC3 | sql_split | PBC tables | `public.sql` | Split later |
