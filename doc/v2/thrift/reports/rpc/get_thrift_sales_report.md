# RPC: `get_thrift_sales_report`

Period sales P&L from **`thrift_sales_pnl_lines`** + **live** inbound COGS.

Permission: `thrift_reports` / `view`.  
Domain: [../workflow.md](../workflow.md) · [../schema.md](../schema.md).

## Args

| Arg | Type | Required | Notes |
| :--- | :--- | :---: | :--- |
| `p_tenant_id` | bigint | Yes | |
| `p_date_from` | date/timestamptz | Yes | Filter PnL `event_date` |
| `p_date_to` | date/timestamptz | Yes | Inclusive end |
| `p_sale_channel` | text | No | Join invoice |
| `p_outcome` | text | No | `DELIVERED` \| `RTO` \| `CUSTOMER_RETURN` |

## Behaviour

1. Select PnL lines in date range (tenant).  
2. `cogs = sell_amount > 0 ? compute_thrift_landed_unit_cost(stock_id) * quantity : 0`.  
3. Aggregate: invoice_count (distinct), units, net_revenue (`sell_amount`), cogs, fee buckets, net_profit.  
4. Breakdown by `outcome` and optional `sale_channel`.  
5. `cod_outstanding`: all open `ACTIVE` + `COD_PENDING` (not date-filtered) — unchanged cash card.  
6. Refunds/RTO loss visible via `outcome != DELIVERED` fee totals + zero sell — **not** by deleting ledger expenses.

## Returns (shape)

```json
{
  "date_from": "...",
  "date_to": "...",
  "summary": {
    "invoice_count": 0,
    "units": 0,
    "net_revenue": 0,
    "cogs": 0,
    "allocated_shop_delivery": 0,
    "allocated_shop_cod_fee": 0,
    "allocated_shop_packing": 0,
    "allocated_return_courier": 0,
    "allocated_fees_total": 0,
    "net_profit": 0
  },
  "by_outcome": [],
  "by_channel": [],
  "cod_outstanding": {
    "invoice_count": 0,
    "cod_expected_total": 0,
    "cod_remitted_total": 0
  }
}
```

## Call

```ts
await supabase.rpc('get_thrift_sales_report', {
  p_tenant_id: tenantId,
  p_date_from: dateFrom,
  p_date_to: dateTo,
  p_sale_channel: null,
  p_outcome: null,
})
```
