# RPC: `get_wallet_entity_statement`

Fetches transactional ledger history for a specific entity with optional date filters, providing opening balance, total credits, total debits, closing balance, and itemized entries.

---

## 1. Internal Table Operations

* [universal_wallet_ledger_api.md](../api/universal_wallet_ledger_api.md) — `universal_wallet_ledger` query & calculation

---

## 2. Main RPC Call

```typescript
const { data, error } = await supabase.rpc('get_wallet_entity_statement', {
  p_tenant_id: 12,
  p_entity_type: 'vendor',
  p_entity_id: 2,
  p_start_date: '2026-08-01',
  p_end_date: '2026-08-31'
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
  "p_start_date": "2026-08-01",
  "p_end_date": "2026-08-31"
}
```

### B. Response Payload
```json
{
  "tenant_id": 12,
  "entity_type": "vendor",
  "entity_id": 2,
  "start_date": "2026-08-01",
  "end_date": "2026-08-31",
  "opening_balance": 15000.00,
  "total_credits": 5000.00,
  "total_debits": 0.00,
  "closing_balance": 20000.00,
  "entries": [
    {
      "id": "f47ac10b-58cc-4372-a567-0e02b2c3d479",
      "tenant_id": 12,
      "entity_type": "vendor",
      "entity_id": 2,
      "type": "credit",
      "amount": 5000.00,
      "currency_code": "BDT",
      "exchange_rate": 1.000000,
      "base_amount": 5000.00,
      "balance_after": 20000.00,
      "source_type": "shipment",
      "source_id": "881",
      "metadata": {
        "reference": "PO-9912",
        "note": "Pay / Settle for inbound shipment"
      },
      "created_at": "2026-08-01T20:11:00Z"
    }
  ]
}
```
