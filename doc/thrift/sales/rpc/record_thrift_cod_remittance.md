# RPC: `record_thrift_cod_remittance`

Records courier COD cash on the **same invoice** (`cod_*` + `payment_status`) for an **ACTIVE** invoice with `payment_status = COD_PENDING`. Write-off uses this same RPC (`p_outcome = WRITTEN_OFF`). No separate collection document. Does **not** change `delivery_status`, fees, `cod_expected`, lines, or write PnL / ledger.

Permission: `thrift_sales` `edit` or `create`.  
Schema: [../schema.md](../schema.md) · Workflow: [../workflow.md](../workflow.md) §3.

## Behaviour

1. Validate invoice tenant, `sale_channel = ONLINE`, `status = ACTIVE`, `payment_status = COD_PENDING`; remitted amount ≥ `0`.  
2. Resolve `p_outcome`:
   - Explicit: `PAID` \| `KEEP_PENDING` \| `WRITTEN_OFF`
   - Omitted / empty: remitted ≥ `cod_expected` (or `cod_expected` null) → `PAID`; else `KEEP_PENDING`
3. Set `cod_remitted_amount` (**replace**, not accumulate), `cod_remitted_at`, optional `cod_remittance_ref`.  
4. Map outcome → `payment_status`: `PAID` / stay `COD_PENDING` / `WRITTEN_OFF`.  
5. Optional `p_notes` appends to invoice `notes` (does not replace). **Required** when outcome is `WRITTEN_OFF`.  
6. **No** ledger insert. **No** PnL change. **No** mutation of delivery / fees / `cod_expected` / lines.

Staff may choose `PAID` when remitted &lt; `cod_expected` (accept shortfall). Do not rewrite `cod_expected` to force a match.

## Call

```ts
await supabase.rpc('record_thrift_cod_remittance', {
  p_tenant_id: tenantId,
  p_invoice_id: invoiceId,
  p_remitted_amount: amount,
  p_actor: actor,
  p_remitted_at: iso ?? null,
  p_remittance_ref: ref ?? null,
  p_notes: notes ?? null,
  p_outcome: 'PAID' | 'KEEP_PENDING' | 'WRITTEN_OFF' | null,
})
```

## Returns (JSONB)

| Key | Meaning |
| :--- | :--- |
| `invoice_id` | Invoice id |
| `payment_status` | Resulting payment status |
| `cod_expected` | Unchanged expected |
| `cod_remitted_amount` | Amount just written |
| `outcome` | Resolved outcome |
