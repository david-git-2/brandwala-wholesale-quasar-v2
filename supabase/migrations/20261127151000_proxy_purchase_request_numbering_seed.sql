INSERT INTO public.document_number_configs (
  tenant_id, doc_type, prefix, sub_type_mode, period, padding, separator, timezone, is_active
)
SELECT
  NULL::bigint,
  'proxy_purchase_request',
  'PPR',
  'none',
  'day',
  4::smallint,
  '-',
  'UTC',
  true
WHERE NOT EXISTS (
  SELECT 1
  FROM public.document_number_configs c
  WHERE c.tenant_id IS NULL AND c.doc_type = 'proxy_purchase_request'
);