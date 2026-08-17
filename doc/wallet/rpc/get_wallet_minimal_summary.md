# RPC: `get_wallet_minimal_summary`

Fetches a highly simplified financial summary for an entity. This is the "Presentation Engine" layer that abstracts away the complex 3-bucket wallet and double-entry ledger into four plain-English metrics for the frontend user interface.

---

## 1. Internal Operations

This RPC aggregates data from:
* `wallet_accounts` (for current available and pending balances)
* `universal_wallet_ledger` (to calculate recent spending over a specified timeframe)
* Optionally queries unpaid invoices/adjustments to calculate outstanding dues.

---

## 2. Main RPC Call

```typescript
const { data, error } = await supabase.rpc('get_wallet_minimal_summary', {
  p_tenant_id: 12,
  p_entity_type: 'vendor',
  p_entity_id: 2,
  p_currency_code: 'BDT',
  p_spend_days_lookback: 30 // E.g., 'What I spent in the last 30 days'
});
```

---

## 3. Payloads

### A. Request Payload
```json
{
  "p_tenant_id": 12,
  "p_entity_type": "vendor",
  "p_entity_id": 2,
  "p_currency_code": "BDT",
  "p_spend_days_lookback": 30
}
```

### B. Response Payload (The "Minimal View")
```json
{
  "tenant_id": 12,
  "entity_type": "vendor",
  "entity_id": 2,
  "currency_code": "BDT",
  
  "available_to_withdraw": 15000.00,  // "What I Have" (Mapped from available_balance)
  "incoming_funds": 2500.00,          // "What I Will Get" (Mapped from pending_balance + locked_balance)
  "recent_spend": 4500.00,            // "What I Spent" (Sum of debits in the last 30 days)
  "outstanding_dues": 0.00            // "What I Owe" (Sum of unpaid platform invoices or negative adjustments)
}
```
