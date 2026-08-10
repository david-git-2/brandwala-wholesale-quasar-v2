# RPC: `generate_thrift_barcodes`

Stub rebuilt from `database.types.ts` after docs reorg. Expand from migrations as needed.

Domain: [../workflow.md](../workflow.md) · [../schema.md](../schema.md).

## Args

| Field | Type | Description |
| :--- | :--- | :--- |
| `p_inserted_by` | `string; p_quantity: number; p_tenant_id: number }` |  |
| `Returns` | `string[]` |  |
| `generate_thrift_invoice_number` | `{` |  |
| `Args` | `{ p_date?: string; p_tenant_id: number }` |  |
| `Returns` | `string` |  |
| `get_active_module_keys_for_tenant` | `{` |  |
| `Args` | `{ p_tenant_id: number }` |  |
| `Returns` | `string[]` |  |
| `get_allocation_reconciliation` | `{` |  |
| `Args` | `{ p_stock_id: number }` |  |
| `Returns` | `{` |  |
| `allocated_qty` | `number` |  |
| `global_qty` | `number` |  |
| `is_reconciled` | `boolean` |  |
| `stock_id` | `number` |  |
| `unallocated_qty` | `number` |  |

## Call

```ts
await supabase.rpc('generate_thrift_barcodes', { /* args */ })
```
