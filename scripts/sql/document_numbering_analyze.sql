-- READ ONLY — analyze document_number_counters vs high-water from existing rows.
-- Does NOT change data. Does NOT rewrite historical invoice_no / order_no / movement_no.
--
-- Focus: rows where needed_last_value > coalesce(current_last_value, 0) → run backfill
-- or investigate before issuing new documents in that bucket.
--
-- Run in Supabase SQL editor on prod. Safe to re-run.

-- =============================================================================
-- 1) Counter gaps (action list) — only rows that backfill should raise
-- =============================================================================

WITH shipment_needed AS (
  SELECT u.tenant_id, max(u.max_shipment_id)::bigint AS needed_last_value
  FROM (
    SELECT gs.tenant_id, max(gs.tenant_shipment_id)::bigint AS max_shipment_id
    FROM public.global_shipments gs
    WHERE gs.tenant_id IS NOT NULL AND gs.tenant_shipment_id IS NOT NULL
    GROUP BY gs.tenant_id
    UNION ALL
    SELECT s.tenant_id, max(s.tenant_shipment_id)::bigint
    FROM public.shipments s
    GROUP BY s.tenant_id
  ) u
  GROUP BY u.tenant_id
),

-- --- Sales invoices (monthly INV-WS|RT|DS) from bills + legacy daily INV-*-YYYYMMDD-* ---
bill_parsed AS (
  SELECT
    b.issued_by_tenant_id AS tenant_id,
    'sales_invoice'::text AS doc_type,
    (m)[1] AS sub_type,
    CASE
      WHEN (m)[2] ~ '^\d{8}$' THEN substring((m)[2] from 3 for 4)
      ELSE (m)[2]
    END AS period_key,
    ((m)[3])::bigint AS seq
  FROM public.bills b
  CROSS JOIN LATERAL regexp_match(
    b.invoice_no,
    '^INV-(WS|RT|DS)-(\d{4}|\d{8})-(\d+)$'
  ) AS m
  WHERE b.document_kind = 'standard'::public.bill_document_kind
    AND b.invoice_type IN ('wholesale'::public.global_invoice_type, 'retail'::public.global_invoice_type, 'dropship'::public.global_invoice_type)
),

legacy_sales_invoice_counters AS (
  SELECT
    sic.tenant_id,
    'sales_invoice'::text AS doc_type,
    CASE sic.invoice_type
      WHEN 'wholesale'::public.global_invoice_type THEN 'WS'
      WHEN 'retail'::public.global_invoice_type THEN 'RT'
      WHEN 'dropship'::public.global_invoice_type THEN 'DS'
      ELSE 'WS'
    END AS sub_type,
    substring(sic.date_key from 3 for 4) AS period_key,
    max(sic.last_value)::bigint AS seq
  FROM public.sales_invoice_counters sic
  WHERE sic.invoice_type <> 'ap'::public.global_invoice_type
  GROUP BY
    sic.tenant_id,
    CASE sic.invoice_type
      WHEN 'wholesale'::public.global_invoice_type THEN 'WS'
      WHEN 'retail'::public.global_invoice_type THEN 'RT'
      WHEN 'dropship'::public.global_invoice_type THEN 'DS'
      ELSE 'WS'
    END,
    substring(sic.date_key from 3 for 4)
),

sales_invoice_needed AS (
  SELECT tenant_id, doc_type, sub_type, period_key, max(seq)::bigint AS needed_last_value
  FROM (
    SELECT tenant_id, doc_type, sub_type, period_key, seq FROM bill_parsed
    UNION ALL
    SELECT tenant_id, doc_type, sub_type, period_key, seq FROM legacy_sales_invoice_counters
  ) u
  WHERE tenant_id IS NOT NULL AND period_key IS NOT NULL
  GROUP BY tenant_id, doc_type, sub_type, period_key
),

-- --- AP bills ---
ap_needed AS (
  SELECT
    b.issued_by_tenant_id AS tenant_id,
    'ap_bill'::text AS doc_type,
    ''::text AS sub_type,
    (m)[1] AS period_key,
    max((m)[2]::bigint) AS needed_last_value
  FROM public.bills b
  CROSS JOIN LATERAL regexp_match(b.invoice_no, '^AP-(\d{4})-(\d+)$') AS m
  WHERE b.invoice_type = 'ap'::public.global_invoice_type
  GROUP BY b.issued_by_tenant_id, (m)[1]
),

