# RPC: `compute_thrift_landed_unit_cost`

Stub rebuilt from `database.types.ts` after docs reorg. Expand from migrations as needed.

Domain: [../workflow.md](../workflow.md) · [../schema.md](../schema.md).

## Args

| Field | Type | Description |
| :--- | :--- | :--- |
| `p_stock_id` | `number }` |  |
| `Returns` | `number` |  |
| `confirm_courier_remittance_to_tenant` | `{` |  |
| `Args` | `{` |  |
| `p_bank_trx_id` | `string` |  |
| `p_courier_charge` | `number` |  |
| `p_order_id` | `number` |  |
| `p_remittance_ref` | `string` |  |

## Call

```ts
await supabase.rpc('compute_thrift_landed_unit_cost', { /* args */ })
```
