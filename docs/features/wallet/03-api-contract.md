# Wallet & receipts — API contract

Target: **one receipt RPC** (header + instrument lines + allocations + ledger) then invoice status update. Live collect/remittance RPCs still differ — [00-gaps](00-gaps.md) WA4, WA9–WA12.

Ledger list/detail below. Bodies: `public.sql` until wallet schema split. Payments live: `collect_wholesale_invoice_payment` (wholesale/retail collect on invoice detail); dropship remittance RPCs in `supabase/schemas/shop_order/03_rpcs.sql`. Unify later — [00-gaps](00-gaps.md) WA4.

Wholesale collect **live**: `collect_wholesale_invoice_payment` on issued buyer bill (cash / store credit / settlement). Receipt amount = money received; allocates to that invoice. Do not use remittance RPCs or `create_billing_profile_payment_with_allocations` on the invoice desk.

Dropship remittance **target**: order `delivered` + linked issued merchant bill; receipt amount = net bank in; allocate `min(net, invoice.due)`; leftover → merchant ledger. Do not rewrite sell. Do not issue a bill here. Require `global_invoice_id` (shop_order SO11).

---

## 0. Target unified receipt RPC (not live)

Posts one receipt header, zero or more instrument lines, optional invoice allocations, optional ledger remainder. Used by **invoice collect** and **billing-profile collect** ([02-data-model](02-data-model.md)).

### Signature (target)
```sql
create or replace function public.post_customer_receipt_with_allocations(
  p_tenant_id bigint,
  p_billing_profile_id bigint,
  p_received_on date,
  p_note text default null,
  p_reference text default null,
  p_source text default 'customer_cash',  -- customer_cash | bank | store_credit
  p_instruments jsonb default '[]'::jsonb,
  p_allocations jsonb default '[]'::jsonb,
  p_shop_order_id bigint default null      -- dropship remittance only
)
returns public.global_payments
language plpgsql security definer;
```

### `p_instruments` element (target)
```json
{
  "payment_method_code": "cheque",
  "amount": 15000,
  "reference": null,
  "bd_bank_id": 12,
  "cheque_number": "88421",
  "cheque_date": "2026-09-25"
}
```

| Field | Required when |
| :--- | :--- |
| `payment_method_code` | Always (`cash`, `cheque`, `bkash`, `bank_transfer`, … from `payment_methods`) |
| `amount` | Always (> 0) |
| `reference` | Optional; bKash/bank trx id or line note |
| `bd_bank_id`, `cheque_number`, `cheque_date` | `payment_method_code = cheque` |

Validation: `SUM(instruments.amount)` = header `amount`. `SUM(allocations.amount)` ≤ header `amount`. Each allocation ≤ invoice `due_amount`.

Store credit-only receipts may omit instruments until store-credit path is merged into the same RPC.

---

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

## 2. Wholesale collect desk RPCs (live)

### `list_customer_group_receipts(p_tenant_id, p_customer_group_id)` → jsonb array
Past receipts for a customer group: header, `instruments[]`, `allocations[]`, `voided_at`.

### `update_payment_instrument_details(p_tenant_id, p_instrument_id, …)` → jsonb
Patch cheque/bank/trx fields only. Refuses voided receipts and amount changes.

### `void_customer_receipt(p_tenant_id, p_payment_id, p_reason)` → jsonb
Reverses tenant cash + customer store-credit leftover; removes `invoice_payments`; sets `voided_at`. UI: void then re-enter on collect page.

### `record_batch_customer_payment` (existing)
Posts header + instruments + allocations. Customer wallet credit only for unallocated leftover.

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
