# RPC: `create_cargo_company_with_wallet`

Atomically creates a new `cargo_companies` row and provisions its `wallet_accounts` ledger anchor in a single database transaction.

User-created cargo companies are always **non-default** (`is_default = false`). The system default row (`code = 'DEFAULT'`) is owned by [`ensure_default_cargo_company`](../api/cargo_company_api.md#5-ensure-default-cargo-company-rpc) / parent tenant create — do not pass `DEFAULT` as `p_code` for a second row under the same tenant.

---

## 1. APIs Called (Internal Operations)

* [cargo_company_api.md](../api/cargo_company_api.md) — `cargo_companies` insert (`is_default` left at column default `false`)
* `wallet_accounts` insert (`entity_type: 'cargo_company'`, `entity_id: cargo_companies.id`)

---

## 2. Main RPC Call

```typescript
const { data, error } = await supabase.rpc('create_cargo_company_with_wallet', {
  p_tenant_id: 15,
  p_name: 'SkyBridge Freight',
  p_code: 'SKY-BD',
  p_email: 'ops@skybridge.example',
  p_phone: '+880 1711 555555',
  p_address: 'Dhaka Airport Cargo Village',
  p_notes: 'Preferred UK→BD agent',
});
```

---

## 3. Request Payload

```json
{
  "p_tenant_id": 15,
  "p_name": "SkyBridge Freight",
  "p_code": "SKY-BD",
  "p_email": "ops@skybridge.example",
  "p_phone": "+880 1711 555555",
  "p_address": "Dhaka Airport Cargo Village",
  "p_notes": "Preferred UK→BD agent"
}
```

---

## 4. Response Payload

```json
{
  "cargo_company": {
    "id": 5,
    "tenant_id": 15,
    "name": "SkyBridge Freight",
    "code": "SKY-BD",
    "is_default": false,
    "is_active": true,
    "email": "ops@skybridge.example",
    "phone": "+880 1711 555555",
    "address": "Dhaka Airport Cargo Village",
    "notes": "Preferred UK→BD agent",
    "created_at": "2026-08-01T22:00:00Z"
  },
  "wallet": {
    "id": 210,
    "tenant_id": 15,
    "entity_type": "cargo_company",
    "entity_id": 5,
    "currency_code": "BDT",
    "available_balance": 0.00,
    "created_at": "2026-08-01T22:00:00Z"
  }
}
```

---

## Related

* `ensure_default_cargo_company(p_tenant_id)` — system default for parent tenants (shipment create prefill / header fallback).
* Vendor parallel: [`create_vendor_with_wallet`](../../vendor/rpc/create_vendor_with_wallet.md).
