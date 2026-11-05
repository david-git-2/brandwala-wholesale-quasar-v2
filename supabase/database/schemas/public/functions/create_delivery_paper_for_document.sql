CREATE FUNCTION public.create_delivery_paper_for_document (
  p_tenant_id     bigint,
  p_document_type text,
  p_document_id   bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_source_type public.delivery_paper_source_type;
  v_parent_tenant_id bigint;
  v_profile_id bigint;
  v_paper_id bigint;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  IF p_document_id IS NULL THEN
    RAISE EXCEPTION 'document_id is required';
  END IF;
  IF v_doc_type NOT IN ('shop_order', 'pbc_costing_file') THEN
    RAISE EXCEPTION 'invalid document_type: %', p_document_type;
  END IF;
  IF NOT public.delivery_paper_document_allows_papers(v_doc_type, p_document_id, p_tenant_id) THEN
    RAISE EXCEPTION 'document does not allow new delivery papers';
  END IF;

  v_source_type := v_doc_type::public.delivery_paper_source_type;

  IF v_doc_type = 'shop_order' THEN
    SELECT
      public.resolve_parent_tenant_id(o.tenant_id),
      o.profile_id
    INTO v_parent_tenant_id, v_profile_id
    FROM public.shop_orders o
    WHERE o.id = p_document_id
      AND o.shop_type_snapshot = 'vendor_catalog';
    IF NOT FOUND THEN RAISE EXCEPTION 'shop order not found'; END IF;
  ELSE
    SELECT
      public.resolve_parent_tenant_id(f.tenant_id),
      f.profile_id
    INTO v_parent_tenant_id, v_profile_id
    FROM public.product_based_costing_files f
    WHERE f.id = p_document_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'costing file not found'; END IF;
  END IF;

  INSERT INTO public.delivery_paper (
    parent_tenant_id,
    source_type,
    source_id,
    profile_id,
    status
  ) VALUES (
    v_parent_tenant_id,
    v_source_type,
    p_document_id,
    v_profile_id,
    'draft'::public.delivery_paper_status
  )
  RETURNING id INTO v_paper_id;

  RETURN jsonb_build_object(
    'id', v_paper_id,
    'status', 'draft',
    'created_at', now()
  );
END;
$function$;

GRANT ALL ON FUNCTION public.create_delivery_paper_for_document(bigint, text, bigint) TO anon;

GRANT ALL ON FUNCTION public.create_delivery_paper_for_document(bigint, text, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.create_delivery_paper_for_document(bigint, text, bigint) TO service_role;