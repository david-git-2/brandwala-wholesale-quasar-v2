# RPC: `transfer_wallet_balance`

Moves funds internally between balance buckets (e.g., `pending` &rarr; `available`, or `available` &rarr; `locked`) for an entity within `wallet_accounts`.

---

## 1. Internal Table Operations

* [wallet_account_api.md](../api/wallet_account_api.md) — `wallet_accounts` balance transfer

---

## 2. Main RPC Call

```typescript
const { data, error } = await supabase.rpc('transfer_wallet_balance', {
  p_tenant_id: 12,
  p_entity_type: 'vendor',
  p_entity_id: 2,
  p_from_bucket: 'pending',
  p_to_bucket: 'available',
  p_amount: 2500.00,
  p_currency_code: 'BDT',
  p_notes: 'Released pending hold after parcel delivery verification',
  p_metadata: {}
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
  "p_from_bucket": "pending",
  "p_to_bucket": "available",
  "p_amount": 2500.00,
  "p_currency_code": "BDT",
  "p_notes": "Released pending hold after parcel delivery verification",
  "p_metadata": {}
}
```

### B. Response Payload
```json
{
  "success": true,
  "entity_type": "vendor",
  "entity_id": 2,
  "transferred_amount": 2500.00,
  "from_bucket": "pending",
  "to_bucket": "available",
  "new_available_balance": 17500.00,
  "new_pending_balance": 0.00
}
```
