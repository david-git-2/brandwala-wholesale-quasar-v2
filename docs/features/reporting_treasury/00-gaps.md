# Reporting & treasury — gaps

Fixture tenant **15** for regression after RT18. SQL: grep `public.sql` (reports not split), then `backend:schema:diff`.

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| RT1 | sql_split | Reporting domain | RPCs in `public.sql` | Split later |
| RT18 | not_built | Shipment P&L minus **non-capitalizable** costs ([procurement US-8](../procurement_stock/spec.md)) | Landed / line COGS only | Subtract `global_shipment_cost_entries` where `is_capitalizable = false` in `get_tenant_shipment_profit_report` |

**Retired (2026-11):** RT19 invoice-line COGS report — dropped with `get_tenant_invoice_profit_report`; GP stays shipment P&L only.
