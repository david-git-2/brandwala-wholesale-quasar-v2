# RPC: `revert_thrift_sales_invoice`

Fully reverts an **ACTIVE** thrift sales invoice for either a customer **Return** or a **Staff Mistake**.

## Behavior

| `p_reason` | Invoice `status` after | Stock | Ledger |
| :--- | :--- | :--- | :--- |
| `RETURN` | `RETURNED` | qty restored, `AVAILABLE` | `REFUND` / `INVOICE` |
| `STAFF_MISTAKE` | `STAFF_MISTAKE` | same | same (note differs) |

Guards: tenant match; status must be `ACTIVE`; second call raises.

## Call

```ts
supabase.rpc('revert_thrift_sales_invoice', {
  p_tenant_id: 15,
  p_invoice_id: 42,
  p_reason: 'RETURN', // or 'STAFF_MISTAKE'
  p_reverted_by: 'cashier@brandwala.com',
  p_notes: 'Customer changed mind',
});
```
