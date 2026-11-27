CREATE OR REPLACE FUNCTION "public"."update_pp_order_line_supplier"(
    "p_tenant_id" bigint,
    "p_people_group_member_id" bigint,
    "p_line_id" bigint,
    "p_placed_qty" numeric DEFAULT NULL::numeric,
    "p_placement_status" "text" DEFAULT NULL::"text"
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_group_id bigint;
  v_row public.pp_order_lines%ROWTYPE;
  v_placement text := lower(trim(coalesce(p_placement_status, '')));
  v_next_placement text;
  v_not_in_cart boolean;
  v_shipment_status text;
BEGIN
  SELECT r.people_group_id INTO v_group_id
  FROM public._pp_resolve_proxy_supplier_member(p_tenant_id, p_people_group_member_id) r
  LIMIT 1;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Proxy supplier membership required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_row
  FROM public.pp_order_lines l
  WHERE l.id = p_line_id
    AND l.tenant_id = p_tenant_id
    AND l.deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order line not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_row.pp_supplier_group_id IS DISTINCT FROM v_group_id THEN
    RAISE EXCEPTION 'Not allowed for this order line' USING ERRCODE = '42501';
  END IF;

  IF p_placed_qty IS NOT NULL AND p_placed_qty < 0 THEN
    RAISE EXCEPTION 'Placed quantity cannot be negative' USING ERRCODE = '22023';
  END IF;

  v_next_placement := v_row.placement_status;

  IF p_placement_status IS NOT NULL AND v_placement <> '' THEN
    IF v_placement NOT IN ('added_to_cart', 'order_placed') THEN
      RAISE EXCEPTION 'Invalid placement status: %', p_placement_status USING ERRCODE = '22023';
    END IF;

    IF v_placement = 'order_placed' AND v_row.placement_status <> 'added_to_cart' THEN
      IF v_row.placement_status <> 'order_placed' THEN
        RAISE EXCEPTION 'Placement can only advance from added to cart to order placed' USING ERRCODE = '22023';
      END IF;
    END IF;

    IF v_placement = 'added_to_cart' AND v_row.placement_status = 'order_placed' THEN
      RAISE EXCEPTION 'Cannot revert placement to added to cart' USING ERRCODE = '22023';
    END IF;

    IF v_row.placement_status NOT IN ('added_to_cart', 'order_placed')
      AND v_placement <> lower(v_row.placement_status) THEN
      RAISE EXCEPTION 'Placement cannot be changed at this stage' USING ERRCODE = '22023';
    END IF;

    v_next_placement := v_placement;
  END IF;

  IF p_placed_qty IS NOT NULL
    AND v_next_placement NOT IN ('added_to_cart', 'order_placed') THEN
    RAISE EXCEPTION 'Placed quantity cannot be updated at this stage' USING ERRCODE = '22023';
  END IF;

  v_not_in_cart := v_next_placement IN ('none', 'draft', 'requested', 'processing', 'cancelled');

  UPDATE public.pp_order_lines l
  SET placed_qty = CASE WHEN p_placed_qty IS NULL THEN l.placed_qty ELSE p_placed_qty END,
      placement_status = v_next_placement,
      is_added_to_cart = NOT v_not_in_cart,
      added_to_cart_at = CASE
        WHEN v_not_in_cart THEN NULL
        WHEN NOT l.is_added_to_cart THEN now()
        ELSE l.added_to_cart_at
      END,
      status = public.pp_derive_order_line_status_from_placement(v_next_placement),
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

ALTER FUNCTION "public"."update_pp_order_line_supplier"("p_tenant_id" bigint, "p_people_group_member_id" bigint, "p_line_id" bigint, "p_placed_qty" numeric, "p_placement_status" "text") OWNER TO "postgres";

GRANT ALL ON FUNCTION "public"."update_pp_order_line_supplier"(bigint, bigint, bigint, numeric, text) TO "anon", "authenticated", "service_role";