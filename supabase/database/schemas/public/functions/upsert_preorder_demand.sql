CREATE FUNCTION public.upsert_preorder_demand (
  p_tenant_id         bigint,
  p_source_type       public.preorder_demand_source_type,
  p_source_id         bigint,
  p_vendor_id         bigint                             DEFAULT NULL::bigint,
  p_placed_quantity   integer                            DEFAULT NULL::integer,
  p_stock_picks       jsonb                              DEFAULT NULL::jsonb,
  p_notes             text                               DEFAULT NULL::text,
  p_vendor_placements jsonb                              DEFAULT NULL::jsonb
)
  RETURNS public.preorder_demand
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_row public.preorder_demand;
  v_line_tenant_id bigint;
  v_doc_status text;
  v_open_qty integer;
  v_delivered integer;
  v_placed integer;
  v_placements jsonb;
  v_vendor_code text;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;
  IF p_source_id IS NULL THEN
    RAISE EXCEPTION 'source_id is required';
  END IF;

  SELECT g.tenant_id, g.open_qty, g.document_status
  INTO v_line_tenant_id, v_open_qty, v_doc_status
  FROM public.get_procurement_demand_open_qty(p_source_type, p_source_id) g;

  IF v_line_tenant_id IS NULL THEN
    RAISE EXCEPTION 'demand line not found';
  END IF;

  IF NOT public.can_access_preorder_demand_tenant(p_tenant_id)
    AND NOT public.can_access_preorder_demand_tenant(v_line_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  IF v_line_tenant_id <> p_tenant_id THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.tenants t
      WHERE t.id = v_line_tenant_id
        AND t.parent_id = p_tenant_id
        AND public.user_can_manage_parent_tenant(p_tenant_id)
    ) THEN
      RAISE EXCEPTION 'tenant mismatch for demand line';
    END IF;
  END IF;

  IF v_doc_status NOT IN ('procuring', 'dispatch', 'packed') THEN
    RAISE EXCEPTION 'document is not open for preorder demand updates';
  END IF;

  IF (p_placed_quantity IS NOT NULL OR p_vendor_placements IS NOT NULL)
    AND v_doc_status <> 'procuring' THEN
    RAISE EXCEPTION 'vendor placements can only be updated while procuring';
  END IF;

  IF p_stock_picks IS NOT NULL AND v_doc_status NOT IN ('procuring', 'dispatch', 'packed') THEN
    RAISE EXCEPTION 'stock_picks can only be updated while procuring or dispatch';
  END IF;

  IF p_vendor_placements IS NOT NULL THEN
    IF NOT public.validate_preorder_vendor_placements(p_vendor_placements) THEN
      RAISE EXCEPTION 'invalid vendor_placements payload';
    END IF;
    v_placements := p_vendor_placements;
    v_placed := public.sum_preorder_vendor_placements(v_placements);
    IF v_placed > coalesce(v_open_qty, 0) THEN
      RAISE EXCEPTION 'placed quantity cannot exceed need quantity';
    END IF;
  ELSIF p_placed_quantity IS NOT NULL THEN
    IF coalesce(p_placed_quantity, 0) < 0 THEN
      RAISE EXCEPTION 'placed_quantity cannot be negative';
    END IF;
    SELECT pd.* INTO v_row
    FROM public.preorder_demand pd
    WHERE pd.source_type = p_source_type AND pd.source_id = p_source_id;
    SELECT nullif(trim(v.code), '') INTO v_vendor_code
    FROM public.vendors v
    WHERE v.id = coalesce(p_vendor_id, v_row.vendor_id);
    v_vendor_code := coalesce(v_vendor_code, 'unknown');
    v_placements := jsonb_build_array(
      jsonb_build_object('vendor_code', v_vendor_code, 'quantity', p_placed_quantity)
    );
    v_placed := p_placed_quantity;
    IF v_placed > coalesce(v_open_qty, 0) THEN
      RAISE EXCEPTION 'placed quantity cannot exceed need quantity';
    END IF;
  ELSE
    v_placements := NULL;
  END IF;

  IF p_stock_picks IS NOT NULL AND NOT public.validate_preorder_stock_picks(p_stock_picks) THEN
    RAISE EXCEPTION 'invalid stock_picks payload';
  END IF;

  v_delivered := CASE
    WHEN p_stock_picks IS NOT NULL THEN public.sum_preorder_stock_picks(p_stock_picks)
    ELSE NULL
  END;

  SELECT pd.* INTO v_row
  FROM public.preorder_demand pd
  WHERE pd.source_type = p_source_type
    AND pd.source_id = p_source_id;

  IF v_placements IS NULL THEN
    IF found THEN
      v_placed := coalesce(
        public.sum_preorder_vendor_placements(v_row.vendor_placements),
        v_row.placed_quantity,
        0
      );
    ELSE
      v_placed := 0;
    END IF;
  END IF;

  IF v_delivered IS NOT NULL AND v_delivered > coalesce(v_open_qty, 0) THEN
    RAISE EXCEPTION 'delivered_quantity cannot exceed need quantity';
  END IF;

  INSERT INTO public.preorder_demand (
    tenant_id,
    parent_tenant_id,
    source_type,
    source_id,
    vendor_id,
    placed_quantity,
    delivered_quantity,
    vendor_placements,
    stock_picks,
    notes,
    updated_by_user_id
  ) VALUES (
    v_line_tenant_id,
    public.resolve_parent_tenant_id(v_line_tenant_id),
    p_source_type,
    p_source_id,
    coalesce(p_vendor_id, CASE WHEN found THEN v_row.vendor_id ELSE NULL END),
    v_placed,
    coalesce(v_delivered, CASE WHEN found THEN v_row.delivered_quantity ELSE 0 END, 0),
    coalesce(v_placements, CASE WHEN found THEN v_row.vendor_placements ELSE '[]'::jsonb END, '[]'::jsonb),
    coalesce(p_stock_picks, CASE WHEN found THEN v_row.stock_picks ELSE '[]'::jsonb END, '[]'::jsonb),
    coalesce(nullif(trim(p_notes), ''), CASE WHEN found THEN v_row.notes ELSE NULL END),
    auth.uid()
  )
  ON CONFLICT (source_type, source_id) DO UPDATE SET
    parent_tenant_id = coalesce(public.preorder_demand.parent_tenant_id, excluded.parent_tenant_id),
    vendor_id = CASE WHEN p_vendor_id IS NOT NULL THEN p_vendor_id ELSE preorder_demand.vendor_id END,
    placed_quantity = v_placed,
    vendor_placements = CASE
      WHEN v_placements IS NOT NULL THEN v_placements
      ELSE preorder_demand.vendor_placements
    END,
    delivered_quantity = CASE
      WHEN v_delivered IS NOT NULL THEN v_delivered
      ELSE preorder_demand.delivered_quantity
    END,
    open_quantity = greatest(
      coalesce(preorder_demand.confirmed_quantity, 0)
        - CASE WHEN v_delivered IS NOT NULL THEN v_delivered ELSE preorder_demand.delivered_quantity END,
      0
    ),
    stock_picks = CASE WHEN p_stock_picks IS NOT NULL THEN p_stock_picks ELSE preorder_demand.stock_picks END,
    notes = CASE WHEN p_notes IS NOT NULL THEN nullif(trim(p_notes), '') ELSE preorder_demand.notes END,
    updated_by_user_id = auth.uid(),
    updated_at = now()
  RETURNING * INTO v_row;

  IF p_stock_picks IS NOT NULL OR jsonb_array_length(coalesce(v_row.stock_picks, '[]'::jsonb)) > 0 THEN
    PERFORM public.sync_delivery_paper_lines_for_demand(v_row.id);
  END IF;

  RETURN v_row;
