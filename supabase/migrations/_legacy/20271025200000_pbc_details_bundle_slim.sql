CREATE OR REPLACE FUNCTION public.get_product_based_costing_file_details_bundle(
  p_file_id bigint,
  p_limit integer DEFAULT 25,
  p_cursor_sort_order integer DEFAULT NULL,
  p_cursor_id bigint DEFAULT NULL,
  p_conversion_rate numeric DEFAULT NULL,
  p_cargo_rate_kg_gbp numeric DEFAULT NULL,
  p_profit_rate numeric DEFAULT NULL,
  p_vat_rate numeric DEFAULT NULL,
  p_offer_pricing_mode text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_is_first_page boolean;
  v_file jsonb := NULL;
  v_summary jsonb := NULL;
  v_items jsonb;
BEGIN
  IF NOT public.can_view_costing_item(p_file_id) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  v_is_first_page := (p_cursor_sort_order IS NULL AND p_cursor_id IS NULL);

  v_items := public.list_product_based_costing_items(
    p_file_id,
    p_limit,
    p_cursor_sort_order,
    p_cursor_id
  );

  IF v_is_first_page THEN
    SELECT to_jsonb(f.*)
    INTO v_file
    FROM public.product_based_costing_files f
    WHERE f.id = p_file_id;

    v_summary := public.get_product_based_costing_file_summary(
      p_file_id,
      p_conversion_rate,
      p_cargo_rate_kg_gbp,
      p_profit_rate,
      p_vat_rate,
      p_offer_pricing_mode
    );
  END IF;

  RETURN jsonb_build_object(
    'file', v_file,
    'summary', v_summary,
    'items', v_items
  );
END;
$$;
