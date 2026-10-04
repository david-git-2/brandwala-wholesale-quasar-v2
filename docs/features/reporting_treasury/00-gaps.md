# Reporting & treasury — gaps

Fixture tenant **15** for regression after RT18–RT19. SQL: grep `public.sql` (reports not split), then `backend:schema:diff`.

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| RT1 | sql_split | Reporting domain | RPCs in `public.sql` | Split later |
| RT18 | not_built | Shipment P&L minus **local costs** ([procurement US-8](../procurement_stock/spec.md)) | Landed / line COGS only | Subtract `global_shipment_local_costs` in `get_tenant_shipment_profit_report` |
| RT19 | not_built | GP by `shipment_id` vs landed + local; no bill-line COGS | Invoice profit RPC COGS = 0 | Shipment P&L UI ([spec](spec.md) US-1); align margin RPCs |
