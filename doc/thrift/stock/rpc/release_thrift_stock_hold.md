# RPC: `release_thrift_stock_hold`

Stub rebuilt from `database.types.ts` after docs reorg. Expand from migrations as needed.

Domain: [../workflow.md](../workflow.md) · [../schema.md](../schema.md).

## Args

| Field | Type | Description |
| :--- | :--- | :--- |
| `p_stock_id` | `number; p_tenant_id: number }` |  |
| `Returns` | `Json` |  |
| `remove_global_invoice_item` | `{` |  |
| `Args` | `{ p_invoice_item_id: number }` |  |
| `Returns` | `undefined` |  |
| `remove_shop_cart_item` | `{ Args: { p_cart_item_id: number }; Returns: Json }` |  |
| `resolve_billing_profile_for_customer_group` | `{` |  |
| `Args` | `{ p_customer_group_id: number; p_tenant_id: number }` |  |
| `Returns` | `number` |  |
| `resolve_costing_file_creator_label` | `{` |  |
| `Args` | `{` |  |
| `p_created_by_email` | `string` |  |
| `p_customer_group_id` | `number` |  |
| `p_tenant_id` | `number` |  |

## Call

```ts
await supabase.rpc('release_thrift_stock_hold', { /* args */ })
```
