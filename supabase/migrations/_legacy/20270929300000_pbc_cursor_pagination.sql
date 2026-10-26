DROP FUNCTION IF EXISTS public.list_product_based_costing_files(integer, integer, text, text, bigint);

CREATE INDEX IF NOT EXISTS product_based_costing_files_tenant_created_at_id_idx
  ON public.product_based_costing_files (tenant_id, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS product_based_costing_items_file_sort_order_id_idx
  ON public.product_based_costing_items (product_based_costing_file_id, sort_order, id);

CREATE OR REPLACE FUNCTION public.list_product_based_costing_files(
  p_search text DEFAULT NULL,
  p_status text DEFAULT NULL,
  p_tenant_id bigint DEFAULT NULL,
  p_limit integer DEFAULT 20,
  p_cursor_created_at timestamptz DEFAULT NULL,
  p_cursor_id bigint DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO public
AS $$
DECLARE
  v_limit integer;
  v_rows jsonb;
  v_n integer;
  v_has_more boolean := false;
  v_next_cursor jsonb := NULL;
  v_last_created_at timestamptz;
  v_last_id bigint;
BEGIN
  v_limit := greatest(1, least(coalesce(p_limit, 20), 100));

  SELECT coalesce(jsonb_agg(q.row_json ORDER BY q.created_at DESC, q.id DESC), '[]'::jsonb)
  INTO v_rows
  FROM (
    SELECT
      f.created_at,
      f.id,
      to_jsonb(f) || jsonb_build_object('customer_group_name', cg.name) AS row_json
    FROM public.product_based_costing_files f
    LEFT JOIN public.customer_groups cg ON cg.id = f.customer_group_id
    WHERE
      (p_tenant_id IS NULL OR f.tenant_id = p_tenant_id)
      AND (
        coalesce(trim(p_search), '') = ''
        OR coalesce(f.name, '') ILIKE ('%' || trim(p_search) || '%')
        OR coalesce(f.order_for, '') ILIKE ('%' || trim(p_search) || '%')
        OR coalesce(f.note, '') ILIKE ('%' || trim(p_search) || '%')
      )
      AND (
        coalesce(trim(p_status), '') = ''
        OR f.status = trim(p_status)
        OR (trim(p_status) = 'procuring' AND f.status = 'placing_order')
        OR (trim(p_status) = 'delivered' AND f.status = 'invoicing')
      )
      AND (
        p_cursor_created_at IS NULL
        OR p_cursor_id IS NULL
        OR (f.created_at, f.id) < (p_cursor_created_at, p_cursor_id)
      )
    ORDER BY f.created_at DESC, f.id DESC
    LIMIT v_limit + 1
  ) q;

  v_n := jsonb_array_length(v_rows);
  IF v_n > v_limit THEN
    v_has_more := true;
    SELECT elem->>'created_at', (elem->>'id')::bigint
    INTO v_last_created_at, v_last_id
    FROM jsonb_array_elements(v_rows) WITH ORDINALITY AS t(elem, ord)
    WHERE ord = v_limit;

    v_next_cursor := jsonb_build_object(
      'created_at', v_last_created_at,
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
$$;

CREATE OR REPLACE FUNCTION public.list_product_based_costing_items(
  p_file_id bigint,
  p_limit integer DEFAULT 25,
  p_cursor_sort_order integer DEFAULT NULL,
  p_cursor_id bigint DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
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
$$;

GRANT ALL ON FUNCTION public.list_product_based_costing_files(
  text, text, bigint, integer, timestamptz, bigint
) TO authenticated;

GRANT ALL ON FUNCTION public.list_product_based_costing_items(
  bigint, integer, integer, bigint
) TO authenticated;
