# RPC: `get_wallet_dashboard_summary`

Fetches aggregate tenant-wide wallet metrics, total cash positions, courier holdings, merchant pending/available totals, and vendor payables.

---

## 1. Internal Table Operations

* [wallet_account_api.md](../api/wallet_account_api.md) — `wallet_accounts` aggregate queries

---

## 2. Main RPC Call

```typescript
const { data, error } = await supabase.rpc('get_wallet_dashboard_summary', {
  p_tenant_id: 12
});
```

---

## 3. Payloads

### A. Request Payload
```json
{
  "p_tenant_id": 12
}
```

### B. Response Payload
```json
{
  "tenant_id": 12,
  "tenant_cash_total": 450000.00,
  "courier_cod_holding_total": 12500.00,
  "merchant_pending_total": 3400.00,
  "merchant_available_total": 85000.00,
  "vendor_payables_total": 17500.00,
  "customer_deposits_total": 2100.00
}
```
