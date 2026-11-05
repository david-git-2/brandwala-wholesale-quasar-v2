-- global_shipments use parent_tenant_id, not tenant_id

CREATE OR REPLACE FUNCTION public.backfill_document_number_counters_from_tenant_shipments()
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
    h.tenant_id,
    'shipment',
    '',
    '',
    GREATEST(
      h.max_shipment_id,
      coalesce((
        SELECT tsc.last_value
        FROM public.tenant_scoped_counters tsc
        WHERE tsc.tenant_id = h.tenant_id
          AND tsc.scope = 'shipment'
      ), 0)
    )
  FROM (
    SELECT u.tenant_id, max(u.max_shipment_id) AS max_shipment_id
    FROM (
      SELECT gs.parent_tenant_id AS tenant_id, max(gs.tenant_shipment_id)::bigint AS max_shipment_id
      FROM public.global_shipments gs
      WHERE gs.parent_tenant_id IS NOT NULL
        AND gs.tenant_shipment_id IS NOT NULL
      GROUP BY gs.parent_tenant_id
      UNION ALL
      SELECT s.tenant_id, max(s.tenant_shipment_id)::bigint AS max_shipment_id
      FROM public.shipments s
      GROUP BY s.tenant_id
    ) u
    GROUP BY u.tenant_id
  ) h
  ON CONFLICT (tenant_id, doc_type, sub_type, period_key)
  DO UPDATE SET last_value = GREATEST(public.document_number_counters.last_value, EXCLUDED.last_value);

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
