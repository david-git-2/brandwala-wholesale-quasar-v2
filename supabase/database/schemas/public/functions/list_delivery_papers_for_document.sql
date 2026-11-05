CREATE FUNCTION public.list_delivery_papers_for_document (
  p_tenant_id     bigint,
  p_document_type text,
  p_document_id   bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_source_type public.delivery_paper_source_type;
  v_papers jsonb := '[]'::jsonb;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  IF p_document_id IS NULL THEN
    RAISE EXCEPTION 'document_id is required';
  END IF;
  IF v_doc_type NOT IN ('shop_order', 'pbc_costing_file') THEN
    RAISE EXCEPTION 'invalid document_type: %', p_document_type;
  END IF;

  v_source_type := v_doc_type::public.delivery_paper_source_type;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', dp.id,
        'status', dp.status,
        'created_at', dp.created_at,
        'updated_at', dp.updated_at,
        'delivery_date', dp.delivery_date,
        'note', dp.note,
        'line_count', (
          SELECT coalesce(sum(jsonb_array_length(dpl.splits)), 0)::integer
          FROM public.delivery_paper_line dpl
          WHERE dpl.delivery_paper_id = dp.id
        )
      )
      ORDER BY dp.created_at DESC, dp.id DESC
    ),
    '[]'::jsonb
  )
  INTO v_papers
  FROM public.delivery_paper dp
  WHERE dp.source_type = v_source_type
    AND dp.source_id = p_document_id;

  RETURN jsonb_build_object('papers', v_papers);
END;
$function$;

GRANT ALL ON FUNCTION public.list_delivery_papers_for_document(bigint, text, bigint) TO anon;

GRANT ALL ON FUNCTION public.list_delivery_papers_for_document(bigint, text, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_delivery_papers_for_document(bigint, text, bigint) TO service_role;