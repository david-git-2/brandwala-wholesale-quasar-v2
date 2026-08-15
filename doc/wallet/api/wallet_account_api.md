# Wallet Account API Specification

This document details the direct API operations for the `wallet_accounts` record table.

---

## 1. Fetch Entity Wallet Account

* **Endpoint / Query**: `supabase.from('wallet_accounts').select('*')`

### Query Parameters / Filters
* `tenant_id`: Scope to tenant
* `entity_type`: Target entity classification (`vendor`, `customer`, `courier`, `middleman`, `tenant`, `investor`, `cargo_company`)
* `entity_id`: Primary ID of target entity
* `currency_code`: Currency filter (default `'BDT'`)

### Request Example
```typescript
const { data, error } = await supabase
  .from('wallet_accounts')
  .select('*')
  .eq('tenant_id', 12)
  .eq('entity_type', 'vendor')
  .eq('entity_id', 2)
  .eq('currency_code', 'BDT')
  .maybeSingle();
```

### Response Payload
```json
{
  "id": 14,
  "tenant_id": 12,
  "entity_type": "vendor",
  "entity_id": 2,
  "currency_code": "BDT",
  "available_balance": 15000.00,
  "locked_balance": 2500.00,
  "pending_balance": 0.00,
  "created_at": "2026-08-01T10:00:00Z",
  "updated_at": "2026-08-01T20:11:00Z"
}
```

---

## 2. List Tenant Wallet Accounts

* **Endpoint / Query**: `supabase.from('wallet_accounts').select('*')`

### Query Parameters / Filters
* `tenant_id`: Filter accounts belonging to a tenant
* `entity_type`: Optional filter by entity type

### Request Example
```typescript
const { data, error } = await supabase
  .from('wallet_accounts')
  .select('*')
  .eq('tenant_id', 12)
  .order('updated_at', { ascending: false });
```

### Response Payload
```json
[
  {
    "id": 14,
    "tenant_id": 12,
    "entity_type": "vendor",
    "entity_id": 2,
    "currency_code": "BDT",
    "available_balance": 15000.00,
    "locked_balance": 2500.00,
    "pending_balance": 0.00,
    "created_at": "2026-08-01T10:00:00Z",
    "updated_at": "2026-08-01T20:11:00Z"
  },
  {
    "id": 15,
    "tenant_id": 12,
    "entity_type": "courier",
    "entity_id": 5,
    "currency_code": "BDT",
    "available_balance": 3500.00,
    "locked_balance": 0.00,
    "pending_balance": 1200.00,
    "created_at": "2026-08-01T11:00:00Z",
    "updated_at": "2026-08-01T19:30:00Z"
  }
]
```

---

## 3. Account Bucket State Rules

* **Direct Mutations**: Direct client-side `update` or `insert` calls to `wallet_accounts` are restricted.
* **Atomic RPC Preference**: Mutating balance buckets (`available_balance`, `locked_balance`, `pending_balance`) must be performed via atomic PostgreSQL stored procedures (`record_ledger_transaction` or `transfer_wallet_balance`) to preserve audit history and avoid race conditions.
