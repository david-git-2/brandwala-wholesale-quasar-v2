# RPC: `list_thrift_sales_invoices_paginated`

Paginated invoice list for desk UI.

Permission: `thrift_sales` / `view`.

## Filters (conceptual)

| Arg | Notes |
| :--- | :--- |
| `p_tenant_id` | Required |
| `p_payment_status` | `COD_PENDING`, `PAID`, `REFUNDED`, `WRITTEN_OFF` |
| `p_status` | `ACTIVE` \| `RETURNED` |
| `p_delivery_status` | Online parcel filter |
| `p_close_reason` | `RTO` \| `CUSTOMER_RETURN` |
| `p_sale_channel` | |
| `p_search` | invoice number / phone / name |
| `p_skip_count` | large lists |

Returns header fields including fees, COD, delivery, `close_reason` — not COGS.

## Call

```ts
await supabase.rpc('list_thrift_sales_invoices_paginated', { /* … */ })
```
