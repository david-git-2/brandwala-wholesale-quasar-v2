# RPC: `delete_thrift_stocks` (goal)

Soft-delete (archive) stock for the desk. Does **not** remove rows needed for sales history.

Schema: [../schema.md](../schema.md) · Workflow: [../workflow.md](../workflow.md)

## Args (goal)

| Arg | Required | Notes |
| :--- | :---: | :--- |
| `p_tenant_id` | Yes | |
| `p_stock_ids` | Yes | Ids to archive |
| `p_deleted_by` | Yes | Actor |

## Behaviour (goal)

1. For each id: set `deleted_at = now()`, `deleted_by`.  
2. Hide from default open-stock lists.  
3. **Reject** (or no-op with clear error) hard removal — especially if status is `SOLD` or any invoice line references the stock.  
4. Keep `stock_id` on existing invoice lines valid for reporting joins.

## Call

```ts
await supabase.rpc('delete_thrift_stocks', {
  p_tenant_id,
  p_stock_ids,
  p_deleted_by,
})
```
