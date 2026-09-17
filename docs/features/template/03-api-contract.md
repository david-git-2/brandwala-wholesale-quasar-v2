# [Feature Name] — API Contract & RPC Signatures

> **RPC Functions Target**: `supabase/schemas/<domain>/03_rpcs.sql`  

---

## 1. List / Search RPC: `list_feature_entities`

### Signature
```sql
create or replace function public.list_feature_entities(
  p_tenant_id uuid,
  p_search text default null,
  p_status public.feature_status default null,
  p_limit int default 50,
  p_offset int default 0
)
returns table (
  id uuid,
  title text,
  status public.feature_status,
  created_at timestamptz,
  total_count bigint
)
language plpgsql
security invoker
as $$
...
$$;
```

---

## 2. Mutation RPC: `create_or_update_feature_entity`

### Input Payload Schema
```json
{
  "tenant_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "title": "Batch Operations Alpha",
  "status": "active",
  "items": [
    { "sku": "SKU-001", "quantity": 10 }
  ]
}
```

### Success Response (`200 OK`)
```json
{
  "success": true,
  "data": {
    "id": "7ca85f64-5717-4562-b3fc-2c963f66afb2",
    "status": "active"
  }
}
```
