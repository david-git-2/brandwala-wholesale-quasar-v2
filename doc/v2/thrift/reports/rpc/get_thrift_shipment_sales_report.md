# RPC: `get_thrift_shipment_sales_report`

Inbound **purchase shipment** P&L: PnL lines where `inbound_shipment_id = p_shipment_id` + live COGS.

Permission: `thrift_reports` / `view`.  
Does **not** alter `thrift_shipments` schema.

## Args

| Arg | Type | Required | Notes |
| :--- | :--- | :---: | :--- |
| `p_tenant_id` | bigint | Yes | |
| `p_shipment_id` | bigint | Yes | Inbound shipment |
| `p_date_from` | date | No | Optional `event_date` filter |
| `p_date_to` | date | No | |

## Behaviour

1. Verify shipment belongs to tenant.  
2. Load PnL lines for `inbound_shipment_id`.  
3. Live COGS when `sell_amount > 0`.  
4. Summary + line detail (invoice number, outcome, sell, fees, cogs, net).

## Returns (shape)

```json
{
  "shipment": { "id": 1, "name": "..." },
  "summary": {
    "units": 0,
    "net_revenue": 0,
    "cogs": 0,
    "allocated_fees_total": 0,
    "net_profit": 0,
    "rto_fee_loss": 0,
    "delivered_net": 0
  },
  "lines": [
    {
      "invoice_id": 1,
      "invoice_number": "INV-...",
      "outcome": "DELIVERED",
      "stock_id": 1,
      "sell_amount": 0,
      "landed_unit_cost": 0,
      "cogs": 0,
      "allocated_fees_total": 0,
      "net_profit": 0
    }
  ]
}
```

## Call

```ts
await supabase.rpc('get_thrift_shipment_sales_report', {
  p_tenant_id: tenantId,
  p_shipment_id: shipmentId,
})
```
