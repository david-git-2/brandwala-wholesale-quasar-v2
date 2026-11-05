CREATE FUNCTION public.delivery_paper_document_allows_papers (
  p_document_type text,
  p_document_id   bigint,
  p_tenant_id     bigint
)
  RETURNS boolean
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_shop_status text;
  v_pbc_status text;
  v_open_lines integer := 0;
BEGIN
  IF v_doc_type = 'shop_order' THEN
    SELECT public.normalize_shop_order_procurement_status(o.status)
    INTO v_shop_status
    FROM public.shop_orders o
    WHERE o.id = p_document_id
      AND o.shop_type_snapshot = 'vendor_catalog';
    IF NOT FOUND THEN RETURN false; END IF;
    IF v_shop_status IN ('procuring', 'dispatch') THEN RETURN true; END IF;
    SELECT count(*)::integer INTO v_open_lines
    FROM public.shop_order_items oi
    INNER JOIN public.preorder_demand pd
      ON pd.source_type = 'shop_order_item'
      AND pd.source_id = oi.id
    WHERE oi.order_id = p_document_id
      AND coalesce(pd.open_quantity, 0) > 0;
    RETURN v_open_lines > 0;
  ELSIF v_doc_type = 'pbc_costing_file' THEN
    SELECT public.normalize_pbc_procurement_status(f.status)
    INTO v_pbc_status
    FROM public.product_based_costing_files f
    WHERE f.id = p_document_id
      AND f.profile_id IS NOT NULL;
    IF NOT FOUND THEN RETURN false; END IF;
    IF v_pbc_status IN ('procuring', 'dispatch') THEN RETURN true; END IF;
    SELECT count(*)::integer INTO v_open_lines
    FROM public.product_based_costing_items pci
    INNER JOIN public.preorder_demand pd
      ON pd.source_type = 'pbc_costing_item'
      AND pd.source_id = pci.id
    WHERE pci.product_based_costing_file_id = p_document_id
      AND coalesce(pd.open_quantity, 0) > 0;
    RETURN v_open_lines > 0;
  END IF;
  RETURN false;
END;
$function$;

GRANT ALL ON FUNCTION public.delivery_paper_document_allows_papers(text, bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.delivery_paper_document_allows_papers(text, bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.delivery_paper_document_allows_papers(text, bigint, bigint) TO service_role;