# Universal Wallet Ledger API Specification

This document details the direct API operations for the immutable `universal_wallet_ledger` audit log.

---

## 1. List Entity Ledger Entries (Paginated)

* **Endpoint / Query**: `supabase.from('universal_wallet_ledger').select('*')`

### Query Parameters / Filters
* `tenant_id`: Scope to tenant
* `entity_type`: Target entity classification (`vendor`, `customer`, `courier`, `middleman`, `tenant`, `investor`)
* `entity_id`: Primary ID of target entity
* `source_type`: Filter by transaction source (e.g., `shop_order`, `vendor_purchase`, `shipment`, `sales_invoice`, `sales_invoice_return`, `payout`, `adjustment`, `bucket_transfer`)
* `limit` / `offset`: Pagination parameters

### Request Example
```typescript
const { data, error } = await supabase
  .from('universal_wallet_ledger')
  .select('*')
  .eq('tenant_id', 12)
  .eq('entity_type', 'vendor')
  .eq('entity_id', 2)
  .order('created_at', { ascending: false })
  .order('id', { ascending: false })
  .range(0, 19);
```

### Response Payload
```json
[
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
]
```

---

## 2. Fetch Latest Entity Running Balance

* **Endpoint / Query**: `supabase.from('universal_wallet_ledger').select('balance_after')`

### Query Parameters / Filters
* `tenant_id`: Scope to tenant
* `entity_type`: Target entity classification
* `entity_id`: Target entity ID

### Request Example
```typescript
const { data, error } = await supabase
  .from('universal_wallet_ledger')
  .select('balance_after')
  .eq('tenant_id', 12)
  .eq('entity_type', 'vendor')
  .eq('entity_id', 2)
  .order('created_at', { ascending: false })
  .order('id', { ascending: false })
  .limit(1)
  .maybeSingle();
```

### Response Payload
```json
{
  "balance_after": 20000.00
}
```

---

## 3. Immutability & Audit Safeguards

* **No Update / Delete**: `universal_wallet_ledger` entries are strictly immutable. Update and Delete operations are blocked to guarantee audit compliance and double-entry accounting integrity.
* **RPC Execution**: Insertions should be performed via `record_ledger_transaction` RPC to ensure target balance buckets in `wallet_accounts` are synchronously updated.
