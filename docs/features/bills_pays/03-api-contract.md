# Bills & pays — API

Spec tables: [02](02-data-model.md) (`bills`, `pays`, `profiles`, `cashbook_*`). Live RPC/column names below (`sales_invoices`, `billing_profile_id`, …) until BP3–BP4. Pays SQL: `public.sql`. [00-gaps](00-gaps.md) WA4 / WA12.

## A. Bills


## 1. Unified Creation RPC: `create_sales_invoice_from_payload`

Creates a **bill** with header, lines, and optional `issue`. `sell_price_amount` is **tenant sell** only. Issue does not record payment. Live SQL: `supabase/schemas/sales_invoice/03_rpcs.sql`.

| Who | Calls this RPC? |
| :--- | :--- |
| **Wholesale / retail desk** | Yes — `CreateWholesaleInvoicePage` Save / Save & Issue. Lines = FIFO sellable stock. `invoice_type=wholesale` (or retail). |
| **Dropship desk** | **No.** Use `ship_dropship_order_and_issue_merchant_bill` → `issue_dropship_tenant_b2b_invoice` → this RPC internally. Lines = held picks. `invoice_type=dropship`. |

COD/resell are never payload totals. [01-prd](01-prd.md) / [money-story](money-story.md).

### Input Payload Schema
```json
{
  "invoice": {
    "invoice_type": "wholesale",
    "billing_profile_id": "8ba85f64-5717-4562-b3fc-2c963f66af01",
    "invoice_date": "2026-09-17",
    "due_date": "2026-10-02",
    "discount_amount": 1000.00,
    "shipping_charge": 500.00,
    "note": "Net 15 days payment terms"
  },
  "items": [
    {
      "global_stock_id": "4ba85f64-5717-4562-b3fc-2c963f66af88",
      "quantity": 10,
      "sell_price_amount": 1200.00,
      "line_discount_amount": 0.00
    }
  ],
  "options": {
    "issue": true
  }
}
```

### Success Response (`200 OK`)
```json
{
  "success": true,
  "invoice_id": "7fa85f64-5717-4562-b3fc-2c963f66af10",
  "invoice_no": "INV-WS-20260917-0001",
  "invoice_status": "issued",
  "payment_status": "due",
  "total_amount": 11500.00,
  "due_amount": 11500.00
}
```

---

## 2. Unified Patching RPC: `update_sales_invoice_from_payload`

Performs partial PATCH updates on draft or proforma invoices, modifying only sent keys, adding new items, or removing items by ID.

### Signature
```sql
create or replace function public.update_sales_invoice_from_payload(
  p_tenant_id uuid,
  p_invoice_id uuid,
  p_payload jsonb
)
returns jsonb
language plpgsql security definer;
```

---

## 3. Stock Search RPC: `search_sales_invoice_stock`

Searches products by name or barcode, ranking current tenant allocations first (Rank 0) followed by parent warehouse stock (Rank 1), ordered by strict FIFO (`created_at ASC`).

### Signature
```sql
create or replace function public.search_sales_invoice_stock(
  p_tenant_id uuid,
  p_search text default null,
  p_limit int default 50
)
returns table (
  global_stock_id uuid,
  product_id uuid,
  product_name text,
  sku text,
  barcode text,
  available_atp numeric,
  landed_unit_cost_bdt numeric,
  suggested_sell_price numeric,
  allocation_rank int,
  location_name text
)
language plpgsql security definer;
```

---

## 4. Wholesale Return RPC: `process_wholesale_invoice_return`

Applies full or partial returns to invoice lines, deducts restock fees on the invoice, restores inventory to `held`, reduces due balance, or posts customer **cashbook** leftover for paid excess.

### Signature
```sql
create or replace function public.process_wholesale_invoice_return(
  p_invoice_id uuid,
  p_returned_items jsonb,
  p_restocking_charge numeric default 0,
  p_refund_method text default 'wallet_credit',
  p_notes text default null
)
returns jsonb
language plpgsql security definer;
```

## B. Pays & cashbook

Target: **one receipt RPC** (header + instrument lines + allocations + ledger) then invoice status update. Live collect/remittance RPCs still differ — [00-gaps](00-gaps.md) WA4, WA9–WA12.

Ledger list/detail below. Bodies: `public.sql` until pays schema split ([WA1](00-gaps.md)). Payments live: `collect_wholesale_invoice_payment` (wholesale/retail collect on invoice detail); dropship remittance RPCs in `supabase/schemas/shop_order/03_rpcs.sql`. Unify later — [00-gaps](00-gaps.md) WA4.

Wholesale collect **live**: `collect_wholesale_invoice_payment` on issued buyer bill (cash / store credit / settlement). Receipt amount = money received; allocates to that invoice. Do not use remittance RPCs or `create_billing_profile_payment_with_allocations` on the invoice desk.

Dropship remittance **target**: order `delivered` + linked issued merchant bill; receipt amount = net bank in; allocate `min(net, invoice.due)`; leftover → shop **cashbook**. Do not rewrite sell. Do not issue a bill here. Require `global_invoice_id` ([shop_order 01-prd](../shop_order/01-prd.md) US-3).

---

## 0. Target unified receipt RPC (not live)

Posts one receipt header, zero or more instrument lines, optional invoice allocations, optional ledger remainder. Used by **invoice collect** and **profile collect** ([02-data-model](02-data-model.md)). Params still `p_billing_profile_id` until BP3.

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

Live **cashbook** RPC names until [BP2](00-gaps.md) (not a wallet product).

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
Posts header + instruments + allocations. Unallocated leftover → customer **cashbook** only.

---

## 3. Ledger History RPC: `list_wallet_ledger_for_staff`

Retrieves the paginated, chronological cashbook log for a party.

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
