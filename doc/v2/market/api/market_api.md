# Market API Specification

This document details the read-only REST & RPC query operations for `markets`.

> **Read-Only API**: Mutation endpoints (`INSERT`, `UPDATE`, `DELETE`) are intentionally omitted as markets are system reference data.

---

## 1. List / Query Markets

Fetch all active system markets or filter by active status.

* **Endpoint / Query**: `supabase.from('markets').select('*')`

### Query Parameters & Filters
* `is_active`: Filter active markets (`true`/`false`)
* `region`: Filter by geographic region (e.g. `ASIA`, `EUROPE`)

### Request Example (TypeScript)
```typescript
const { data, error } = await supabase
  .from('markets')
  .select('*')
  .eq('is_active', true)
  .order('name', { ascending: true });
```

### Response Payload
```json
[
  {
    "id": 1,
    "code": "BD_LOCAL",
    "name": "Bangladesh Local Market",
    "region": "ASIA",
    "is_active": true,
    "is_system": true,
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:00:00Z"
  },
  {
    "id": 2,
    "code": "UK_MARKET",
    "name": "United Kingdom Market",
    "region": "EUROPE",
    "is_active": true,
    "is_system": true,
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:00:00Z"
  }
]
```

---

## 2. Specific Query (Fetch by Code or ID)

Fetch detailed information for a single market using unique identifier `code` or `id`.

* **Endpoint / Query**: `supabase.from('markets').select('*').eq('code', 'BD_LOCAL').single()`

### Request Example (By Code)
```typescript
const { data, error } = await supabase
  .from('markets')
  .select('*')
  .eq('code', 'BD_LOCAL')
  .single();
```

### Response Payload
```json
{
  "id": 1,
  "code": "BD_LOCAL",
  "name": "Bangladesh Local Market",
  "region": "ASIA",
  "is_active": true,
  "is_system": true,
  "created_at": "2026-01-01T00:00:00Z",
  "updated_at": "2026-01-01T00:00:00Z"
}
```

---

## 3. List Vendor Markets (RPC)

Custom RPC function to query active markets linked or configured for vendor operations.

* **RPC Function**: `list_vendor_markets`

### Request Example (TypeScript)
```typescript
const { data, error } = await supabase
  .rpc('list_vendor_markets');
```

### Response Payload
```json
[
  {
    "code": "BD_LOCAL",
    "name": "Bangladesh Local Market",
    "region": "ASIA"
  },
  {
    "code": "UK_MARKET",
    "name": "United Kingdom Market",
    "region": "EUROPE"
  }
]
```
