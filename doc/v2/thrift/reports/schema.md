# Thrift Reports — Schema (goal)

Reports are **read models**. No dedicated warehouse tables beyond sales facts.

| Need | Source |
| :--- | :--- |
| Recognized sell + allocated shop logistics | `thrift_sales_pnl_lines` |
| Outcome / close reason | PnL `outcome` + invoice `close_reason` / status |
| Post-pay return history | `thrift_sales_returns` + items |
| COGS | `stock_id` → `compute_thrift_landed_unit_cost` (**live**); if `cogs_is_loss` count as loss when sell is 0 |
| Invoice commercial / COD | `thrift_sales_invoices` |
| Money events | `thrift_accounting_ledger` |

Sales: [../sales/schema.md](../sales/schema.md) · Scenarios: [../sales/scenarios.md](../sales/scenarios.md).
