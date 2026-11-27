DROP FUNCTION IF EXISTS public.add_pp_order_line_staff(bigint, bigint, text, numeric, text);

CREATE OR REPLACE FUNCTION public.add_pp_order_line_staff(
    p_tenant_id bigint,
    p_request_id bigint,
    p_url text,
    p_needed_qty numeric,
    p_tracking_url text DEFAULT NULL::text,
    p_description text DEFAULT NULL::text,
    p_product_name text DEFAULT NULL::text,
    p_image_url text DEFAULT NULL::text,
    p_unit_price numeric DEFAULT NULL::numeric,
    p_pp_supplier_group_id bigint DEFAULT NULL::bigint,
    p_shipment_id bigint DEFAULT NULL::bigint,
    p_is_added_to_cart boolean DEFAULT NULL::boolean,
    p_placement_status text DEFAULT NULL::text,
    p_placed_qty numeric DEFAULT NULL::numeric,
    p_received_qty numeric DEFAULT NULL::numeric
) RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_req public.pp_purchase_requests%ROWTYPE;
  v_url text := trim(coalesce(p_url, ''));
  v_tracking text := nullif(trim(coalesce(p_tracking_url, '')), '');
  v_desc text := nullif(trim(coalesce(p_description, '')), '');
  v_product_name text := nullif(trim(coalesce(p_product_name, '')), '');
  v_image_url text := nullif(trim(coalesce(p_image_url, '')), '');
  v_qty numeric := p_needed_qty;
  v_row public.pp_order_lines%ROWTYPE;
  v_shipment_status text;
  v_placement text := lower(trim(coalesce(p_placement_status, 'requested')));
  v_final_placement text := v_placement;
  v_not_in_cart boolean;
  v_in_cart boolean;
  v_line_status text;
BEGIN
  IF NOT public.has_active_tenant_membership(p_tenant_id) THEN
    RAISE EXCEPTION 'Not allowed for tenant %', p_tenant_id USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_req
  FROM public.pp_purchase_requests r
  WHERE r.id = p_request_id
    AND r.tenant_id = p_tenant_id
    AND r.deleted_at IS NULL;

  IF v_req.id IS NULL THEN
    RAISE EXCEPTION 'Purchase request not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_req.status <> 'requested' THEN
    RAISE EXCEPTION 'Only requested purchase requests can receive new items' USING ERRCODE = '22023';
  END IF;

  IF length(v_url) = 0 THEN
    RAISE EXCEPTION 'URL is required' USING ERRCODE = '22023';
  END IF;

  IF v_qty IS NULL OR v_qty <= 0 THEN
    RAISE EXCEPTION 'Quantity must be positive' USING ERRCODE = '22023';
  END IF;

  IF p_received_qty IS NOT NULL AND p_received_qty < 0 THEN
    RAISE EXCEPTION 'Received quantity cannot be negative' USING ERRCODE = '22023';
  END IF;

  IF v_final_placement NOT IN (
    'none', 'draft', 'requested', 'processing', 'cancelled',
    'added_to_cart', 'order_placed', 'cargo_warehouse',
    'in_flight', 'local_warehouse', 'delivered', 'lost'
  ) THEN
    RAISE EXCEPTION 'Invalid placement status: %', p_placement_status USING ERRCODE = '22023';
  END IF;

  IF p_pp_supplier_group_id IS NOT NULL THEN
    PERFORM 1
    FROM public.pp_people_group g
    WHERE g.id = p_pp_supplier_group_id
      AND g.tenant_id = p_tenant_id
      AND g.type = 'supplier'
      AND g.deleted_at IS NULL;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Invalid supplier group' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF p_shipment_id IS NOT NULL THEN
    PERFORM 1
    FROM public.pp_shipment sh
    WHERE sh.id = p_shipment_id
      AND sh.tenant_id = p_tenant_id
      AND sh.deleted_at IS NULL;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Invalid shipment' USING ERRCODE = '22023';
    END IF;
  END IF;

  v_not_in_cart := v_final_placement IN ('none', 'draft', 'requested', 'processing', 'cancelled');
  v_in_cart := CASE
    WHEN p_is_added_to_cart IS NOT NULL THEN p_is_added_to_cart
    ELSE NOT v_not_in_cart
  END;
  v_line_status := public.pp_derive_order_line_status_from_placement(v_final_placement);

  INSERT INTO public.pp_order_lines (
    tenant_id,
    purchase_request_id,
    pp_customer_group_id,
    url,
    tracking_url,
    needed_qty,
    description,
    product_name,
    image_url,
    unit_price,
    pp_supplier_group_id,
    shipment_id,
    placement_status,
    is_added_to_cart,
    added_to_cart_at,
    placed_qty,
    received_qty,
    status
  ) VALUES (
    p_tenant_id,
    p_request_id,
    v_req.people_group_id,
    v_url,
    v_tracking,
    v_qty,
    v_desc,
    v_product_name,
    v_image_url,
    p_unit_price,
    p_pp_supplier_group_id,
    p_shipment_id,
    v_final_placement,
    v_in_cart,
    CASE WHEN v_in_cart THEN now() ELSE NULL END,
    p_placed_qty,
    p_received_qty,
    v_line_status
  )
  RETURNING * INTO v_row;

  SELECT s.status INTO v_shipment_status
  FROM public.pp_shipment s
  WHERE s.id = v_row.shipment_id
    AND s.deleted_at IS NULL;

  RETURN public._pp_order_line_to_json(v_row, v_shipment_status);
END;
$$;

ALTER FUNCTION public.add_pp_order_line_staff(
  bigint,
  bigint,
  text,
  numeric,
  text,
  text,
  text,
  text,
  numeric,
  bigint,
  bigint,
  boolean,
  text,
  numeric,
  numeric
) OWNER TO postgres;

GRANT ALL ON FUNCTION public.add_pp_order_line_staff(
  bigint,
  bigint,
  text,
  numeric,
  text,
  text,
  text,
  text,
  numeric,
  bigint,
  bigint,
  boolean,
  text,
  numeric,
  numeric
) TO anon, authenticated, service_role;