# RPC: `get_thrift_dashboard_metrics`

Compact thrift hub metrics.

Permission: `thrift_reports` / `view`.

## Behaviour

1. Period net from PnL engine (same formulas as sales report).  
2. COD outstanding from invoices.  
3. Counts: delivered vs RTO vs customer return in period.  
4. Optional: open Online parcels (`PENDING`/`READY`/`IN_TRANSIT`).

Does not change stock/shipment schemas.

## Call

```ts
await supabase.rpc('get_thrift_dashboard_metrics', {
  p_tenant_id: tenantId,
  p_date_from: dateFrom,
  p_date_to: dateTo,
})
```
