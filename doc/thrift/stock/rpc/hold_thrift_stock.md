# RPC: `hold_thrift_stock`

Stub rebuilt from `database.types.ts` after docs reorg. Expand from migrations as needed.

Domain: [../workflow.md](../workflow.md) · [../schema.md](../schema.md).

## Args

| Field | Type | Description |
| :--- | :--- | :--- |
| `p_held_by` | `string` |  |
| `p_held_for_name` | `string` |  |
| `p_held_for_phone` | `string` |  |
| `p_hold_expires_at` | `string` |  |
| `p_hold_note` | `string` |  |
| `p_stock_id` | `number` |  |
| `p_tenant_id` | `number` |  |

## Call

```ts
await supabase.rpc('hold_thrift_stock', { /* args */ })
```
