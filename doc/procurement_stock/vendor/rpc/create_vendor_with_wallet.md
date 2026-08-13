# RPC: `create_vendor_with_wallet`

Atomically creates a new vendor record and provisions its corresponding `wallet_accounts` ledger anchor in a single database transaction.

---

## 1. APIs Called (Internal Operations)

* [vendor_api.md](../api/vendor_api.md) — `vendors` insert
* `wallet_accounts` insert (`entity_type: 'vendor'`, `entity_id: vendor.id`)

---

## 2. Main RPC Call

```typescript
const { data, error } = await supabase.rpc('create_vendor_with_wallet', {
  p_tenant_id: 15,
  p_name: "Apex Textiles",
  p_code: "ATS-BD",
  p_market_code: "BD_LOCAL",
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
  "p_market_code": "BD_LOCAL",
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
    "market_code": "BD_LOCAL",
    "currency_id": 1,
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
    "currency_id": 1,
    "available_balance": 0.00,
    "created_at": "2026-08-01T22:00:00Z"
  }
}
```
