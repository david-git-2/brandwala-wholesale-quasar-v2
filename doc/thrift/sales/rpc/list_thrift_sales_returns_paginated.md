# RPC: `list_thrift_sales_returns_paginated`

Returns management list for the post-pay returns hub.

Permission: `thrift_sales` / `view` (or `thrift_reports` / `view` if read-only ops).  
Schema: [../schema.md](../schema.md) · UI: [../workflow.md](../workflow.md) §5.0b.

## Filters (conceptual)

| Arg | Notes |
| :--- | :--- |
| `p_tenant_id` | Required |
| `p_date_from` / `p_date_to` | On return `created_at` |
| `p_search` | `return_number`, invoice number, customer phone/name |
| `p_invoice_id` | Optional — history for one invoice |
| `p_condition` | Optional — has any `DAMAGED` line |
| `p_skip_count` | Large lists |

## Returns (shape)

Header rows: `return_number`, invoice number, refund_amount, return_courier_amount, line_count, created_at, created_by. Detail via join or follow-up read of return items.

## Call

```ts
await supabase.rpc('list_thrift_sales_returns_paginated', { /* … */ })
```
