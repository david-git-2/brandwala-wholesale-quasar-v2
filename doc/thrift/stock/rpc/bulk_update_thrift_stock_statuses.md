# RPC: `bulk_update_thrift_stock_statuses`

Stub rebuilt from `database.types.ts` after docs reorg. Expand from migrations as needed.

Domain: [../workflow.md](../workflow.md) · [../schema.md](../schema.md).

## Args

| Field | Type | Description |
| :--- | :--- | :--- |
| `p_status` | `string; p_stock_ids: number[]; p_tenant_id: number }` |  |
| `Returns` | `undefined` |  |
| `bump_tenant_permission_version` | `{` |  |
| `Args` | `{ p_tenant_id: number }` |  |
| `Returns` | `undefined` |  |
| `calculate_costing_auxiliary_price_gbp` | `{` |  |
| `Args` | `{ p_delivery_price_gbp: number; p_price_in_web_gbp: number }` |  |
| `Returns` | `number` |  |
| `calculate_costing_item_type_surcharge_gbp` | `{` |  |
| `Args` | `{ p_item_type: string }` |  |
| `Returns` | `number` |  |
| `calculate_landed_unit_cost` | `{` |  |
| `Args` | `{ p_shipment_item_id: number }` |  |
| `Returns` | `number` |  |
| `can_access_cart` | `{ Args: { p_cart_id: number }; Returns: boolean }` |  |
| `can_access_cart_item` | `{` |  |
| `Args` | `{ p_cart_item_id: number }` |  |
| `Returns` | `boolean` |  |
| `can_admin_manage_costing_file` | `{` |  |
| `Args` | `{ p_tenant_id: number }` |  |
| `Returns` | `boolean` |  |
| `can_assign_membership_role` | `{` |  |
| `Args` | `{` |  |
| `p_target_role` | `Database["public"]["Enums"]["app_role"]` |  |
| `p_target_tenant_id` | `number` |  |

## Call

```ts
await supabase.rpc('bulk_update_thrift_stock_statuses', { /* args */ })
```
