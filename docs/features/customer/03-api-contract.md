# Customer Hub — API Contract & RPC Signatures

> **RPC Functions Target**: Customer Provisioning, Account Summaries & Group Management  
> **Security Level**: `SECURITY DEFINER`

---

## 1. Unified Provisioning RPC: `create_customer_account`

Creates a Customer Group, links its Billing Profile, and initializes a Universal Wallet account in a single atomic transaction.

### Input Payload Schema
```json
{
  "parent_tenant_id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
  "name": "Metro Mega Mart (Dhanmondi)",
  "phone": "01711223344",
  "phone_country_code": "+880",
  "accent_color": "#2563EB"
}
```

### Success Response (`200 OK`)
```json
{
  "success": true,
  "customer_group_id": "7fa85f64-5717-4562-b3fc-2c963f66af10",
  "billing_profile_id": "8ba85f64-5717-4562-b3fc-2c963f66af20",
  "wallet_account_id": "9ca85f64-5717-4562-b3fc-2c963f66af30"
}
```

---

## 2. Directory Listing RPC: `list_customer_accounts_paginated`

Lists customer groups with their contact details, active shop grants, current invoice dues, and store credit wallet balances.

### Signature
```sql
create or replace function public.list_customer_accounts_paginated(
  p_tenant_id uuid,
  p_search text default null,
  p_limit int default 50,
  p_offset int default 0
)
returns table (
  customer_group_id uuid,
  billing_profile_id uuid,
  name text,
  phone text,
  email text,
  accent_color text,
  is_active boolean,
  active_shops_count bigint,
  total_open_due_bdt numeric,
  store_credit_balance_bdt numeric,
  total_count bigint
)
language plpgsql security definer;
```

---

## 3. Account Summary RPC: `get_customer_account_summary_for_staff`

Fetches detailed balance comparisons (Total Billed vs Total Paid vs Total Due vs Store Credit) along with open invoice registers for the Account drawer tab.

### Signature
```sql
create or replace function public.get_customer_account_summary_for_staff(
  p_tenant_id uuid,
  p_customer_group_id uuid
)
returns jsonb
language plpgsql security definer;
```
