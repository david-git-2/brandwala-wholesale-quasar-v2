# Reporting & treasury — gaps

## Proven fixture (2026-09)

Replay after each RT12–RT17 fix. Tenant **15**. Customer **TR** (`billing_profile_id` 7). Wholesale **INV-WS-20260917-0001** (id 64): billed **1,237,390**, collected **1,237,000**, write-off **390**, due **0**. Shipment **WTS Shipment 23** (id 30): ordered **1,500**, sold **1,497**. Live receipts: payments 17–20, 22, 24. Voided: 21, 23. Investor capital **10,000** is not a receipt. Courier COD empty = correct (wholesale, not dropship).

SQL edits: [`supabase/schemas/public.sql`](../../../supabase/schemas/public.sql) (reports not split), then `pnpm run backend:schema:diff` + migration. Do not hand-edit `20270913*` history.

## Fix order (one slice per PR)

1. RT12 — invoice book + customer dues  
2. RT13 — invoice profit detail  
3. RT14 + RT15 — cash in + month snapshot cash tile  
4. RT16 — wallet liability credits  
5. RT17 — shipment profit sold %

Optional later: partner capital report (not one of the eight views).

| ID | Type | Plan / doc | Code today | Fix |
| :--- | :--- | :--- | :--- | :--- |
| RT1 | sql_split | Reporting domain | RPCs in `public.sql` | Split later |
| RT2 | **Done** | ACs match layers | [spec](spec.md) US-1–3 ticked | — |
| RT3 | **Done** | Sales = issued `total_amount`; never COD | `p_invoice_type` on profit; snapshot `sales_by_invoice_type` | `20270928160000_reporting_money_layers_rt3_11.sql` |
| RT4 | **Done** | Cash in = receipts only | `buyer_receipt` / `courier_remittance` on entries | same migration |
| RT5 | **Done** | AR = billed party due | Dues + snapshot AR: `billing_profile_id` required; not wholesale-only | same migration |
| RT6 | **Done** | COD report is ops, not sales | Remitted = ledger net; `payment_received` included | `20270928160000_*` + `20270928161000_courier_cod_include_payment_received.sql` |
| RT7 | **Done** | Wallet liability split | Totals: `customer_store_credit`, `merchant_payable`, `courier` | `20270928160000_*` |
| RT8 | **Done** | Month snapshot tiles | Five tiles + cash caption | same migration + `MonthSnapshotReportPage.vue` |
| RT9 | **Done** | Collect is pays module | Payments/collect under `web/src/modules/wallet/` | routes still `finance/payments` |
| RT10 | **Done** | Shipment P&L revenue = invoice sell | `get_tenant_shipment_profit_report` uses issued line sell (RT17) | no COD change needed |
| RT11 | **Done** | Cash-in by instrument | `global_payment_instruments` + `bd_banks` on entries / `by_method` | `20270928160000_*` |
| RT12 | **Done** | Invoice book + customer dues | Was `settlement_discount_amount`; voided receipts counted | `written_off_amount`; `gp.voided_at IS NULL` — `20270928120000_fix_report_rpcs_rt12.sql` |
| RT13 | **Done** | Invoice profit detail | Orphan `line_metrics` SELECT | Second `WITH line_metrics` on detail query — `20270928130000_fix_report_rpcs_rt13.sql` |
| RT14 | **Done** | Cash in | UWL tenant credits | Non-void `global_payments`; voided excluded; fixture Sep **1,237,000** — `20270928140000_fix_report_rpcs_rt14_15.sql` |
| RT15 | **Done** | Month snapshot cash tile | UWL cash | Same receipt rule as RT14 — `20270928140000_fix_report_rpcs_rt14_15.sql` |
| RT16 | **Done** | Wallet liability | Gross customer credits | Net of reversal/void purposes — `20270928150000_fix_report_rpcs_rt16_17.sql`; entity split still RT7 |
| RT17 | **Done** | Shipment profit | Sold-only inbound | Ordered inbound; sold % **99.8**; revenue **1,237,000** on fixture — `20270928150000_fix_report_rpcs_rt16_17.sql` |
| RT18 | not_built | Shipment P&L minus **local costs** ([procurement US-8](../procurement_stock/spec.md)) | Landed / line COGS only | Subtract `global_shipment_local_costs` sum in `get_tenant_shipment_profit_report` |
| RT19 | not_built | GP = lines **by `shipment_id`** vs shipment landed + local. No bill cost table | Invoice profit RPC: COGS = 0; bill cost table dropped ([SI5](../bills_pays/00-gaps.md) done 2026-10) | Shipment P&L UI ([spec](spec.md) US-1); align margin RPCs to shipment landed cost |
