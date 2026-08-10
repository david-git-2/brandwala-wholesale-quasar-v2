# RPC: `bulk_update_thrift_stock_locations`

Stub rebuilt from `database.types.ts` after docs reorg. Expand from migrations as needed.

Domain: [../workflow.md](../workflow.md) · [../schema.md](../schema.md).

## Args

| Field | Type | Description |
| :--- | :--- | :--- |
| `p_box_id` | `number` |  |
| `p_shelf_id` | `number` |  |
| `p_stock_ids` | `number[]` |  |
| `p_tenant_id` | `number` |  |

## Call

```ts
await supabase.rpc('bulk_update_thrift_stock_locations', { /* args */ })
```
