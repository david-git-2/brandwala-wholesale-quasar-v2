# RPC: `record_ledger_transaction`

Atomic PostgreSQL RPC to record a credit/debit entry into `universal_wallet_ledger` and update balance buckets in `wallet_accounts`.

---

## 1. Internal Table Operations

* [universal_wallet_ledger_api.md](../api/universal_wallet_ledger_api.md) — `universal_wallet_ledger` insert
* [wallet_account_api.md](../api/wallet_account_api.md) — `wallet_accounts` balance bucket update / upsert

> **Concurrency Note**: To ensure accurate calculation in a high-concurrency environment (e.g., simultaneous payments to the same entity), the underlying PostgreSQL function MUST use a row-level lock (`SELECT ... FOR UPDATE`) when fetching the current balance from `wallet_accounts`. Alternatively, use an atomic mathematical increment/decrement directly in the update statement (e.g., `UPDATE wallet_accounts SET available_balance = available_balance + p_amount`).

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
  p_source_type: 'shipment',
  p_source_id: '881',
  p_target_bucket: 'available',
  p_metadata: {
    reference: 'PO-9912',
    note: 'Pay / Settle for inbound shipment'
  }
});
```

Desk sales Pay / allocate (billing profile / customer entity):

```typescript
const { data, error } = await supabase.rpc('record_ledger_transaction', {
  p_tenant_id: 12,
  p_entity_type: 'customer',
  p_entity_id: 44,
  p_type: 'credit',
  p_amount: 12000.00,
  p_currency_code: 'BDT',
  p_exchange_rate: 1.000000,
  p_source_type: 'sales_invoice',
  p_source_id: '90210',
  p_target_bucket: 'available',
  p_metadata: {
    invoice_no: 'SI-2026-0042',
    note: 'Collection against desk sales invoice'
  }
});
```

`source_type` for desk sales is locked: `sales_invoice` / `sales_invoice_return` — see [../schema.md](../schema.md) · [../../invoice/schema.md](../../invoice/schema.md) §5.2. Do **not** post wallet on invoice post (stub-skip).

---

## 3. Payloads

### A. Request Payload (shipment Pay / Settle)
```json
{
  "p_tenant_id": 12,
  "p_entity_type": "vendor",
  "p_entity_id": 2,
  "p_type": "credit",
  "p_amount": 5000.00,
  "p_currency_code": "BDT",
  "p_exchange_rate": 1.000000,
  "p_source_type": "shipment",
  "p_source_id": "881",
  "p_target_bucket": "available",
  "p_metadata": {
    "reference": "PO-9912",
    "note": "Pay / Settle for inbound shipment"
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
  "source_type": "shipment",
  "source_id": "881",
  "metadata": {
    "reference": "PO-9912",
    "note": "Pay / Settle for inbound shipment"
  },
  "created_at": "2026-08-01T20:11:00Z"
}
```
