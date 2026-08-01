# Global Reference API Specification

This document details the read-only REST & RPC query operations for Global Reference catalogs (`markets`, `global_currencies`, `payment_methods`, and `units_of_measure`).

> **Read-Only API**: Mutation endpoints (`INSERT`, `UPDATE`, `DELETE`) are intentionally omitted as global reference entities are system-managed lookup data.

---

## 1. Markets APIs

### 1.1 List Markets
Fetch all active system markets or filter by active status/region.

* **Endpoint / Query**: `supabase.from('markets').select('*')`

#### Request Example (TypeScript)
```typescript
const { data, error } = await supabase
  .from('markets')
  .select('*')
  .order('code', { ascending: true });
```

#### Response Payload
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
  }
]
```

### 1.2 Get Market by ID / Code
Fetch detailed information for a single market using `id` or `code`.

```typescript
// By ID
const { data, error } = await supabase
  .from('markets')
  .select('*')
  .eq('id', id)
  .maybeSingle();

// By Code
const { data, error } = await supabase
  .from('markets')
  .select('*')
  .eq('code', code)
  .maybeSingle();
```

### 1.3 List Vendor Markets (RPC)
Custom RPC function to query active markets linked or configured for vendor operations.

* **RPC Function**: `list_vendor_markets`

```typescript
const { data, error } = await supabase.rpc('list_vendor_markets');
```

---

## 2. Global Currencies APIs

### 2.1 List Currencies
Fetch all supported transaction currencies.

* **Endpoint / Query**: `supabase.from('global_currencies').select('*')`

#### Request Example (TypeScript)
```typescript
const { data, error } = await supabase
  .from('global_currencies')
  .select('*')
  .order('code', { ascending: true });
```

#### Response Payload
```json
[
  {
    "id": 1,
    "code": "BDT",
    "name": "Bangladeshi Taka",
    "symbol": "৳",
    "country": "Bangladesh",
    "is_active": true,
    "is_system": true,
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:00:00Z"
  }
]
```

### 2.2 Get Currency by ID / Code
Fetch detailed currency by `id` or `code`.

```typescript
// By ID
const { data, error } = await supabase
  .from('global_currencies')
  .select('*')
  .eq('id', id)
  .maybeSingle();

// By Code
const { data, error } = await supabase
  .from('global_currencies')
  .select('*')
  .eq('code', code)
  .maybeSingle();
```

---

## 3. Payment Methods APIs

### 3.1 List Payment Methods
Fetch all system-supported payment methods.

* **Endpoint / Query**: `supabase.from('payment_methods').select('*')`

#### Request Example (TypeScript)
```typescript
const { data, error } = await supabase
  .from('payment_methods')
  .select('*')
  .order('sort_order', { ascending: true });
```

#### Response Payload
```json
[
  {
    "id": 1,
    "code": "BKASH",
    "name": "bKash Mobile Wallet",
    "category": "bd_mobile_wallet",
    "scope": "bd",
    "sort_order": 1,
    "is_active": true,
    "is_system": true,
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:00:00Z"
  }
]
```

### 3.2 Get Payment Method by ID
Fetch payment method details by `id`.

```typescript
const { data, error } = await supabase
  .from('payment_methods')
  .select('*')
  .eq('id', id)
  .maybeSingle();
```

---

## 4. Units of Measure APIs

### 4.1 List Units of Measure
Fetch standard system units of measure.

* **Endpoint / Query**: `supabase.from('units_of_measure').select('*')`

#### Request Example (TypeScript)
```typescript
const { data, error } = await supabase
  .from('units_of_measure')
  .select('*')
  .order('sort_order', { ascending: true });
```

#### Response Payload
```json
[
  {
    "id": 1,
    "code": "KG",
    "name": "Kilogram",
    "unit_type": "weight",
    "symbol": "kg",
    "sort_order": 1,
    "is_active": true,
    "is_system": true,
    "created_at": "2026-01-01T00:00:00Z",
    "updated_at": "2026-01-01T00:00:00Z"
  }
]
```

### 4.2 Get Unit of Measure by ID
Fetch single unit of measure by `id`.

```typescript
const { data, error } = await supabase
  .from('units_of_measure')
  .select('*')
  .eq('id', id)
  .maybeSingle();
```
