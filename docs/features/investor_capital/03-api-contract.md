# Investor Portal & Capital — API Contract & RPC Signatures

> **RPC Functions Target**: Capital Inflow, Withdrawal Payouts, Batch Allocation & Profit Sync  
> **Security Level**: `SECURITY DEFINER`

---

## 1. Capital Deposit RPC: `record_investor_capital_in`

Records capital injected into the investor's balance and posts immutable ledger entries.

### Signature
```sql
create or replace function public.record_investor_capital_in(
  p_parent_tenant_id uuid,
  p_investor_id uuid,
  p_amount numeric,
  p_reference_no text default null,
  p_notes text default null
)
returns jsonb
language plpgsql security definer;
```

---

## 2. Withdrawal Payout RPC: `record_investor_withdrawal_paid`

Debits investor balance upon payout and debits the tenant liquid operating wallet.

### Signature
```sql
create or replace function public.record_investor_withdrawal_paid(
  p_parent_tenant_id uuid,
  p_investor_id uuid,
  p_amount numeric,
  p_payment_method text default 'bank_transfer',
  p_reference_no text default null,
  p_notes text default null
)
returns jsonb
language plpgsql security definer;
```

---

## 3. Batch Investment Allocation RPC: `upsert_shipment_investment`

```sql
create or replace function public.upsert_shipment_investment(
  p_parent_tenant_id uuid,
  p_shipment_id uuid,
  p_investor_id uuid,
  p_cost_share_pct numeric
)
returns jsonb
language plpgsql security definer;
```
