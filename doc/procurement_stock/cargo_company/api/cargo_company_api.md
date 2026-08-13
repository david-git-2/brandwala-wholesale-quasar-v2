# Cargo Company API Specification

Direct REST / Supabase API operations for `cargo_companies`.

Schema: [../schema.md](../schema.md)

---

## 1. Create Cargo Company (Direct Insert)

* **Endpoint / Query**: `supabase.from('cargo_companies').insert(payload)`
> **Note**: For atomic creation of Cargo Company + Wallet in 1 step, use [`create_cargo_company_with_wallet`](../rpc/create_cargo_company_with_wallet.md) RPC instead.
> User-created rows must leave `is_default = false` (column default). Do not insert a second default; use `ensure_default_cargo_company` for the system row.

### Request Payload
```json
{
  "tenant_id": 15,
  "name": "SkyBridge Freight",
  "code": "SKY-BD",
  "phone": "+880 1711 555555",
  "email": "ops@skybridge.example",
  "address": "Dhaka Airport Cargo Village",
  "notes": "Preferred UK→BD agent"
}
```

### Response Payload
```json
{
  "id": 5,
  "tenant_id": 15,
  "name": "SkyBridge Freight",
  "code": "SKY-BD",
  "is_default": false,
  "is_active": true,
  "phone": "+880 1711 555555",
  "email": "ops@skybridge.example",
  "address": "Dhaka Airport Cargo Village",
  "notes": "Preferred UK→BD agent",
  "wallet_entity_id": null,
  "created_at": "2026-08-01T22:00:00Z",
  "updated_at": "2026-08-01T22:00:00Z"
}
```

---

## 2. Update Cargo Company

* **Endpoint / Query**: `supabase.from('cargo_companies').update(payload).eq('id', 5)`

### Request Payload (Partial Update)
```json
{
  "name": "SkyBridge Freight Ltd",
  "phone": "+880 1711 444444"
}
```

### Response Payload
```json
{
  "id": 5,
  "tenant_id": 15,
  "name": "SkyBridge Freight Ltd",
  "code": "SKY-BD",
  "is_default": false,
  "is_active": true,
  "phone": "+880 1711 444444",
  "updated_at": "2026-08-01T22:10:00Z"
}
```

> Do not flip `is_default` via client update except through `ensure_default_cargo_company` / controlled ops. At most one default per tenant.

---

## 3. Delete Cargo Company

* **Endpoint / Query**: `supabase.from('cargo_companies').delete().eq('id', 5)`

### Request
* Parameter: `id = 5`

### Response Payload
```json
{
  "success": true,
  "deleted_id": 5
}
```

### Safety & Deletion Rules
* **Default**: Never delete rows with `is_default = true` or `code = 'DEFAULT'` — required for shipment create prefill / header fallback.
* **Zero Balance**: Associated `wallet_accounts` record may be deleted (`ON DELETE CASCADE`) if `available_balance = 0`.
* **Non-Zero Balance**: Deletion is **blocked** if `available_balance > 0` to prevent loss of financial trail.
* **Shipments**: Live FK is `ON DELETE SET NULL` on `global_shipments.cargo_company_id`.

---

## 4. List / Query Cargo Companies

* **Endpoint / Query**: `supabase.from('cargo_companies').select('*')`

### Query Parameters / Filters
* `tenant_id` / parent scope: Scope by owning parent
* `is_active`: Hide inactive in pickers (`eq('is_active', true)`)
* `is_default`: Filter system default (`eq('is_default', true)` for create-dialog prefill)

### Request Example
```typescript
const { data, error } = await supabase
  .from('cargo_companies')
  .select('*')
  .eq('tenant_id', 15)
  .eq('is_active', true)
  .order('name', { ascending: true });

// Prefill default for shipment create
const { data: defaultCargo } = await supabase
  .from('cargo_companies')
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
    "name": "Default Cargo Company",
    "code": "DEFAULT",
    "is_default": true,
    "is_active": true,
    "created_at": "2026-08-01T21:00:00Z",
    "updated_at": "2026-08-01T21:00:00Z"
  },
  {
    "id": 5,
    "tenant_id": 15,
    "name": "SkyBridge Freight Ltd",
    "code": "SKY-BD",
    "is_default": false,
    "is_active": true,
    "phone": "+880 1711 444444",
    "email": "ops@skybridge.example",
    "address": "Dhaka Airport Cargo Village",
    "created_at": "2026-08-01T22:00:00Z",
    "updated_at": "2026-08-01T22:10:00Z"
  }
]
```

---

## 5. Ensure default cargo company (RPC)

```typescript
const { data: cargoCompanyId, error } = await supabase.rpc('ensure_default_cargo_company', {
  p_tenant_id: 15,
});
```

Idempotent. Parent tenants only. See [workflow_flow.md](../workflow_flow.md) Stage 0.
