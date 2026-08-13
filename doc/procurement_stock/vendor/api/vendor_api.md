# Vendor API Specification

This document details the direct REST / Supabase API operations for managing `vendors`.

---

## 1. Create Vendor (Direct Insert)

* **Endpoint / Query**: `supabase.from('vendors').insert(payload)`
> **Note**: For atomic creation of Vendor + Wallet in 1 step, use [`create_vendor_with_wallet`](../rpc/create_vendor_with_wallet.md) RPC instead.
> User-created vendors must leave `is_default = false` (column default). Do not insert a second default; use `ensure_default_vendor` for the system row.

### Request Payload
```json
{
  "tenant_id": 15,
  "name": "Apex Textiles",
  "code": "ATS-BD",
  "market_code": "BD",
  "email": "info@apextextiles.com",
  "phone": "+880 1711 999999",
  "address": "Dhaka, Bangladesh",
  "website": "https://apextextiles.com"
}
```

### Response Payload
```json
{
  "id": 2,
  "tenant_id": 15,
  "name": "Apex Textiles",
  "code": "ATS-BD",
  "market_code": "BD",
  "is_default": false,
  "email": "info@apextextiles.com",
  "phone": "+880 1711 999999",
  "address": "Dhaka, Bangladesh",
  "website": "https://apextextiles.com",
  "created_at": "2026-08-01T22:00:00Z",
  "updated_at": "2026-08-01T22:00:00Z"
}
```

---

## 2. Update Vendor

* **Endpoint / Query**: `supabase.from('vendors').update(payload).eq('id', 2)`

### Request Payload (Partial Update)
```json
{
  "name": "Apex Textiles Ltd",
  "phone": "+880 1711 888888"
}
```

### Response Payload
```json
{
  "id": 2,
  "tenant_id": 15,
  "name": "Apex Textiles Ltd",
  "code": "ATS-BD",
  "market_code": "BD",
  "is_default": false,
  "email": "info@apextextiles.com",
  "phone": "+880 1711 888888",
  "updated_at": "2026-08-01T22:10:00Z"
}
```

> Do not flip `is_default` via client update except through `ensure_default_vendor` / controlled ops. At most one default per tenant.

---

## 3. Delete Vendor

* **Endpoint / Query**: `supabase.from('vendors').delete().eq('id', 2)`

### Request
* Parameter: `id = 2`

### Response Payload
```json
{
  "success": true,
  "deleted_id": 2
}
```

### Safety & Deletion Rules:
* **Default vendor**: Never delete rows with `is_default = true` or `code = 'DEFAULT'` — required for shipment create prefill / header fallback.
* **Zero Balance**: Associated `wallet_accounts` record is deleted automatically (`ON DELETE CASCADE`) if `available_balance = 0`.
* **Non-Zero Balance**: Deletion is **blocked** by database foreign key/trigger constraints if `available_balance > 0` to prevent loss of financial trail.

---

## 4. List / Query Vendors

* **Endpoint / Query**: `supabase.from('vendors').select('*')`

### Query Parameters / Filters
* `tenant_id`: Scope by tenant ID
* `market_code`: Filter by market (e.g. `BD`, `GB`)
* `is_default`: Filter system default (`eq('is_default', true)` for create-dialog prefill)

### Request Example
```typescript
const { data, error } = await supabase
  .from('vendors')
  .select('*')
  .eq('tenant_id', 15)
  .order('name', { ascending: true });

// Prefill default for shipment create
const { data: defaultVendor } = await supabase
  .from('vendors')
  .select('*')
  .eq('tenant_id', 15)
  .eq('is_default', true)
  .maybeSingle();
```

### Response Payload
```json
[
  {
    "id": 1,
    "tenant_id": 15,
    "name": "Default Vendor",
    "code": "DEFAULT",
    "market_code": "GB",
    "is_default": true,
    "created_at": "2026-08-01T21:00:00Z",
    "updated_at": "2026-08-01T21:00:00Z"
  },
  {
    "id": 2,
    "tenant_id": 15,
    "name": "Apex Textiles Ltd",
    "code": "ATS-BD",
    "market_code": "BD",
    "is_default": false,
    "email": "info@apextextiles.com",
    "phone": "+880 1711 888888",
    "address": "Dhaka, Bangladesh",
    "website": "https://apextextiles.com",
    "created_at": "2026-08-01T22:00:00Z",
    "updated_at": "2026-08-01T22:10:00Z"
  }
]
```

---

## 5. Ensure default vendor (RPC)

```typescript
const { data: vendorId, error } = await supabase.rpc('ensure_default_vendor', {
  p_tenant_id: 15,
});
```

Idempotent. Parent tenants only. See [workflow_flow.md](../workflow_flow.md) Stage 0.
