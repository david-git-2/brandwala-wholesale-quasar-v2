# Wallet & receipts — API contract

Target: **one receipt RPC** (source = cash / bank / store credit / courier remittance) then allocations + ledger. Live collect/remittance RPCs still differ — [00-gaps](00-gaps.md) WA4.

Ledger list/detail below. Bodies: `public.sql` until wallet schema split. Payments live: `create_billing_profile_payment_with_allocations` (wholesale); dropship remittance RPCs in `supabase/schemas/shop_order/03_rpcs.sql`.

## 1. Directory Listing RPC: `list_wallet_entities_for_staff`

Retrieves all entities of a specified type with their primary currency balances, search filtering, and pagination.

### Signature
```sql
create or replace function public.list_wallet_entities_for_staff(
  p_tenant_id uuid,
  p_entity_type public.wallet_entity_type,
  p_search text default null,
  p_limit int default 50,
  p_offset int default 0
)
returns table (
  entity_id uuid,
  entity_name text,
  entity_code text,
  phone text,
  currency_code text,
  current_balance numeric,
  unsettled_balance numeric,
  last_transaction_at timestamptz,
  total_count bigint
)
language plpgsql security definer;
```

---

## 2. Wallet Detail & Balances RPC: `get_wallet_detail_for_staff`

Fetches detailed balances across all active currencies for a single entity.

### Signature
```sql
create or replace function public.get_wallet_detail_for_staff(
  p_tenant_id uuid,
  p_entity_type public.wallet_entity_type,
  p_entity_id uuid
)
returns jsonb
language plpgsql security definer;
```

---

## 3. Ledger History RPC: `list_wallet_ledger_for_staff`

Retrieves the paginated, chronological transaction log for an entity wallet with operating tenant attribution.

### Signature
```sql
create or replace function public.list_wallet_ledger_for_staff(
  p_tenant_id uuid,
  p_entity_type public.wallet_entity_type,
  p_entity_id uuid,
  p_currency_code text default 'BDT',
  p_limit int default 50,
  p_offset int default 0
)
returns table (
  id uuid,
  entry_direction public.ledger_entry_direction,
  amount numeric,
  balance_before numeric,
  balance_after numeric,
  transaction_type text,
  operating_tenant_name text,
  reference_no text,
  notes text,
  created_at timestamptz,
  total_count bigint
)
language plpgsql security definer;
```

---

## 4. Core Double-Entry & Atomic Ledger Writers

### 4.1 Single Ledger Post: `record_ledger_transaction`
```sql
create or replace function public.record_ledger_transaction(
  p_parent_tenant_id uuid,
  p_operating_tenant_id uuid,
  p_entity_type public.wallet_entity_type,
  p_entity_id uuid,
  p_currency_code text,
  p_direction public.ledger_entry_direction,
  p_amount numeric,
  p_transaction_type text,
  p_source_type text default null,
  p_source_id uuid default null,
  p_reference_no text default null,
  p_notes text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql security definer;
```

### 4.2 Inter-Wallet Transfer: `transfer_wallet_funds`
```sql
create or replace function public.transfer_wallet_funds(
  p_parent_tenant_id uuid,
  p_operating_tenant_id uuid,
  p_from_entity_type public.wallet_entity_type,
  p_from_entity_id uuid,
  p_to_entity_type public.wallet_entity_type,
  p_to_entity_id uuid,
  p_currency_code text,
  p_amount numeric,
  p_notes text default null
)
returns jsonb
language plpgsql security definer;
```
