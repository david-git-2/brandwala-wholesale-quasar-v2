CREATE OR REPLACE FUNCTION public.add_pp_order_line_staff(
    p_tenant_id bigint,
    p_request_id bigint,
    p_url text,
    p_needed_qty numeric,
    p_description text DEFAULT NULL::text
) RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_req public.pp_purchase_requests%ROWTYPE;
  v_url text := trim(coalesce(p_url, ''));
  v_desc text := nullif(trim(coalesce(p_description, '')), '');
  v_qty numeric := p_needed_qty;
  v_row public.pp_order_lines%ROWTYPE;
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

  INSERT INTO public.pp_order_lines (
    tenant_id,
    purchase_request_id,
    pp_customer_group_id,
    url,
    needed_qty,
    description,
    status,
    placement_status
  ) VALUES (
    p_tenant_id,
    p_request_id,
    v_req.people_group_id,
    v_url,
    v_qty,
    v_desc,
    'requested',
    'none'
  )
  RETURNING * INTO v_row;

  RETURN public._pp_order_line_to_json(v_row, NULL);
END;
$$;

ALTER FUNCTION public.add_pp_order_line_staff(
  bigint,
  bigint,
  text,
  numeric,
  text
) OWNER TO postgres;

GRANT ALL ON FUNCTION public.add_pp_order_line_staff(
  bigint,
  bigint,
  text,
  numeric,
  text
) TO anon, authenticated, service_role;