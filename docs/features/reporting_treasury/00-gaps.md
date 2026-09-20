# Reporting & treasury — gaps

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| RT1 | sql_split | Reporting domain | RPCs in `public.sql` | Split later |
| RT2 | doc_wrong | ACs `[ ]` | Pages exist for the eight views | Tick only ACs that match **layer** rules in `01-prd` |
| RT3 | design | Sales = issued `total_amount`; never COD | Invoice book/profit/month snapshot may treat all invoice-like or COD-ish totals as revenue | Split by `invoice_type`; tenant sell only |
| RT4 | design | Cash in = receipts only | Cash in / snapshot may mix till, invoice paid, or COD | `get_tenant_cash_in_report` from receipts; `source` includes courier remittance |
| RT5 | design | AR = billed party due | Dues may blur recipient COD vs merchant bill | Age `billing_profile` invoice due only |
| RT6 | design | COD report is ops, not sales | `get_tenant_courier_cod_report` exists | Keep face vs remitted; do not add into snapshot “revenue” |
| RT7 | design | Wallet liability split merchant / customer / courier | One liability total | Break down `entity_type`; show dropship payable (e.g. 620) |
| RT8 | design | Month snapshot four tiles + payable caption | KPI “TOTAL REVENUE” next to cash | Separate tiles; cash may exceed sales |
| RT9 | design | Collect is wallet, not reporting | US-3 / Billing Balances posts `create_billing_profile_payment_with_allocations` | Move ownership to [wallet](../wallet/01-prd.md); report pages stay read-only |
| RT10 | design | Shipment P&L revenue = invoice sell | May use resell/COD | Same sell rule as invoice profit |
| RT11 | not_built | Cash-in report breakdown by instrument (cash / cheque / bKash) | Report may filter by header method only | After [wallet WA9](../wallet/00-gaps.md): join `global_payment_instruments` + `payment_methods`; cheque detail via `bd_banks` |
