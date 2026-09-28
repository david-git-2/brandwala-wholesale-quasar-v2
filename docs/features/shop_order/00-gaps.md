# Shop order & dropship — gaps

Open with [01-prd.md](01-prd.md). Types: `not_built` | `doc_wrong` | `sql_split`. When you ship a row: delete it.

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| SO1 | ~~not_built~~ | Declarative `shop_order/03_rpcs.sql` matched live remittance + payload | ~~Truncated `record_dropship_courier_remittance` / `process_dropship_courier_remittance_uwl`~~ | **Done (2026-09):** `20270929130000_dropship_receipts_wiring.sql` + schema restore |
| SO2 | ~~design~~ | Bank transfer credits wallet from remittance remainder only | ~~`transfer_dropship_reseller_profit` after remittance~~ | **Done (2026-09):** `record_dropship_courier_bank_transfer` stops at remittance |
| SO3 | ~~not_built~~ | Finance hub delivered costing = fields only (WA5) | ~~`confirm_dropship_delivered_costing` credited courier COD~~ | **Done (2026-09):** same migration |
| SO4 | ~~not_built~~ | Courier wallet = COD receivable at deliver; tenant cash at remittance | ~~Remittance debited courier with no prior credit~~ | **Done (2026-09):** `ensure_dropship_courier_cod_receivable` + `20270929200000_dropship_courier_cod_receivable.sql` |
