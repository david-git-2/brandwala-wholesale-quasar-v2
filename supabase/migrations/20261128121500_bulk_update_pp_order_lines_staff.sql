-- bulk_update_pp_order_lines_staff: one RPC for staff multi-line field / qty patches.

CREATE OR REPLACE FUNCTION public.bulk_update_pp_order_lines_staff(
    p_tenant_id bigint,
    p_line_ids bigint[],
    p_patch jsonb
) RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO public
AS $$
DECLARE
  v_line_id bigint;
  v_line public.pp_order_lines%ROWTYPE;
  v_placement text;
  v_supplier bigint;
  v_shipment bigint;
  v_placed numeric;
  v_received numeric;
  v_cart boolean;
  v_updated integer := 0;
  v_supplier_id_text text;
BEGIN
  IF NOT public.has_active_tenant_membership(p_tenant_id) THEN
    RAISE EXCEPTION 'Not allowed for tenant %', p_tenant_id USING ERRCODE = '42501';
  END IF;

  IF p_line_ids IS NULL OR cardinality(p_line_ids) = 0 THEN
    RETURN jsonb_build_object('updated_count', 0);
  END IF;

  IF p_patch IS NULL OR p_patch = '{}'::jsonb THEN
    RAISE EXCEPTION 'Bulk patch is required' USING ERRCODE = '22023';
  END IF;

  IF p_patch ? 'placement_status' THEN
    v_placement := lower(trim(coalesce(p_patch->>'placement_status', '')));
    IF v_placement = '' OR v_placement NOT IN (
      'none', 'draft', 'requested', 'processing', 'cancelled',
      'added_to_cart', 'order_placed', 'cargo_warehouse',
      'in_flight', 'local_warehouse', 'delivered', 'lost'
    ) THEN
      RAISE EXCEPTION 'Invalid placement status: %', p_patch->>'placement_status' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF p_patch ? 'pp_supplier_group_id' THEN
  IF jsonb_typeof(p_patch->'pp_supplier_group_id') = 'null' THEN
    NULL;
  ELSE
    v_supplier_id_text := nullif(trim(p_patch->>'pp_supplier_group_id'), '');
    v_supplier := v_supplier_id_text::bigint;
    PERFORM 1
    FROM public.pp_people_group g
    WHERE g.id = v_supplier
      AND g.tenant_id = p_tenant_id
      AND g.type = 'supplier'
      AND g.deleted_at IS NULL;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Invalid supplier group' USING ERRCODE = '22023';
    END IF;
  END IF;
  END IF;

  IF p_patch ? 'shipment_id' THEN
    IF jsonb_typeof(p_patch->'shipment_id') = 'null' THEN
      NULL;
    ELSE
      v_shipment := nullif(trim(p_patch->>'shipment_id'), '')::bigint;
      PERFORM 1
      FROM public.pp_shipment sh
      WHERE sh.id = v_shipment
        AND sh.tenant_id = p_tenant_id
        AND sh.deleted_at IS NULL;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid shipment' USING ERRCODE = '22023';
      END IF;
    END IF;
  END IF;

  FOREACH v_line_id IN ARRAY p_line_ids
  LOOP
    SELECT * INTO v_line
    FROM public.pp_order_lines l
    WHERE l.id = v_line_id
      AND l.tenant_id = p_tenant_id
      AND l.deleted_at IS NULL;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Order line % not found', v_line_id USING ERRCODE = 'P0002';
    END IF;

    v_placement := CASE
      WHEN p_patch ? 'placement_status' THEN lower(trim(p_patch->>'placement_status'))
      ELSE ''
    END;

    v_supplier := CASE
      WHEN NOT (p_patch ? 'pp_supplier_group_id') THEN v_line.pp_supplier_group_id
      WHEN jsonb_typeof(p_patch->'pp_supplier_group_id') = 'null' THEN NULL::bigint
      ELSE nullif(trim(p_patch->>'pp_supplier_group_id'), '')::bigint
    END;

    v_shipment := CASE
      WHEN NOT (p_patch ? 'shipment_id') THEN v_line.shipment_id
      WHEN jsonb_typeof(p_patch->'shipment_id') = 'null' THEN NULL::bigint
      ELSE nullif(trim(p_patch->>'shipment_id'), '')::bigint
    END;

    v_placed := v_line.placed_qty;
    IF coalesce((p_patch->>'set_placed_qty_from_needed')::boolean, false) THEN
      v_placed := v_line.needed_qty;
    END IF;

    v_received := v_line.received_qty;
    IF coalesce((p_patch->>'set_received_qty_from_placed')::boolean, false) THEN
      v_received := coalesce(v_placed, v_line.placed_qty, v_line.needed_qty);
    END IF;

    v_cart := CASE
      WHEN p_patch ? 'placement_status' THEN NULL::boolean
      ELSE v_line.is_added_to_cart
    END;

    PERFORM public.update_pp_order_line_staff(
      p_tenant_id,
      v_line_id,
      v_line.url,
      v_line.needed_qty,
      v_line.tracking_url,
      v_line.description,
      v_line.product_name,
      v_line.image_url,
      v_line.unit_price,
      v_supplier,
      v_shipment,
      v_cart,
      v_placement,
      v_placed,
      v_received
    );

    v_updated := v_updated + 1;
  END LOOP;

  RETURN jsonb_build_object('updated_count', v_updated);
END;
$$;

GRANT ALL ON FUNCTION public.bulk_update_pp_order_lines_staff(bigint, bigint[], jsonb)
    TO anon, authenticated, service_role;