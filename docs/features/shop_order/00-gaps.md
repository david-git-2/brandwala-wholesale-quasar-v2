# Shop order & dropship — gaps

Open with [spec.md](spec.md). Types: `not_built` | `doc_wrong` | `sql_split`. When you ship a row: delete it.

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| SO1 | ~~not_built~~ | Declarative `shop_order/03_rpcs.sql` matched live remittance + payload | ~~Truncated remittance RPCs~~ | **Done (2026-09)** |
| SO2 | ~~design~~ | Bank transfer credits wallet from remittance remainder only | ~~`transfer_dropship_reseller_profit` after remittance~~ | **Done (2026-09)** |
| SO3 | ~~not_built~~ | Finance hub delivered costing = fields only (WA5) | ~~`confirm_dropship_delivered_costing` credited courier COD~~ | **Done (2026-09)** |
| SO4 | ~~not_built~~ | Courier wallet = COD receivable at deliver; tenant cash at remittance | ~~Remittance debited courier with no prior credit~~ | **Done (2026-09)** |
| SO5 | ~~not_built~~ | Remittance closes settlement | ~~Skipped settlement~~ | **Done (2026-09)** |
| SO6 | ~~design~~ | Catalog pack → Delivery paper close | ~~`fulfill_shop_order_to_invoice` for fixed_price~~ | **Done (2026-10):** RPC blocks `fixed_price`; use Delivery paper close |
| SO7 | ~~not_built~~ | US-4 recipient call | ~~No call gate~~ | **Done (2026-10)** |
