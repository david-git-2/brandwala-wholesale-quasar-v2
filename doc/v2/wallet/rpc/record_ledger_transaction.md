# RPC: `record_ledger_transaction`

Atomic PostgreSQL RPC to record a credit/debit entry into `universal_wallet_ledger` and update balance buckets in `wallet_accounts`.

---

## 1. Internal Table Operations

* [universal_wallet_ledger_api.md](../api/universal_wallet_ledger_api.md) — `universal_wallet_ledger` insert
* [wallet_account_api.md](../api/wallet_account_api.md) — `wallet_accounts` balance bucket update / upsert

---

## 2. Main RPC Call

```typescript
const { data, error } = await supabase.rpc('record_ledger_transaction', {
  p_tenant_id: 12,
  p_entity_type: 'vendor',
  p_entity_id: 2,
  p_type: 'credit',
  p_amount: 5000.00,
  p_currency_code: 'BDT',
  p_exchange_rate: 1.000000,
  p_source_type: 'shipment_invoice',
  p_source_id: 'INV-2026-004',
  p_target_bucket: 'available',
  p_metadata: {
    reference: 'PO-9912',
    note: 'Payment received for stock shipment'
  }
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
  "p_type": "credit",
  "p_amount": 5000.00,
  "p_currency_code": "BDT",
  "p_exchange_rate": 1.000000,
  "p_source_type": "shipment_invoice",
  "p_source_id": "INV-2026-004",
  "p_target_bucket": "available",
  "p_metadata": {
    "reference": "PO-9912",
    "note": "Payment received for stock shipment"
  }
}
```

### B. Response Payload
```json
{
  "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
  "tenant_id": 12,
  "entity_type": "vendor",
  "entity_id": 2,
  "type": "credit",
  "amount": 5000.00,
  "base_amount": 5000.00,
  "currency_code": "BDT",
  "exchange_rate": 1.000000,
  "balance_after": 20000.00,
  "source_type": "shipment_invoice",
  "source_id": "INV-2026-004",
  "metadata": {
    "reference": "PO-9912",
    "note": "Payment received for stock shipment"
  },
  "created_at": "2026-08-01T20:11:00Z"
}
```
