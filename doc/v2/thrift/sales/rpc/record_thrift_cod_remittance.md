# RPC: `record_thrift_cod_remittance`

Records courier COD cash on the **same invoice** (`cod_*` + `payment_status`) for an **ACTIVE** online invoice with `payment_status = COD_PENDING`. No separate collection document. Does **not** change `delivery_status` or write PnL.

Permission: `thrift_sales` / remittance action.  
Schema: [../schema.md](../schema.md) · Workflow: [../workflow.md](../workflow.md) §3.

## Behaviour

1. Validate invoice tenant, `ACTIVE`, `COD_PENDING`.  
2. Set `cod_remitted_amount`, `cod_remitted_at`, optional `cod_remittance_ref`.  
3. If remitted ≥ expected (or staff accepts) → `payment_status = PAID`.  
4. Partial / dispute → keep `COD_PENDING` or `WRITTEN_OFF` + notes.  
5. **No** ledger insert. **No** PnL change.

## Call

```ts
await supabase.rpc('record_thrift_cod_remittance', {
  p_tenant_id: tenantId,
  p_invoice_id: invoiceId,
  p_cod_remitted_amount: amount,
  p_cod_remitted_at: iso,
  p_cod_remittance_ref: ref ?? null,
})
```
