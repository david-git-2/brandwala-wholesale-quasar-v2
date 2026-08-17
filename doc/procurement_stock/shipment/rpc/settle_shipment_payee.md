# RPC: `settle_shipment_payee`

Per-payee wallet post after the shipment is **`received`**. One action, one amount. **Not** bulk settle of cost-entry rows (`pay_settle_shipment_costs` retired from UI).

```typescript
const { data, error } = await supabase.rpc('settle_shipment_payee', {
  p_shipment_id: 881,
  p_entity_type: 'vendor', // or 'cargo_company'
  p_entity_id: 12,
  p_action: 'pay', // 'pay' | 'record_credit' | 'use_credit'
  p_amount: 500,
  p_exchange_rate: 124.5, // optional; else first matching cost-entry FX
});
// { success: true, action: 'pay', amount_bdt: 62250, ledger: { ... } }
```

| Action | Tenant available | Payee available |
| :--- | :--- | :--- |
| `pay` | Debit (tenant `available_balance` may go negative) | Unchanged |
| `record_credit` | Unchanged | Credit (short delivery / store credit) |
| `use_credit` | Unchanged | Debit (must have balance) |

Ledger: `source_type = 'shipment'`, `source_id =` shipment id. Multiple posts per shipment are allowed.

List this-shipment totals: `list_shipment_payee_settlements(p_shipment_id)`.

Status ≠ `received` → error. Payee must match shipment header vendor / cargo company.
