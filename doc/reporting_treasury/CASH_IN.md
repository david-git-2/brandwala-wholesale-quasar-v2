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

A single, consolidated RPC handles the complete dataset for this report (summary KPIs, method breakdowns, and itemized table records in one network roundtrip).

### Signature & Definition
```sql
CREATE OR REPLACE FUNCTION "public"."get_tenant_cash_in_report"(
  "p_tenant_id" bigint,
  "p_start_date" timestamp with time zone DEFAULT NULL::timestamp with time zone,
  "p_end_date" timestamp with time zone DEFAULT NULL::timestamp with time zone
) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_cash_in numeric(18,4) := 0.0000;
  v_count integer := 0;
  v_by_method jsonb;
  v_entries jsonb;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'Tenant ID is required';
  END IF;

  SELECT coalesce(t.parent_id, t.id)
  INTO v_books_id
  FROM public.tenants t
  WHERE t.id = p_tenant_id;

  IF v_books_id IS NULL THEN
    RAISE EXCEPTION 'Tenant not found';
  END IF;

  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'universal_wallet', 'view')
    OR public.membership_has_module_action(v_books_id, 'universal_wallet', 'view')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  WITH lined AS (
    SELECT
      l.id,
      l.amount,
      l.source_type,
      l.source_id,
      l.metadata,
      l.created_at,
      coalesce(
        nullif(trim(l.metadata->>'method'), ''),
        nullif(trim(gp.method), ''),
        'other'
      ) AS method,
      nullif(l.metadata->>'label', '') AS label,
      CASE
        WHEN (l.metadata->>'invoice_id') ~ '^[0-9]+$' THEN (l.metadata->>'invoice_id')::bigint
        ELSE NULL
      END AS invoice_id
    FROM public.universal_wallet_ledger l
    LEFT JOIN public.global_payments gp
      ON l.source_id ~ '^[0-9]+$'
     AND gp.id = l.source_id::bigint
     AND gp.tenant_id = v_books_id
    WHERE l.tenant_id = v_books_id
      AND l.entity_type = 'tenant'
      AND l.entity_id = v_books_id
      AND l.type = 'credit'
      AND coalesce(l.metadata->>'purpose', '') <> 'apply_store_credit'
      AND (p_start_date IS NULL OR l.created_at >= p_start_date)
      AND (p_end_date IS NULL OR l.created_at <= p_end_date)
  )
  SELECT
    coalesce(sum(amount), 0.0000),
    count(*)::integer,
    coalesce(
      (
        SELECT jsonb_agg(jsonb_build_object(
          'method', m.method,
          'amount', m.amt,
          'count', m.cnt
        ) ORDER BY m.amt DESC)
        FROM (
          SELECT method, sum(amount) AS amt, count(*)::integer AS cnt
          FROM lined
          GROUP BY method
        ) m
      ),
      '[]'::jsonb
    ),
    coalesce(
      (
        SELECT jsonb_agg(jsonb_build_object(
          'id', e.id,
          'amount', e.amount,
          'method', e.method,
          'source_type', e.source_type,
          'source_id', e.source_id,
          'label', e.label,
          'invoice_id', e.invoice_id,
          'created_at', e.created_at
        ) ORDER BY e.created_at DESC, e.id DESC)
        FROM lined e
      ),
      '[]'::jsonb
    )
  INTO v_cash_in, v_count, v_by_method, v_entries
  FROM lined;

  RETURN jsonb_build_object(
    'tenant_id', v_books_id,
    'start_date', p_start_date,
    'end_date', p_end_date,
    'cash_in_total', v_cash_in,
    'entry_count', v_count,
    'by_method', v_by_method,
    'entries', v_entries
  );
END;
$$;
```

**Auth:** `membership_has_module_action` on parent tenant, module `universal_wallet`, action `view`.

**Books tenant:** `coalesce(tenants.parent_id, tenants.id)` from `p_tenant_id`. Ledger rows use that id as both `tenant_id` and tenant `entity_id`.

**Rows:** `entity_type = 'tenant'`, `type = 'credit'`, date window on `created_at`. Exclude `metadata.purpose = 'apply_store_credit'`.

**Method resolution** (first non-empty): `metadata.method` → `global_payments.method` when `source_id` is a payment id → `'other'`.

### RPC Response JSON Payload

Everything needed for the entire report page (KPI cards, method breakdown tabs/chips, and the transaction list table) is returned in a single response:

```json
{
  "tenant_id": 1,
  "start_date": "2026-08-01T00:00:00Z",
  "end_date": "2026-08-31T23:59:59Z",
  "cash_in_total": 45000.0000,
  "entry_count": 14,
  "by_method": [
    { "method": "cash", "amount": 25000.0000, "count": 8 },
    { "method": "bank", "amount": 15000.0000, "count": 4 },
    { "method": "courier_remit", "amount": 5000.0000, "count": 2 }
  ],
  "entries": [
    {
      "id": "a3f5c71d-1b1e-4c7b-9e23-28f0991c2834",
      "amount": 5000.0000,
      "method": "cash",
      "source_type": "sales_invoice",
      "source_id": "142",
      "label": "Payment Received - Invoice #INV-1042",
      "invoice_id": 142,
      "created_at": "2026-08-31T14:20:00Z"
    }
  ]
}
```

**Writes:** Invoice cash collect stamps `metadata.method` on the tenant credit (`collect_wholesale_invoice_payment`). Older rows resolve via `global_payments`.

---

## App wiring

- **Route:** `/:tenantSlug?/app/finance/reports/cash-in`
- **Component:** [`CashInReportPage.vue`](file:///Users/david/Documents/personal_projects/brandwala-wholesale-quasar-v2/web/src/modules/reporting_treasury/pages/CashInReportPage.vue)
- **Design System:** Follows [`.agents/rules/table_list_design_system.md`](file:///Users/david/Documents/personal_projects/brandwala-wholesale-quasar-v2/.agents/rules/table_list_design_system.md) (Zero outer scroll, 38px compact top toolbar, stats strip, and internal sticky header scroll).
- **Query Key:** `walletQueryKeys.cashIn({ tenantId, startDate, endDate })` via TanStack Query (`staleTime: 30s`).
- **Repository:** `walletReportsRepository.fetchCashInReport` & `exportCashInToCsv`.
- **Status:** **Live & Integrated**.

