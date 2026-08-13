# RPC: `get_wallet_account_balances`

Fetches current 3-bucket balance metrics (`available_balance`, `locked_balance`, `pending_balance`, `total_balance`) for a specific entity.

---

## 1. Internal Table Operations

* [wallet_account_api.md](../api/wallet_account_api.md) — `wallet_accounts` read / initialization

---

## 2. Main RPC Call

```typescript
const { data, error } = await supabase.rpc('get_wallet_account_balances', {
  p_tenant_id: 12,
  p_entity_type: 'vendor',
  p_entity_id: 2,
  p_currency_code: 'BDT'
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
  "p_currency_code": "BDT"
}
```

### B. Response Payload
```json
{
  "tenant_id": 12,
  "entity_type": "vendor",
  "entity_id": 2,
  "currency_code": "BDT",
  "available_balance": 15000.00,
  "locked_balance": 2500.00,
  "pending_balance": 0.00,
  "total_balance": 17500.00
}
```
