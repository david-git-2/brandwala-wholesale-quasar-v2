# RPC: `revert_thrift_sales_invoice`

**RTO / no-pickup** whole close, or **staff mistake** erase.  
Post-pay partial/full returns → [`create_thrift_sales_return`](./create_thrift_sales_return.md).

Permission: `return` / `force_return` / `staff_mistake`.  
Schema: [../schema.md](../schema.md).

## Args

| Arg | Notes |
| :--- | :--- |
| `p_tenant_id` | |
| `p_invoice_id` | |
| `p_reason` | `RTO` \| `STAFF_MISTAKE` (legacy `RETURN` with `p_close_reason=RTO` accepted) |
| `p_return_courier_amount` | RTO courier shop cost |
| `p_force` | Bypass windows where applicable |
| `p_notes` | |

## Behaviour

### RTO (`close_reason = RTO`)

Whole invoice only (situation A — customer did not pick up).

1. Reject if any `thrift_sales_returns` already exist.  
2. Soft `RETURNED` + `REFUNDED`; Online `delivery_status = RETURNED`.  
3. Restore all stocks sellable.  
4. Ledger refund + losses; **never delete** expenses.  
5. PnL all lines → `RTO`.

### `STAFF_MISTAKE`

Permission: `thrift_sales` / `staff_mistake`.  
Hard-delete path — erase a wrongly created invoice. **Not** soft-close.

1. **Reject** if any `thrift_sales_returns` exist (unless future admin force).  
2. Restore **all** line stocks to `AVAILABLE`.  
3. Delete invoice-sourced ledger rows (`source = INVOICE`) — scrub REVENUE/EXPENSE; do **not** post `REFUND`/`LOSS`.  
4. Delete `thrift_sales_pnl_lines` for the invoice.  
5. Hard-delete invoice (+ items cascade).  
6. **Do not** change `thrift_invoice_counters` — never reuse or decrement; number gaps are OK.  
7. Return `{ id, invoice_number, deleted: true, … }`.

## Call

```ts
await supabase.rpc('revert_thrift_sales_invoice', {
  p_tenant_id: tenantId,
  p_invoice_id: invoiceId,
  p_reason: 'RTO',
  p_return_courier_amount: 80,
})
```
