CREATE FUNCTION public.get_procurement_demand_buy_document (
  p_tenant_id        bigint,
  p_document_type    text,
  p_document_id      bigint,
  p_search           text    DEFAULT NULL::text,
  p_limit            integer DEFAULT 50,
  p_cursor_source_id bigint  DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_items_payload jsonb;
  v_document jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_document_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id and document_id are required';
  END IF;
  IF v_doc_type NOT IN ('shop_order', 'pbc_costing_file') THEN
    RAISE EXCEPTION 'invalid document_type: %', p_document_type;
  END IF;

  v_items_payload := public.list_procurement_demand_group_items(
    p_tenant_id,
    v_doc_type,
    p_document_id,
    p_search,
    p_limit,
    p_cursor_source_id
  );

  SELECT doc INTO v_document
  FROM (
    SELECT (d.value) AS doc
    FROM jsonb_array_elements(
      (public.list_procurement_demand_buy_documents(
        p_tenant_id,
        null,
        null,
        500,
        0
      )->'documents')
    ) AS d(value)
    WHERE lower(trim(coalesce(d.value->>'document_type', ''))) = v_doc_type
      AND (d.value->>'document_id')::bigint = p_document_id
    LIMIT 1
  ) sub;

  IF v_document IS NULL THEN
    RAISE EXCEPTION 'document not found or not in procuring';
  END IF;

  RETURN jsonb_build_object(
    'document', v_document,
    'items', coalesce(v_items_payload->'items', '[]'::jsonb),
    'meta', coalesce(v_items_payload->'meta', '{}'::jsonb)
  );
END;
$function$;

GRANT ALL ON FUNCTION public.get_procurement_demand_buy_document(bigint, text, bigint, text, integer, bigint) TO anon;

GRANT ALL ON FUNCTION public.get_procurement_demand_buy_document(bigint, text, bigint, text, integer, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_procurement_demand_buy_document(bigint, text, bigint, text, integer, bigint) TO service_role;