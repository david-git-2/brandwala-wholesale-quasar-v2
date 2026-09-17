# Thrift Vertical — API Contract & RPC Signatures

> **RPC Functions Target**: Thrift Intake, Barcode Generation, Risk Scoring & POS Checkout  
> **Security Level**: `SECURITY DEFINER`

---

## 1. Stock Registration RPC: `register_thrift_stock_from_app`

Registers a single-piece garment, creates measurement records, and assigns thermal barcode in one atomic call.

### Signature
```sql
create or replace function public.register_thrift_stock_from_app(
  p_tenant_id uuid,
  p_stock_payload jsonb,
  p_measurements jsonb default null
)
returns jsonb
language plpgsql security definer;
```

---

## 2. Customer Courier Risk Scoring RPC: `get_thrift_customer_sales_risk`

Evaluates historical delivery completion rates, return ratios, and cancellations for a customer phone number across couriers.

### Signature
```sql
create or replace function public.get_thrift_customer_sales_risk(
  p_tenant_id uuid,
  p_phone text
)
returns jsonb
language plpgsql security definer;
```

### Success Response Schema
```json
{
  "phone": "01711223344",
  "risk_tier": "low", // 'low', 'medium', 'high'
  "total_orders": 12,
  "successful_deliveries": 11,
  "cancelled_orders": 1,
  "success_rate_percentage": 91.67,
  "warning_flag": false
}
```

---

## 3. Atomic POS Invoicing RPC: `create_thrift_sales_invoice`

```sql
create or replace function public.create_thrift_sales_invoice(
  p_tenant_id uuid,
  p_invoice_payload jsonb,
  p_stock_barcodes text[]
)
returns jsonb
language plpgsql security definer;
```
