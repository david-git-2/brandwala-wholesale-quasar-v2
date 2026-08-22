# Cash in report (report 1)

Money that **hit the company till**. Not billed sales. Not store credit applied. Not money paid out.

Source of truth: **tenant wallet credits** on `universal_wallet_ledger`. No second cash book.

---

## Why

Staff need “what came in today?” without opening the full wallet statement (in + out mixed).

---

## Product

| Piece | Rule |
| :--- | :--- |
| **Cash in** | Sum of **credit** rows on the **tenant** wallet in the date filter |
| **By method** | Same credits grouped (`cash`, `bank`, courier remit, deposit, `other`) |
| **Not included** | Customer store credit used on an invoice (debits the **customer** wallet only) |
| **Not included** | Tenant **debits** (payouts, withdrawals) |

Wallet apply stays on report 6 (Wallet). Dues stay on report 2.

---

## Nav & route

- **Nav label:** Cash in
- **Module grant:** `universal_wallet` / `view`
- **Path:** `/:tenantSlug?/app/wallet/cash-in`
- **Name:** `app-wallet-cash-in-page`

Sits with Wallets (Cash & dues home). Not under invoice lists.

---

## Page (planned — not built)

Layout: treasury shell (header + cards + filter + table). Separate skeleton component. No extra in-page `<h1>` beyond `AppPageHeader` / `TreasuryPageShell`.

1. **Filter** — Today, last 7 days, this month, or from–to. Default **Today**.
2. **Cards** — **Cash in** (total). Extra cards per method when more than one method has amount.
3. **Table** — Credit lines: time, method, amount, label/source, invoice if present. Row click → invoice detail when `metadata.invoice_id` exists, else company wallet.

TanStack Query: `walletQueryKeys.cashIn(tenantId, start, end)`, `staleTime` 30s. One RPC per filter change. Debounce custom dates 300ms.

---

## RPC: `get_tenant_cash_in_report`

```text
get_tenant_cash_in_report(
  p_tenant_id bigint,
  p_start_date timestamptz default null,
  p_end_date timestamptz default null
) returns jsonb
```

**Auth:** `membership_has_module_action` on parent tenant, module `universal_wallet`, action `view`.

**Books tenant:** `coalesce(tenants.parent_id, tenants.id)` from `p_tenant_id`. Ledger rows use that id as both `tenant_id` and tenant `entity_id`.

**Rows:** `entity_type = 'tenant'`, `type = 'credit'`, date window on `created_at`. Exclude `metadata.purpose = 'apply_store_credit'`.

**Method** (first non-empty): `metadata.method` → `global_payments.method` when `source_id` is a payment id → `'other'`.

**JSON:**

```json
{
  "tenant_id": 1,
  "start_date": "...",
  "end_date": "...",
  "cash_in_total": 0,
  "entry_count": 0,
  "by_method": [{ "method": "cash", "amount": 0, "count": 0 }],
  "entries": [
    {
      "id": "uuid",
      "amount": 0,
      "method": "cash",
      "source_type": "sales_invoice",
      "source_id": "12",
      "label": "Payment Received",
      "invoice_id": 99,
      "created_at": "..."
    }
  ]
}
```

Reuse `get_wallet_entity_statement` only as a fallback debug view. The report page **must** call this RPC (credits only + method).

**Writes:** Invoice cash collect must stamp `metadata.method` on the tenant credit (`collect_wholesale_invoice_payment`). Older rows still resolve via `global_payments`.

---

## App wiring

**UI later.** Do not add the page, nav, or repository until asked.

Planned path: `/:tenantSlug?/app/wallet/cash-in` (register **before** `:walletType`). Grant: `universal_wallet` / `view`. Query key (when built): `['wallet', 'cashIn', { tenantId, startDate, endDate }]`.

---

## Out of scope (v1)

UI. Daily sparkline, staff collector, cash-out page, mixing billed/returned/due on this screen.
