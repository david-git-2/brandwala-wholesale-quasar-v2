# Thrift Stock — Workflow (goal)

Schema: [schema.md](./schema.md)

---

## 1. Register & price

1. Register stock on a shipment (web or mobile RPC); attach barcode; set weights / origin inputs.  
2. Pricing: auto listed from landed × markup unless manual — [costing.md](./costing.md).  
3. Optional: images, measurements, bulk shelf/status.  
4. Optional hold (`RESERVED`) — [workflow_hold.md](./workflow_hold.md).

## 2. Sale

Desk sale marks stock `SOLD` and writes invoice lines with `stock_id` (sell prices on invoice only). See [../sales/workflow.md](../sales/workflow.md).

## 3. Soft delete (archive)

Desk “delete” = **soft delete**:

1. Set `deleted_at` / `deleted_by`.  
2. Hide from open stock UI / default list filters.  
3. Keep the row so invoice history and margin reports still join `stock_id` → stock → costing.  
4. Release barcode to the pool only when product rules allow (if barcode must stay tied for history, keep association).

Do **not** hard-delete stock that is `SOLD` or referenced by an invoice line.

RPC: [rpc/delete_thrift_stocks.md](./rpc/delete_thrift_stocks.md) (soft-delete behaviour).

## 4. Cost for reports

Landed cost is **not** frozen on the invoice (inputs can still change). At report time:

```text
invoice_items.stock_id → stock → shipment/settings → costing engine
```

## Related RPCs

- [api/thrift_stock_api.md](./api/thrift_stock_api.md)  
- [rpc/register_thrift_stock_from_app.md](./rpc/register_thrift_stock_from_app.md)  
- [rpc/list_thrift_stocks_paginated.md](./rpc/list_thrift_stocks_paginated.md)  
- [rpc/delete_thrift_stocks.md](./rpc/delete_thrift_stocks.md)  
- [rpc/compute_thrift_landed_unit_cost.md](./rpc/compute_thrift_landed_unit_cost.md)  
- [rpc/hold_thrift_stock.md](./rpc/hold_thrift_stock.md) · [rpc/release_thrift_stock_hold.md](./rpc/release_thrift_stock_hold.md)