END;
$function$;

CREATE FUNCTION public.upsert_preorder_demand (
  p_tenant_id       bigint,
  p_source_type     public.preorder_demand_source_type,
  p_source_id       bigint,
  p_vendor_id       bigint                             DEFAULT NULL::bigint,
  p_placed_quantity integer                            DEFAULT NULL::integer,
  p_stock_picks     jsonb                              DEFAULT NULL::jsonb,
  p_notes           text                               DEFAULT NULL::text
)
  RETURNS public.preorder_demand
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_row public.preorder_demand;
  v_line_tenant_id bigint;
  v_doc_status text;
  v_open_qty integer;
  v_delivered integer;
  v_placed integer;
  v_placements jsonb;
  v_vendor_code text;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;
  IF p_source_id IS NULL THEN
    RAISE EXCEPTION 'source_id is required';
  END IF;

  SELECT g.tenant_id, g.open_qty, g.document_status
  INTO v_line_tenant_id, v_open_qty, v_doc_status
  FROM public.get_procurement_demand_open_qty(p_source_type, p_source_id) g;

  IF v_line_tenant_id IS NULL THEN
    RAISE EXCEPTION 'demand line not found';
  END IF;

  IF NOT public.can_access_preorder_demand_tenant(p_tenant_id)
    AND NOT public.can_access_preorder_demand_tenant(v_line_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  IF v_line_tenant_id <> p_tenant_id THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.tenants t
      WHERE t.id = v_line_tenant_id
        AND t.parent_id = p_tenant_id
        AND public.user_can_manage_parent_tenant(p_tenant_id)
    ) THEN
      RAISE EXCEPTION 'tenant mismatch for demand line';
    END IF;
  END IF;

  IF v_doc_status NOT IN ('procuring', 'packed') THEN
    RAISE EXCEPTION 'document is not open for preorder demand updates';
  END IF;

  IF p_placed_quantity IS NOT NULL AND v_doc_status <> 'procuring' THEN
    RAISE EXCEPTION 'placed_quantity can only be updated while procuring';
  END IF;

  IF p_stock_picks IS NOT NULL AND v_doc_status NOT IN ('procuring', 'packed') THEN
    RAISE EXCEPTION 'stock_picks can only be updated while procuring or packed';
  END IF;

  IF p_placed_quantity IS NOT NULL AND coalesce(p_placed_quantity, 0) < 0 THEN
    RAISE EXCEPTION 'placed_quantity cannot be negative';
  END IF;

  IF p_stock_picks IS NOT NULL AND NOT public.validate_preorder_stock_picks(p_stock_picks) THEN
    RAISE EXCEPTION 'invalid stock_picks payload';
  END IF;

  v_delivered := CASE
    WHEN p_stock_picks IS NOT NULL THEN public.sum_preorder_stock_picks(p_stock_picks)
    ELSE NULL
  END;

  SELECT pd.* INTO v_row
  FROM public.preorder_demand pd
  WHERE pd.source_type = p_source_type
    AND pd.source_id = p_source_id;

  IF p_placed_quantity IS NOT NULL THEN
    SELECT nullif(trim(v.code), '') INTO v_vendor_code
    FROM public.vendors v
    WHERE v.id = coalesce(p_vendor_id, v_row.vendor_id);
    v_vendor_code := coalesce(v_vendor_code, 'unknown');
    v_placements := jsonb_build_array(
      jsonb_build_object('vendor_code', v_vendor_code, 'quantity', p_placed_quantity)
    );
    IF NOT public.validate_preorder_vendor_placements(v_placements) THEN
      RAISE EXCEPTION 'invalid vendor_placements payload';
    END IF;
  ELSE
    v_placements := NULL;
  END IF;

  IF found THEN
    v_placed := coalesce(
      CASE WHEN v_placements IS NOT NULL THEN public.sum_preorder_vendor_placements(v_placements) END,
      public.sum_preorder_vendor_placements(v_row.vendor_placements),
      v_row.placed_quantity,
      0
    );
  ELSE
    v_placed := coalesce(public.sum_preorder_vendor_placements(v_placements), 0);
  END IF;

  IF v_delivered IS NOT NULL AND v_delivered > coalesce(v_open_qty, 0) THEN
    RAISE EXCEPTION 'delivered_quantity cannot exceed need quantity';
  END IF;

  INSERT INTO public.preorder_demand (
    tenant_id,
    parent_tenant_id,
    source_type,
    source_id,
    vendor_id,
    placed_quantity,
    delivered_quantity,
    vendor_placements,
    stock_picks,
    notes,
    updated_by_user_id
  ) VALUES (
    v_line_tenant_id,
    public.resolve_parent_tenant_id(v_line_tenant_id),
    p_source_type,
    p_source_id,
    coalesce(p_vendor_id, CASE WHEN found THEN v_row.vendor_id ELSE NULL END),
    v_placed,
    coalesce(v_delivered, CASE WHEN found THEN v_row.delivered_quantity ELSE 0 END, 0),
    coalesce(v_placements, CASE WHEN found THEN v_row.vendor_placements ELSE '[]'::jsonb END, '[]'::jsonb),
    coalesce(p_stock_picks, CASE WHEN found THEN v_row.stock_picks ELSE '[]'::jsonb END, '[]'::jsonb),
    coalesce(nullif(trim(p_notes), ''), CASE WHEN found THEN v_row.notes ELSE NULL END),
    auth.uid()
  )
  ON CONFLICT (source_type, source_id) DO UPDATE SET
    parent_tenant_id = coalesce(public.preorder_demand.parent_tenant_id, excluded.parent_tenant_id),
    vendor_id = CASE WHEN p_vendor_id IS NOT NULL THEN p_vendor_id ELSE preorder_demand.vendor_id END,
    placed_quantity = v_placed,
    vendor_placements = CASE
      WHEN v_placements IS NOT NULL THEN v_placements
      ELSE preorder_demand.vendor_placements
    END,
    delivered_quantity = CASE
      WHEN v_delivered IS NOT NULL THEN v_delivered
      ELSE preorder_demand.delivered_quantity
    END,
    open_quantity = greatest(
      coalesce(preorder_demand.confirmed_quantity, 0)
        - CASE WHEN v_delivered IS NOT NULL THEN v_delivered ELSE preorder_demand.delivered_quantity END,
      0
    ),
    stock_picks = CASE WHEN p_stock_picks IS NOT NULL THEN p_stock_picks ELSE preorder_demand.stock_picks END,
    notes = CASE WHEN p_notes IS NOT NULL THEN nullif(trim(p_notes), '') ELSE preorder_demand.notes END,
    updated_by_user_id = auth.uid(),
    updated_at = now()
  RETURNING * INTO v_row;

  IF p_stock_picks IS NOT NULL OR jsonb_array_length(coalesce(v_row.stock_picks, '[]'::jsonb)) > 0 THEN
    PERFORM public.sync_delivery_paper_lines_for_demand(v_row.id);
  END IF;

  RETURN v_row;
END;
$function$;

GRANT ALL ON FUNCTION public.upsert_preorder_demand(bigint, public.preorder_demand_source_type, bigint, bigint, integer, jsonb, text, jsonb) TO anon;

GRANT ALL ON FUNCTION public.upsert_preorder_demand(bigint, public.preorder_demand_source_type, bigint, bigint, integer, jsonb, text, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_preorder_demand(bigint, public.preorder_demand_source_type, bigint, bigint, integer, jsonb, text, jsonb) TO service_role;

GRANT ALL ON FUNCTION public.upsert_preorder_demand(bigint, public.preorder_demand_source_type, bigint, bigint, integer, jsonb, text) TO anon;

GRANT ALL ON FUNCTION public.upsert_preorder_demand(bigint, public.preorder_demand_source_type, bigint, bigint, integer, jsonb, text) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_preorder_demand(bigint, public.preorder_demand_source_type, bigint, bigint, integer, jsonb, text) TO service_role;