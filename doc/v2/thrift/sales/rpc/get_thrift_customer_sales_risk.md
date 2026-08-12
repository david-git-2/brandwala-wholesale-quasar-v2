# RPC: `get_thrift_customer_sales_risk`

Customer RTO + post-pay return history by phone for create-sale risk panel / COD advance.

Permission: `thrift_sales` / `view`.  
Schema: [../schema.md](../schema.md) · Workflow: [../workflow.md](../workflow.md) §1.

## Args

| Arg | Notes |
| :--- | :--- |
| `p_tenant_id` | |
| `p_phone` | Normalized via `normalize_thrift_phone` (digits-only) |

Empty / non-digit phone → `{ customer_id: null, rto_count: 0, return_count: 0, rtos: [], returns: [] }`.

## Behaviour

1. Resolve `thrift_customers.id` by `(tenant_id, phone_normalized)` when present.  
2. **RTO list:** invoices with `close_reason = 'RTO'` matching `customer_id` **or** normalized `customer_phone`.  
3. **Returns list:** `thrift_sales_returns` joined to invoices with the same customer match.  
4. Counts are full totals; each list dated DESC, max **20**.  
5. Return JSON (separate labeled lists).

## Payload

```json
{
  "customer_id": 1,
  "rto_count": 2,
  "return_count": 1,
  "rtos": [
    {
      "kind": "RTO",
      "invoice_id": 10,
      "invoice_number": "...",
      "at": "ISO",
      "total_invoice_amount": 3000
    }
  ],
  "returns": [
    {
      "kind": "CUSTOMER_RETURN",
      "return_id": 5,
      "return_number": "...",
      "invoice_id": 9,
      "invoice_number": "...",
      "at": "ISO",
      "refund_amount": 1000,
      "line_count": 1,
      "has_damaged": false
    }
  ]
}
```

## UI use

Online create-sale: after phone debounce, if `rto_count + return_count > 0`, require `advance_amount > 0` (non-refundable; deducted from `cod_expected`).

## Call

```ts
await supabase.rpc('get_thrift_customer_sales_risk', {
  p_tenant_id: tenantId,
  p_phone: phone,
});
```
