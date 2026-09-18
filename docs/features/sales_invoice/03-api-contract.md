# Sales Invoice — API Contract & RPC Signatures

> **RPC Functions Target**: `supabase/schemas/sales_invoice/03_rpcs.sql`  
> **Security Level**: `SECURITY DEFINER` with tenant membership validation

---

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

Applies full or partial returns to invoice lines, deducts restock fees on the invoice, restores inventory to `held`, reduces due balance, or credits the customer wallet for paid excess.

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
