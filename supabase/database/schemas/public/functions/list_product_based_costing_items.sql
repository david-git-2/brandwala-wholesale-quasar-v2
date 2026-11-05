CREATE FUNCTION public.list_product_based_costing_items (
  p_file_id           bigint,
  p_limit             integer DEFAULT 25,
  p_cursor_sort_order integer DEFAULT NULL::integer,
  p_cursor_id         bigint  DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_limit integer;
  v_rows jsonb;
  v_n integer;
  v_has_more boolean := false;
  v_next_cursor jsonb := NULL;
  v_last_sort_order integer;
  v_last_id bigint;
BEGIN
  IF NOT public.can_view_costing_item(p_file_id) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  v_limit := greatest(1, least(coalesce(p_limit, 25), 100));

  SELECT coalesce(jsonb_agg(to_jsonb(i) ORDER BY i.sort_order ASC, i.id ASC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT i.*
    FROM public.product_based_costing_items i
    WHERE i.product_based_costing_file_id = p_file_id
      AND (
        p_cursor_sort_order IS NULL
        OR p_cursor_id IS NULL
        OR (i.sort_order, i.id) > (p_cursor_sort_order, p_cursor_id)
      )
    ORDER BY i.sort_order ASC, i.id ASC
    LIMIT v_limit + 1
  ) i;

  v_n := jsonb_array_length(v_rows);
  IF v_n > v_limit THEN
    v_has_more := true;
    SELECT (elem->>'sort_order')::integer, (elem->>'id')::bigint
    INTO v_last_sort_order, v_last_id
    FROM jsonb_array_elements(v_rows) WITH ORDINALITY AS t(elem, ord)
    WHERE ord = v_limit;

    v_next_cursor := jsonb_build_object(
      'sort_order', v_last_sort_order,
      'id', v_last_id
    );

    SELECT coalesce(jsonb_agg(elem ORDER BY ord), '[]'::jsonb)
    INTO v_rows
    FROM (
      SELECT elem, ord
      FROM jsonb_array_elements(v_rows) WITH ORDINALITY AS t(elem, ord)
      WHERE ord <= v_limit
    ) trimmed;
  END IF;

  RETURN jsonb_build_object(
    'data', v_rows,
    'meta', jsonb_build_object(
      'has_more', v_has_more,
      'next_cursor', v_next_cursor,
      'limit', v_limit
    )
  );
END;
$function$;

GRANT ALL ON FUNCTION public.list_product_based_costing_items(bigint, integer, integer, bigint) TO anon;

GRANT ALL ON FUNCTION public.list_product_based_costing_items(bigint, integer, integer, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_product_based_costing_items(bigint, integer, integer, bigint) TO service_role;