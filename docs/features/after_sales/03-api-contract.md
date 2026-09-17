# After-Sales & Returns — API Contract & RPC Signatures

> **RPC Functions Target**: Policy Resolution, RMA Creation, Approval & Outcome Execution  
> **Security Level**: `SECURITY DEFINER`

---

## 1. Policy Resolver RPC: `resolve_after_sales_policy`

Evaluates the effective return window, allowed outcomes, and restocking fees for a given order or invoice item.

### Signature
```sql
create or replace function public.resolve_after_sales_policy(
  p_parent_tenant_id uuid,
  p_program public.after_sales_program,
  p_invoice_id uuid default null,
  p_shop_order_id uuid default null
)
returns jsonb
language plpgsql security definer;
```

---

## 2. Case Creation RPC: `create_after_sales_case`

Opens an RMA case, captures policy snapshot, and registers itemized return lines.

### Input Payload Schema
```json
{
  "parent_tenant_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "source_channel": "wholesale",
  "program": "return_credit",
  "sales_invoice_id": "7fa85f64-5717-4562-b3fc-2c963f66af10",
  "reason_code": "wrong_item",
  "lines": [
    {
      "sales_invoice_item_id": "9ba85f64-5717-4562-b3fc-2c963f66af33",
      "requested_quantity": 5
    }
  ]
}
```

### Success Response (`200 OK`)
```json
{
  "success": true,
  "case_id": "8ca85f64-5717-4562-b3fc-2c963f66af22",
  "case_no": "RMA-WS-20260917-0001",
  "status": "approved",
  "restock_fee_total": 500.00
}
```

---

## 3. Case Execution RPC: `execute_after_sales_case_line`

Executes the physical return and financial outcome for a line item (calls `process_wholesale_invoice_return` or replacement issuance).

### Signature
```sql
create or replace function public.execute_after_sales_case_line(
  p_case_line_id uuid,
  p_outcome public.after_sales_outcome,
  p_received_quantity numeric,
  p_restock_location_id uuid default null
)
returns jsonb
language plpgsql security definer;
```
