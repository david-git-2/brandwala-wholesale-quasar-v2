# RPC: `list_thrift_stocks_paginated`

Stub rebuilt from `database.types.ts` after docs reorg. Expand from migrations as needed.

Domain: [../workflow.md](../workflow.md) · [../schema.md](../schema.md).

## Args

| Field | Type | Description |
| :--- | :--- | :--- |
| `p_condition` | `string` |  |
| `p_page` | `number` |  |
| `p_page_size` | `number` |  |
| `p_search` | `string` |  |
| `p_status` | `string` |  |
| `p_tenant_id` | `number` |  |

## Call

```ts
await supabase.rpc('list_thrift_stocks_paginated', { /* args */ })
```
