# Reporting & treasury — gaps

Fixture tenant **15**, **shipment id 54** (`Test Shipment 26`) — canonical report P&amp;L golden: `web/src/modules/reporting_treasury/fixtures/shipment_report_golden_s54.json` (vitest) + `supabase/tests/shipment_s54_report_golden.sql` (landed/paid bootstrap). Do not change expected numbers without sign-off (same rule as `shipment_golden_s54.json`). SQL: grep schemas (reports not split), then `backend:schema:diff`.

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| RT1 | sql_split | Reporting domain | RPCs in `public.sql` | Split later |
| RT18 | not_built | Shipment P&L minus **non-capitalizable** costs ([procurement US-8](../procurement_stock/spec.md)) | Landed / line COGS only | Subtract `global_shipment_cost_entries` where `is_capitalizable = false` in `get_tenant_shipment_profit_report` |
| RT20 | not_built | Investor capital + share-of-GP on shipment report detail ([spec US-4](spec.md)) | Shipment detail has no investor block | RPC/UI: join `shipment_investments`; show amount + `cost_share_pct` × shipment GP |
| RT21 | doc_done | Root `REPORTS_PLAN.md` duplicate | Deleted; product truth in this spec only | — |
| RT22 | shipped | Shipment P&amp;L sales/AP on kernel bills | RPCs still read `public.bills` / `global_invoice_items` | `get_tenant_shipment_*` + `get_shipment_pnl` → `money_kernel.bills` / `bill_lines` |
| RT23 | shipped | Customers report ([US-5](spec.md)) | Hub + `list_customers_report` / header / section RPCs | Customer dues page removed; `/customer-dues` → customers |
| RT24 | shipped | Vendor credit notes on shipment report detail | `vendor_credit_notes` + net P&amp;L in RPC/UI | — |

**Retired (2026-11):** RT19 invoice-line COGS report — dropped with `get_tenant_invoice_profit_report`; GP stays shipment P&L only.

**Retired (2026-11):** Customer dues hub + `CustomerDuesReportPage` — `get_customer_dues_report` unused in UI; chase aging available on customer detail KPIs / bills section.
