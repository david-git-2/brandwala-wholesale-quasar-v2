# RPC: `create_vendor_with_wallet`

Atomically creates a new vendor record and provisions its corresponding `wallet_accounts` ledger anchor in a single database transaction.

User-created vendors are always **non-default** (`is_default = false`). The system default row (`code = 'DEFAULT'`) is owned by [`ensure_default_vendor`](../api/vendor_api.md#5-ensure-default-vendor-rpc) / parent tenant create — do not pass `DEFAULT` as `p_code` for a second vendor under the same tenant.

---

## 1. APIs Called (Internal Operations)

* [vendor_api.md](../api/vendor_api.md) — `vendors` insert (`is_default` left at column default `false`)
* `wallet_accounts` insert (`entity_type: 'vendor'`, `entity_id: vendor.id`)

---

## 2. Main RPC Call

```typescript
const { data, error } = await supabase.rpc('create_vendor_with_wallet', {
  p_tenant_id: 15,
  p_name: "Apex Textiles",
  p_code: "ATS-BD",
  p_market_code: "BD",
  p_email: "info@apextextiles.com",
  p_phone: "+880 1711 999999",
  p_address: "Dhaka, Bangladesh",
  p_website: "https://apextextiles.com"
});
```

---

## 3. Request Payload

```json
{
  "p_tenant_id": 15,
  "p_name": "Apex Textiles",
  "p_code": "ATS-BD",
  "p_market_code": "BD",
  "p_email": "info@apextextiles.com",
  "p_phone": "+880 1711 999999",
  "p_address": "Dhaka, Bangladesh",
  "p_website": "https://apextextiles.com"
}
```

---

## 4. Response Payload

```json
{
  "vendor": {
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
    "created_at": "2026-08-01T22:00:00Z"
  },
  "wallet": {
    "id": 102,
    "tenant_id": 15,
    "entity_type": "vendor",
    "entity_id": 2,
    "currency_code": "BDT",
    "available_balance": 0.00,
    "created_at": "2026-08-01T22:00:00Z"
  }
}
```

---

## Related

* `ensure_default_vendor(p_tenant_id)` — system default vendor for parent tenants (shipment create prefill / header fallback).
