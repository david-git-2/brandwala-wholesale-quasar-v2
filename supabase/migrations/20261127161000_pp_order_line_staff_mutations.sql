CREATE OR REPLACE FUNCTION "public"."update_pp_order_line_staff"(
    "p_tenant_id" bigint,
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
  v_url text := trim(coalesce(p_url, ''));
  v_desc text := nullif(trim(coalesce(p_description, '')), '');
  v_qty numeric := p_needed_qty;
  v_row public.pp_order_lines%ROWTYPE;
  v_shipment_status text;
BEGIN
  IF NOT "public"."has_active_tenant_membership"("p_tenant_id") THEN
    RAISE EXCEPTION 'Not allowed for tenant %', "p_tenant_id" USING ERRCODE = '42501';
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
    AND l.deleted_at IS NULL
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order line not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT s.status INTO v_shipment_status
  FROM public.pp_shipment s
  WHERE s.id = v_row.shipment_id
    AND s.deleted_at IS NULL;

  RETURN public._pp_order_line_to_json(v_row, v_shipment_status);
END;
$$;

CREATE OR REPLACE FUNCTION "public"."delete_pp_order_line_staff"(
    "p_tenant_id" bigint,
    "p_line_id" bigint
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NOT "public"."has_active_tenant_membership"("p_tenant_id") THEN
    RAISE EXCEPTION 'Not allowed for tenant %', "p_tenant_id" USING ERRCODE = '42501';
  END IF;

  UPDATE public.pp_order_lines l
  SET deleted_at = now(),
      updated_at = now()
  WHERE l.id = p_line_id
    AND l.tenant_id = p_tenant_id
    AND l.deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order line not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN jsonb_build_object('id', p_line_id, 'deleted', true);
END;
$$;

GRANT ALL ON FUNCTION "public"."update_pp_order_line_staff"(bigint, bigint, text, numeric, text) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."delete_pp_order_line_staff"(bigint, bigint) TO "anon", "authenticated", "service_role";