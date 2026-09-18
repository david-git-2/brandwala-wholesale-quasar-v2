# Reporting & Treasury — API contract

**Read-only.** Each RPC must declare its layer (sales / cash / AR / COD ops / payable). Live bodies: `public.sql`. Target rules: [01-prd](01-prd.md). Collect/remittance RPCs: [wallet](../wallet/03-api-contract.md), not this file.

Signatures below are as-built names. Fix behaviour per [00-gaps](00-gaps.md) RT3–RT10; do not invent a ninth “revenue” RPC that sums layers.

## 1. 8 Core Treasury Reports RPCs

### 1.1 Cash In Report: `get_tenant_cash_in_report`
```sql
create or replace function public.get_tenant_cash_in_report(
  p_tenant_id uuid,
  p_start_date date default null,
  p_end_date date default null,
  p_method text default null
)
returns table (
  transaction_date date,
  payment_method text,
  total_inflow numeric,
  transaction_count bigint,
  details jsonb
)
language plpgsql security definer;
```

### 1.2 Customer Dues Report: `get_customer_dues_report`
```sql
create or replace function public.get_customer_dues_report(
  p_tenant_id uuid,
  p_search text default null,
  p_aging_days int default 30
)
returns table (
  billing_profile_id uuid,
  customer_name text,
  phone text,
  credit_limit numeric,
  current_due numeric,
  overdue_0_30 numeric,
  overdue_31_60 numeric,
  overdue_60_plus numeric
)
language plpgsql security definer;
```

### 1.3 Invoice Book: `get_tenant_invoice_book_report`
```sql
create or replace function public.get_tenant_invoice_book_report(
  p_tenant_id uuid,
  p_start_date date default null,
  p_end_date date default null
)
returns table (
  invoice_id uuid,
  invoice_no text,
  invoice_date date,
  customer_name text,
  net_total numeric,
  paid_amount numeric,
  due_amount numeric,
  payment_status text
)
language plpgsql security definer;
```

### 1.4 Invoice Profit & Margin: `get_tenant_invoice_profit_report`
```sql
create or replace function public.get_tenant_invoice_profit_report(
  p_tenant_id uuid,
  p_start_date date default null,
  p_end_date date default null
)
returns table (
  invoice_id uuid,
  invoice_no text,
  net_revenue numeric,
  cogs_cost numeric,
  gross_profit numeric,
  margin_percentage numeric
)
language plpgsql security definer;
```

### 1.5 Shipment Batch P&L: `get_tenant_shipment_profit_report`
```sql
create or replace function public.get_tenant_shipment_profit_report(
  p_tenant_id uuid,
  p_shipment_id uuid default null
)
returns table (
  shipment_id uuid,
  shipment_no text,
  landed_cost_total numeric,
  sold_revenue numeric,
  sold_cogs numeric,
  realized_gross_profit numeric,
  unsold_stock_value numeric
)
language plpgsql security definer;
```

### 1.6 Wallet Liability: `get_tenant_wallet_liability_report`
```sql
create or replace function public.get_tenant_wallet_liability_report(
  p_tenant_id uuid
)
returns table (
  entity_type text,
  total_credit_liability numeric,
  total_debit_receivable numeric,
  net_exposure numeric
)
language plpgsql security definer;
```

### 1.7 Courier COD: `get_tenant_courier_cod_report`
```sql
create or replace function public.get_tenant_courier_cod_report(
  p_tenant_id uuid,
  p_courier_id uuid default null
)
returns table (
  courier_id uuid,
  courier_name text,
  delivered_cod_total numeric,
  remitted_cash_total numeric,
  pending_remittance numeric
)
language plpgsql security definer;
```

### 1.8 Month Snapshot: `get_tenant_month_snapshot_report`
```sql
create or replace function public.get_tenant_month_snapshot_report(
  p_tenant_id uuid,
  p_month date
)
returns jsonb
language plpgsql security definer;
```

---

## 2. Multi-Invoice Payment Allocation RPC

```sql
create or replace function public.create_billing_profile_payment_with_allocations(
  p_parent_tenant_id uuid,
  p_operating_tenant_id uuid,
  p_billing_profile_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_reference_no text,
  p_allocations jsonb, -- [{ "invoice_id": "...", "allocated_amount": 5000.00 }]
  p_notes text default null
)
returns jsonb
language plpgsql security definer;
```
