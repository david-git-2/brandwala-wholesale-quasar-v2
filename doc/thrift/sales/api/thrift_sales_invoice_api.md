# API: `thrift_sales_invoices` / items / PnL

Prefer RPCs for multi-table writes. Direct reads OK under tenant RLS.

Schema: [../schema.md](../schema.md) · Workflow: [../workflow.md](../workflow.md).

## Tables

| Table | Access pattern |
| :--- | :--- |
| `thrift_sales_invoices` | List/detail; writes via create / delivery / RTO / remittance RPCs |
| `thrift_sales_invoice_items` | Read with invoice; insert via create |
| `thrift_sales_pnl_lines` | Report reads; write via create / delivery / RTO / return RPCs |
| `thrift_sales_returns` | Post-pay returns; write via `create_thrift_sales_return` |
| `thrift_sales_return_items` | Lines on a return |
| `thrift_customers` | Upsert on create; list for lookup |

## Return paths

| Situation | API |
| :--- | :--- |
| No pickup / RTO | `revert_thrift_sales_invoice` (`RTO`) |
| Partial or full post-pay return | `create_thrift_sales_return` |


## Invoice columns (high-signal)

Fees: `courier_*`, `cod_fee_*`, `packing_*`, `return_courier_amount`.  
Tracks: `payment_status`, `delivery_status`, `close_reason`, `economics_closed_at`.  
COD: `cod_expected` (set at create), `cod_remitted_*` via `record_thrift_cod_remittance` only — staff edits remitted amount / when / ref / outcome / notes; never fee columns or `cod_expected` on that call.  
Write-off = same remittance RPC (`outcome = WRITTEN_OFF`).

## PnL line columns (high-signal)

`inbound_shipment_id`, `outcome`, `sell_amount`, `allocated_*`, `event_date`.

COGS is **not** on these tables — report joins landed cost by `stock_id`.