-- --- Dropship B2B (DS-YYMM-####); skip legacy INV-DS-* (not sequence-based) ---
dropship_b2b_needed AS (
  SELECT
    b.issued_by_tenant_id AS tenant_id,
    'dropship_b2b_invoice'::text AS doc_type,
    ''::text AS sub_type,
    (m)[1] AS period_key,
    max((m)[2]::bigint) AS needed_last_value
  FROM public.bills b
  CROSS JOIN LATERAL regexp_match(b.invoice_no, '^DS-(\d{4})-(\d+)$') AS m
  GROUP BY b.issued_by_tenant_id, (m)[1]
),

-- --- Credit / debit notes (new CN-/DN- prefixes) ---
cn_needed AS (
  SELECT
    b.issued_by_tenant_id AS tenant_id,
    'credit_note'::text AS doc_type,
    (m)[1] AS sub_type,
    (m)[2] AS period_key,
    max((m)[3]::bigint) AS needed_last_value
  FROM public.bills b
  CROSS JOIN LATERAL regexp_match(b.invoice_no, '^CN-(WS|RT|DS)-(\d{4})-(\d+)$') AS m
  WHERE b.document_kind = 'credit_note'::public.bill_document_kind
  GROUP BY b.issued_by_tenant_id, (m)[1], (m)[2]
),

dn_needed AS (
  SELECT
    b.issued_by_tenant_id AS tenant_id,
    'debit_note'::text AS doc_type,
    (m)[1] AS sub_type,
    (m)[2] AS period_key,
    max((m)[3]::bigint) AS needed_last_value
  FROM public.bills b
  CROSS JOIN LATERAL regexp_match(b.invoice_no, '^DN-(WS|RT|DS)-(\d{4})-(\d+)$') AS m
  WHERE b.document_kind = 'debit_note'::public.bill_document_kind
  GROUP BY b.issued_by_tenant_id, (m)[1], (m)[2]
),

-- --- Shop orders SO-YYMMDD-#### (ORD-* not used for counter high-water) ---
shop_order_needed AS (
  SELECT
    o.tenant_id,
    'shop_order'::text AS doc_type,
    ''::text AS sub_type,
    (m)[1] AS period_key,
    max((m)[2]::bigint) AS needed_last_value
  FROM public.shop_orders o
  CROSS JOIN LATERAL regexp_match(o.order_no, '^SO-(\d{6})-(\d+)$') AS m
  GROUP BY o.tenant_id, (m)[1]
),

-- --- Stock movements (day buckets) ---
movement_needed AS (
  SELECT
    sm.tenant_id,
    CASE upper(split_part(sm.movement_no, '-', 1))
      WHEN 'MOV' THEN 'stock_movement'
      WHEN 'SM' THEN 'stock_movement_manual'
      WHEN 'RP' THEN 'receive_putaway'
      WHEN 'VR' THEN 'vendor_return'
    END AS doc_type,
    ''::text AS sub_type,
    (m)[1] AS period_key,
    max((m)[2]::bigint) AS needed_last_value
  FROM public.stock_movements sm
  CROSS JOIN LATERAL regexp_match(sm.movement_no, '^(MOV|SM|RP|VR)-(\d{6})-(\d+)$') AS m
  GROUP BY sm.tenant_id,
    CASE upper(split_part(sm.movement_no, '-', 1))
      WHEN 'MOV' THEN 'stock_movement'
      WHEN 'SM' THEN 'stock_movement_manual'
      WHEN 'RP' THEN 'receive_putaway'
      WHEN 'VR' THEN 'vendor_return'
    END,
    (m)[1]
),

all_needed_union AS (
  SELECT tenant_id, 'shipment'::text AS doc_type, ''::text AS sub_type, ''::text AS period_key, needed_last_value
  FROM shipment_needed
  UNION ALL SELECT * FROM sales_invoice_needed
  UNION ALL SELECT * FROM ap_needed
  UNION ALL SELECT * FROM dropship_b2b_needed
  UNION ALL SELECT * FROM cn_needed
  UNION ALL SELECT * FROM dn_needed
  UNION ALL SELECT * FROM shop_order_needed
  UNION ALL SELECT tenant_id, doc_type, sub_type, period_key, needed_last_value
  FROM movement_needed
  WHERE doc_type IS NOT NULL
)

SELECT
  n.doc_type,
  n.tenant_id,
  n.sub_type,
  n.period_key,
  n.needed_last_value,
  coalesce(d.last_value, 0) AS current_last_value,
  n.needed_last_value - coalesce(d.last_value, 0) AS raise_by,
  CASE
    WHEN d.tenant_id IS NULL THEN 'missing_counter_row'
    WHEN n.needed_last_value > d.last_value THEN 'counter_too_low'
    ELSE 'ok'
  END AS status
FROM all_needed_union n
LEFT JOIN public.document_number_counters d
  ON d.tenant_id = n.tenant_id
 AND d.doc_type = n.doc_type
 AND d.sub_type = coalesce(n.sub_type, '')
 AND d.period_key = coalesce(n.period_key, '')
WHERE n.needed_last_value > coalesce(d.last_value, 0)
ORDER BY n.doc_type, n.tenant_id, n.sub_type, n.period_key;


-- =============================================================================
-- 2) Legacy bill numbers (informational — counters may not apply; do not bulk-edit)
-- =============================================================================

