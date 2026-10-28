-- BP20 prep: backfill shipment AP source plug fields; void unpaid duplicate active keys

UPDATE public.bills b
SET
  source_type = coalesce(b.source_type, 'shipment_cost'),
  source_id = coalesce(b.source_id, b.ap_shipment_id::text),
  source_key = coalesce(nullif(btrim(b.source_key), ''), b.ap_kind),
  updated_at = now()
WHERE b.invoice_type = 'ap'::public.global_invoice_type
  AND b.document_kind = 'standard'::public.bill_document_kind
  AND b.ap_shipment_id IS NOT NULL
  AND (
    b.source_type IS NULL
    OR b.source_id IS NULL
    OR nullif(btrim(b.source_key), '') IS NULL
  );

WITH ranked AS (
  SELECT
    b.id,
    row_number() OVER (
      PARTITION BY b.parent_tenant_id, b.source_type, b.source_id, coalesce(b.source_key, ''::text)
      ORDER BY b.id ASC
    ) AS rn
  FROM public.bills b
  WHERE b.document_kind = 'standard'::public.bill_document_kind
    AND b.source_type IS NOT NULL
    AND b.source_id IS NOT NULL
    AND b.invoice_status <> 'voided'::public.global_invoice_status
)
UPDATE public.bills b
SET invoice_status = 'voided'::public.global_invoice_status, updated_at = now()
FROM ranked r
WHERE b.id = r.id
  AND r.rn > 1
  AND coalesce(b.paid_amount, 0) = 0;
