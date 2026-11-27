CREATE OR REPLACE FUNCTION "public"."update_pp_order_line"(
    "p_tenant_id" bigint,
    "p_request_id" bigint,
    "p_line_id" bigint,
    "p_url" "text",
    "p_needed_qty" numeric,
    "p_description" "text" DEFAULT NULL::"text"
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_status text;
  v_url text := trim(coalesce(p_url, ''));
  v_desc text := nullif(trim(coalesce(p_description, '')), '');
  v_qty numeric := p_needed_qty;
  v_row public.pp_order_lines%ROWTYPE;
BEGIN
  SELECT a.request_status INTO v_status
  FROM public._pp_assert_customer_request_access(p_tenant_id, p_request_id) a
  LIMIT 1;

  IF v_status <> 'draft' THEN
    RAISE EXCEPTION 'Only draft requests can be edited' USING ERRCODE = '22023';
  END IF;

  IF length(v_url) = 0 THEN
    RAISE EXCEPTION 'URL is required' USING ERRCODE = '22023';
  END IF;

  IF v_qty IS NULL OR v_qty <= 0 THEN
    RAISE EXCEPTION 'Quantity must be positive' USING ERRCODE = '22023';
  END IF;

  UPDATE public.pp_order_lines l
  SET url = v_url,
      needed_qty = v_qty,
      description = v_desc,
      updated_at = now()
  WHERE l.id = p_line_id
    AND l.tenant_id = p_tenant_id
    AND l.purchase_request_id = p_request_id
    AND l.deleted_at IS NULL
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order line not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN jsonb_build_object(
    'id', v_row.id,
    'purchase_request_id', v_row.purchase_request_id,
    'url', v_row.url,
    'needed_qty', v_row.needed_qty,
    'description', v_row.description,
    'status', v_row.status,
    'created_at', v_row.created_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION "public"."delete_pp_order_line"(
    "p_tenant_id" bigint,
    "p_request_id" bigint,
    "p_line_id" bigint
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_status text;
BEGIN
  SELECT a.request_status INTO v_status
  FROM public._pp_assert_customer_request_access(p_tenant_id, p_request_id) a
  LIMIT 1;

  IF v_status <> 'draft' THEN
    RAISE EXCEPTION 'Only draft requests can be edited' USING ERRCODE = '22023';
  END IF;

  UPDATE public.pp_order_lines l
  SET deleted_at = now(),
      updated_at = now()
  WHERE l.id = p_line_id
    AND l.tenant_id = p_tenant_id
    AND l.purchase_request_id = p_request_id
    AND l.deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order line not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN jsonb_build_object('id', p_line_id, 'deleted', true);
END;
$$;

ALTER FUNCTION "public"."update_pp_order_line"(bigint, bigint, bigint, text, numeric, text) OWNER TO "postgres";
ALTER FUNCTION "public"."delete_pp_order_line"(bigint, bigint, bigint) OWNER TO "postgres";
GRANT ALL ON FUNCTION public.update_pp_order_line(bigint, bigint, bigint, text, numeric, text) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.delete_pp_order_line(bigint, bigint, bigint) TO anon, authenticated, service_role;