SELECT 'legacy_bill_formats' AS section,
  CASE
    WHEN invoice_no ~ '^ORD-' THEN 'shop_order_legacy_ORD'
    WHEN invoice_no ~ '^INV-DS-' THEN 'dropship_b2b_legacy_INV-DS-order'
    WHEN invoice_no ~ '^INV-CN-' OR invoice_no ~ '^INV-DN-' THEN 'adjustment_legacy_INV-CN-DN'
    WHEN invoice_no ~ '^INV-INV-' THEN 'ap_legacy_INV-INV'
    WHEN invoice_no ~ '^INV-(WS|RT|DS)-\d{8}-' THEN 'sales_invoice_legacy_daily'
    WHEN invoice_no ~ '^INV-(WS|RT|DS)-\d{4}-' THEN 'sales_invoice_new_monthly'
    WHEN invoice_no ~ '^AP-' THEN 'ap_new'
    WHEN invoice_no ~ '^DS-\d{4}-' THEN 'dropship_b2b_new'
    WHEN invoice_no ~ '^CN-' OR invoice_no ~ '^DN-' THEN 'adjustment_new'
    ELSE 'other_or_unparsed'
  END AS format_bucket,
  count(*) AS row_count
FROM public.bills
GROUP BY 1, 2
ORDER BY row_count DESC;


SELECT 'legacy_shop_order_formats' AS section,
  CASE
    WHEN order_no ~ '^SO-\d{6}-' THEN 'shop_order_new_SO'
    WHEN order_no ~ '^ORD-' THEN 'shop_order_legacy_ORD'
    ELSE 'shop_order_other'
  END AS format_bucket,
  count(*) AS row_count
FROM public.shop_orders
GROUP BY 1, 2
ORDER BY row_count DESC;


-- =============================================================================
-- 3) Unparsed bills (review if gap report misses a tenant)
-- =============================================================================

SELECT
  b.id,
  b.issued_by_tenant_id AS tenant_id,
  b.invoice_no,
  b.invoice_type,
  b.document_kind,
  b.invoice_date
FROM public.bills b
WHERE b.invoice_no !~ '^INV-(WS|RT|DS)-(\d{4}|\d{8})-(\d+)$'
  AND b.invoice_no !~ '^AP-(\d{4})-(\d+)$'
  AND b.invoice_no !~ '^DS-(\d{4})-(\d+)$'
  AND b.invoice_no !~ '^CN-(WS|RT|DS)-(\d{4})-(\d+)$'
  AND b.invoice_no !~ '^DN-(WS|RT|DS)-(\d{4})-(\d+)$'
  AND b.invoice_no !~ '^INV-DS-'
  AND b.invoice_no !~ '^INV-CN-'
  AND b.invoice_no !~ '^INV-DN-'
  AND b.invoice_no !~ '^INV-INV-'
ORDER BY b.id DESC
LIMIT 200;
