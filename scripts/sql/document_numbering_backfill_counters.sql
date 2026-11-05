-- Counter backfill for production (run sections after each deploy phase).
-- Idempotent: uses GREATEST on conflict.

-- Phase 3: sales invoice sequences from legacy counter table
-- (daily date_key rows collapse to monthly YYMM buckets; function uses max(last_value) per bucket)
SELECT public.backfill_document_number_counters_from_sales_invoice_counters();

-- Phase 4: shipment numeric high-water from existing rows
SELECT public.backfill_document_number_counters_from_tenant_shipments();

-- Phase 4 optional: movement numbers from existing movement_no (MOV prefix, current month bucket)
INSERT INTO public.document_number_counters (tenant_id, doc_type, sub_type, period_key, last_value)
SELECT
  sm.tenant_id,
  'stock_movement',
  '',
  to_char(sm.created_at AT TIME ZONE coalesce(nullif(btrim(t.preference->>'timezone'), ''), 'UTC'), 'YYMMDD'),
  max(
    nullif(
      regexp_replace(sm.movement_no, '^MOV-[0-9]{8}-([0-9]+)$', '\1'),
      sm.movement_no
    )::bigint
  )
FROM public.stock_movements sm
JOIN public.tenants t ON t.id = sm.tenant_id
WHERE sm.movement_no ~ '^MOV-[0-9]{8}-[0-9]+$'
GROUP BY sm.tenant_id, to_char(sm.created_at AT TIME ZONE coalesce(nullif(btrim(t.preference->>'timezone'), ''), 'UTC'), 'YYMMDD')
ON CONFLICT (tenant_id, doc_type, sub_type, period_key)
DO UPDATE SET last_value = GREATEST(public.document_number_counters.last_value, EXCLUDED.last_value);
