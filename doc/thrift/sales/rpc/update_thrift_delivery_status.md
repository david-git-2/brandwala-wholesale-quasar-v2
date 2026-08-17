# RPC: `update_thrift_delivery_status`

Advances Online invoice **parcel** status on `thrift_sales_invoices` (no separate delivery table). Writes PnL on first `DELIVERED`. RTO uses revert/close — do not only flip to `RETURNED` without economics close. Independent of COD remittance (`DELIVERED` never sets `PAID`).

Permission: `thrift_sales` / `update` (or dedicated delivery action).  
Schema: [../schema.md](../schema.md) · Workflow: [../workflow.md](../workflow.md) §2.

## Args

| Arg | Type | Required | Notes |
| :--- | :--- | :---: | :--- |
| `p_tenant_id` | bigint | Yes | |
| `p_invoice_id` | bigint | Yes | Online, `ACTIVE` |
| `p_delivery_status` | text | Yes | `PENDING` \| `READY` \| `IN_TRANSIT` \| `DELIVERED` \| `RETURNED` |

## Behaviour

1. Reject Offline invoices (`delivery_status` must stay null).  
2. Validate allowed transition on the path in sales workflow.  
3. If new status = `DELIVERED` and PnL not yet written: insert `thrift_sales_pnl_lines` with `outcome = DELIVERED` (shop-paid fee pools only); set `economics_closed_at`.  
4. If new status = `RETURNED`: either  
   - require caller to use `revert_thrift_sales_invoice` with `close_reason = RTO`, or  
   - this RPC accepts `p_return_courier_amount` and performs full RTO close (preferred single entry).  
5. Never changes `payment_status`.

## Call

```ts
await supabase.rpc('update_thrift_delivery_status', {
  p_tenant_id: tenantId,
  p_invoice_id: invoiceId,
  p_delivery_status: 'DELIVERED',
})
```
