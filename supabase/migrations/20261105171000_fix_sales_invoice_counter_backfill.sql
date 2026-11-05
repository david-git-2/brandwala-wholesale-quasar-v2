-- Legacy sales_invoice_counters are daily (YYYYMMDD); document numbering uses monthly YYMM buckets.

CREATE OR REPLACE FUNCTION public.backfill_document_number_counters_from_sales_invoice_counters()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_count integer := 0;
BEGIN
  INSERT INTO public.document_number_counters (tenant_id, doc_type, sub_type, period_key, last_value)
  SELECT
    sic.tenant_id,
    'sales_invoice',
    CASE sic.invoice_type
      WHEN 'wholesale'::public.global_invoice_type THEN 'WS'
      WHEN 'retail'::public.global_invoice_type THEN 'RT'
      WHEN 'dropship'::public.global_invoice_type THEN 'DS'
      ELSE 'WS'
    END,
    substring(sic.date_key from 3 for 4),
    max(sic.last_value)
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
  ON CONFLICT (tenant_id, doc_type, sub_type, period_key)
  DO UPDATE SET last_value = GREATEST(public.document_number_counters.last_value, EXCLUDED.last_value);

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
