# RPC: `create_thrift_sales_return`

Post-pay / post-delivery return — **partial or full** line set.  
**Not** for no-pickup RTO (use invoice RTO close).

Permission: `thrift_sales` / `return` (or `force_return`).  
Schema: [../schema.md](../schema.md) · Workflow: [../workflow.md](../workflow.md) §5.

## Args (conceptual)

| Arg | Notes |
| :--- | :--- |
| `p_tenant_id` | |
| `p_invoice_id` | Not RTO-closed |
| `p_items` | `[{ invoice_item_id, quantity, condition: SELLABLE\|DAMAGED }]` — ≥1 |
| `p_return_courier_amount` | Shop loss; default `0` |
| `p_notes` | optional |

## Behaviour

1. Validate invoice: Offline OK; Online requires `delivery_status = DELIVERED` (or already `PARTIALLY_RETURNED` after a prior deliver).  
2. Validate each line not already returned; qty within line.  
3. Insert return header + items; allocate `RET-YYYY-MM-#####`.  
4. Restore stocks per `condition`.  
5. Ledger: `REFUND` = Σ refund amounts; `LOSS` = return courier if `> 0`.  
6. Update PnL for those `invoice_item_id`s only → `CUSTOMER_RETURN`.  
7. Set invoice `PARTIALLY_RETURNED` / `RETURNED` and payment `PARTIALLY_REFUNDED` / `REFUNDED`.  
8. Return `{ return_id, return_number }`.

## UI

1. **Create:** Dedicated **Return items** action on invoice detail (not Create Invoice, not Mark RTO). Staff multi-selects returnable lines, sets `SELLABLE`/`DAMAGED` per line, enters `return_courier_amount`, confirms refund total.  
2. **Manage:** Separate **Returns list / detail** hub to search and open past returns (date, return number, invoice, phone). See [../workflow.md](../workflow.md) §5.0–5.0b.

## Call

```ts
await supabase.rpc('create_thrift_sales_return', {
  p_tenant_id: tenantId,
  p_invoice_id: invoiceId,
  p_items: [
    { invoice_item_id: 11, quantity: 1, condition: 'SELLABLE' },
  ],
  p_return_courier_amount: 60,
})
```
