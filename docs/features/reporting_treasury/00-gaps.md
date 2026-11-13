# Reporting & treasury — gaps

Fixture tenant **15** for regression after RT18. SQL: grep schemas (reports not split), then `backend:schema:diff`.

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| RT1 | sql_split | Reporting domain | RPCs in `public.sql` | Split later |
| RT18 | not_built | Shipment P&L minus **non-capitalizable** costs ([procurement US-8](../procurement_stock/spec.md)) | Landed / line COGS only | Subtract `global_shipment_cost_entries` where `is_capitalizable = false` in `get_tenant_shipment_profit_report` |
| RT20 | not_built | Investor capital + share-of-GP on shipment report detail ([spec US-4](spec.md)) | Shipment detail has no investor block | RPC/UI: join `shipment_investments`; show amount + `cost_share_pct` × shipment GP |
| RT21 | doc_done | Root `REPORTS_PLAN.md` duplicate | Deleted; product truth in this spec only | — |

**Retired (2026-11):** RT19 invoice-line COGS report — dropped with `get_tenant_invoice_profit_report`; GP stays shipment P&L only.
