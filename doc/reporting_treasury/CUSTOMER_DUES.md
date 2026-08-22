# Customer dues report (report 2)

Chase list: **who owes now**, how old, credit limit. Not the invoice book. Not the customer wallet.

Source of truth: issued wholesale invoices on `sales_invoices`. Still due is `due_amount`. Group by billing profile.

Customer wallet is store credit they can spend. Do not add it to “owes.”

Does not wait on the invoice book report. Needs issue / collect / return already keeping `due_amount` correct.

---

## Why

Staff need “who to call” without opening every unpaid invoice.

---

## Product

Show **billed**, **returned**, **collected cash**, **wallet applied**, and **still due** as separate numbers. Settlement write-off is extra, not mixed into cash.

| Piece | Rule |
| :--- | :--- |
| **Still due** | `sum(due_amount)` on issued invoices for that customer |
| **Billed** | Invoice totals before netting returns (net `total_amount` + returned value) |
| **Returned** | Line returns: `return_quantity × sell_price` (restock fee stays on the invoice) |
| **Collected cash** | `invoice_payments` → `global_payments` where `method` is **not** `wallet_credit` |
| **Wallet applied** | Same join where `method = 'wallet_credit'` |
| **Settlement** | `sum(settlement_discount_amount)` |
| **Aging** | Split still due by `due_date` (else `invoice_date`): current, 1–30, 31–60, 61–90, 90+ |
| **Credit limit** | Customer group access, if set. Not on the invoice |

Snapshot is **now**. No date range in v1 (that is invoice book).

Default rows: customers with `still_due > 0` only.

Drill: row → existing unpaid invoice list for that billing profile (no second dues RPC).

---

## Nav & route

- **Nav label:** Customer dues
- **Module grant:** `reporting_treasury` / `view`
- **Path:** `/:tenantSlug?/app/finance/reports/customer-dues`
- **Name:** `app-finance-customer-dues-report-page`

Cash & dues home. Wallet liability stays on report 6.

---

## Page (planned — stub only)

Layout: treasury shell (header + cards + filter + table). Empty `CustomerDuesReportPage.vue` today.

1. **Filter** — Search name, child seller, aging bucket, min due, over credit limit.
2. **Cards** — Totals: billed, returned, cash, wallet applied, settlement, still due, customer count.
3. **Table** — One row per customer. Sort by still due desc. Click → invoice list.

TanStack Query: `['finance', 'customerDues', filters]`, `staleTime` 30s. One RPC per filter change. Debounce search 300ms.

---

## RPC: `get_customer_dues_report`

```text
get_customer_dues_report(
  p_tenant_id bigint,
  p_issued_by_tenant_id bigint default null,
  p_search text default null,
  p_aging_bucket text default null,
  p_min_due numeric default 0,
  p_over_limit_only boolean default false,
  p_page integer default 1,
  p_page_size integer default 50,
  p_skip_count boolean default true
) returns jsonb
```

**Auth:** `membership_has_module_action` on parent tenant, module `reporting_treasury`, action `view`.

**Books tenant:** `coalesce(tenants.parent_id, tenants.id)` from `p_tenant_id`. Invoices: `parent_tenant_id` = books tenant, `invoice_status = issued`, `invoice_type = wholesale`, `billing_profile_id` not null.

**Aging bucket** (optional): `current` | `1_30` | `31_60` | `61_90` | `90_plus`. Keep the customer if that bucket’s due &gt; 0.

**JSON:**

```json
{
  "totals": {
    "billed": 0,
    "returned": 0,
    "collected_cash": 0,
    "wallet_applied": 0,
    "settlement": 0,
    "still_due": 0,
    "customer_count": 0
  },
  "rows": [
    {
      "billing_profile_id": 88,
      "name": "Rahim Traders",
      "phone": null,
      "credit_limit": 100000,
      "billed": 0,
      "returned": 0,
      "collected_cash": 0,
      "wallet_applied": 0,
      "settlement": 0,
      "still_due": 0,
      "oldest_due_date": "2026-06-01",
      "aging": {
        "current": 0,
        "d1_30": 0,
        "d31_60": 0,
        "d61_90": 0,
        "d90_plus": 0
      },
      "open_invoice_count": 0
    }
  ],
  "page": 1,
  "page_size": 50,
  "total_count": null
}
```

`totals` ignore page (all matching customers). `total_count` only when `p_skip_count` is false.

Do not sum invoices in the browser.

---

## Filters

| Filter | Arg |
| :--- | :--- |
| Search (customer name) | `p_search` |
| Who sold (child) | `p_issued_by_tenant_id` |
| Age bucket | `p_aging_bucket` |
| Min due | `p_min_due` |
| Over credit limit | `p_over_limit_only` |

---

## Out of scope (v1)

Date range, paid-off customers, dropship/recipient COD, mixing wallet liability into this list, staff collector, write-off as its own report (settlement column only).
