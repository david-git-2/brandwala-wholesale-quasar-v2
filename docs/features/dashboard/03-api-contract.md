# Dashboard & Insights — API Contract & RPC Signatures

> **RPC Functions Target**: Aggregated Dashboard Metrics & Customer Summaries  
> **Security Level**: `SECURITY DEFINER`

---

## 1. Customer Storefront Dashboard RPC: `get_customer_dashboard_summary`

Fetches storefront categories, order status segments, recent orders, and active cart resumes in a single call.

### Signature
```sql
create or replace function public.get_customer_dashboard_summary(
  p_tenant_id uuid
)
returns jsonb
language plpgsql security definer;
```

---

## 2. Staff Domain Dashboard Glance RPCs

### 2.1 Procurement Inbound Pipeline: `get_procurement_dashboard_metrics`
```sql
create or replace function public.get_procurement_dashboard_metrics(
  p_tenant_id uuid
)
returns jsonb
language plpgsql security definer;
```

### 2.2 Sales Invoices & AR Dues: `get_sales_invoice_dashboard_metrics`
```sql
create or replace function public.get_sales_invoice_dashboard_metrics(
  p_tenant_id uuid
)
returns jsonb
language plpgsql security definer;
```

### 2.3 Dropship Fulfillment Glance: `get_shop_order_dashboard_metrics`
```sql
create or replace function public.get_shop_order_dashboard_metrics(
  p_tenant_id uuid
)
returns jsonb
language plpgsql security definer;
```
