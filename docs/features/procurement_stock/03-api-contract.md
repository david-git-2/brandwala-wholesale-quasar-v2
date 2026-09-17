# Procurement & Stock — API Contract & RPC Signatures

> **RPC Functions Target**: `supabase/schemas/procurement/03_rpcs.sql`  
> **Security Level**: `SECURITY DEFINER` with staff membership check

---

## 1. List / Search RPC: `list_global_shipments_paginated`

Consolidated single RPC to retrieve active or archived shipments, embedding vendor, cargo, progress tag info, and archived totals in a single network roundtrip.

### Signature
```sql
create or replace function public.list_global_shipments_paginated(
  p_tenant_id uuid,
  p_is_archived boolean default false,
  p_search text default null,
  p_status public.global_shipment_status default null,
  p_vendor_id uuid default null,
  p_limit int default 25,
  p_offset int default 0
)
returns table (
  id uuid,
  shipment_no text,
  status public.global_shipment_status,
  vendor_id uuid,
  vendor_name text,
  vendor_code text,
  cargo_company_name text,
  progress_tag_name text,
  progress_tag_color text,
  costs_locked boolean,
  is_archived boolean,
  total_weight_kg numeric,
  landed_cost_total_bdt numeric,
  items_count bigint,
  created_at timestamptz,
  total_count bigint,
  archived_total bigint
)
language plpgsql security definer;
```

---

## 2. Inbound Finalization RPC: `finalize_global_shipment`

Executes the physical receiving checklist, stamps final landed unit costs on line items, and creates `global_stocks` rows in the warehouse pool.

### Input Payload Schema
```json
{
  "shipment_id": "7fa85f64-5717-4562-b3fc-2c963f66af10",
  "default_location_id": "9ca85f64-5717-4562-b3fc-2c963f66af22",
  "received_items": [
    {
      "shipment_item_id": "3ba85f64-5717-4562-b3fc-2c963f66af33",
      "received_quantity": 500,
      "location_id": "9ca85f64-5717-4562-b3fc-2c963f66af22",
      "condition_grade": "sellable"
    }
  ]
}
```

### Success Response (`200 OK`)
```json
{
  "success": true,
  "data": {
    "shipment_id": "7fa85f64-5717-4562-b3fc-2c963f66af10",
    "status": "received",
    "stocks_created_count": 38,
    "total_landed_cost_bdt": 540200.00
  }
}
```

---

## 3. Books Lock RPC: `lock_global_shipment_costs`

Freezes landed cost calculations, preventing any further edits to line prices, weight entries, or freight charges.

### Signature
```sql
create or replace function public.lock_global_shipment_costs(
  p_shipment_id uuid
)
returns jsonb
language plpgsql security definer;
```

---

## 4. Archiving Governance RPCs

### 4.1 Archive Shipment: `archive_shipment`
```sql
create or replace function public.archive_shipment(
  p_shipment_id uuid
)
returns jsonb
language plpgsql security definer;
```

### 4.2 Unarchive / Restore: `unarchive_shipment`
```sql
create or replace function public.unarchive_shipment(
  p_shipment_id uuid
)
returns jsonb
language plpgsql security definer;
```

### 4.3 Permanent Purge (Draft/Cancelled Only): `purge_archived_shipment`
```sql
create or replace function public.purge_archived_shipment(
  p_shipment_id uuid
)
returns jsonb
language plpgsql security definer;
```
*(Fails with error `CANNOT_PURGE_COMMITTED_SHIPMENT` if status is `in_transit` or `received`).*

---

## 5. Stock Movement RPC: `create_and_post_stock_movement`

```sql
create or replace function public.create_and_post_stock_movement(
  p_tenant_id uuid,
  p_stock_id uuid,
  p_movement_type public.stock_movement_type,
  p_quantity numeric,
  p_to_location_id uuid default null,
  p_to_availability public.stock_availability default null,
  p_notes text default null
)
returns jsonb
language plpgsql security definer;
```
