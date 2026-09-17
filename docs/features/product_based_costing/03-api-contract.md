# Product-Based Costing (PBC) — API Contract & RPC Signatures

> **RPC Functions Target**: Costing File Generation, Formula Recalculation & Backlog Sync  
> **Security Level**: `SECURITY DEFINER`

---

## 1. File Creation RPC: `create_costing_file`

Initializes a new costing file with customer group binding, FX parameters, and line items.

### Signature
```sql
create or replace function public.create_costing_file(
  p_tenant_id uuid,
  p_customer_group_id uuid,
  p_title text,
  p_base_currency text default 'GBP',
  p_fx_rate numeric default 154.50,
  p_markup_percentage numeric default 0.18,
  p_items jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql security definer;
```

---

## 2. Backlog Listing RPC: `list_pbc_backlog_items`

Retrieves unconsumed backlog shortfall items for a specific customer billing profile.

### Signature
```sql
create or replace function public.list_pbc_backlog_items(
  p_billing_profile_id uuid
)
returns table (
  id uuid,
  product_id uuid,
  product_name text,
  backlog_quantity numeric,
  source_file_id uuid,
  created_at timestamptz
)
language plpgsql security definer;
```

---

## 3. Backlog Import RPC: `add_pbc_backlog_to_file`

Consumes backlog items into an active costing file draft and marks them as consumed.

### Signature
```sql
create or replace function public.add_pbc_backlog_to_file(
  p_costing_file_id uuid,
  p_backlog_item_ids uuid[]
)
returns jsonb
language plpgsql security definer;
```
