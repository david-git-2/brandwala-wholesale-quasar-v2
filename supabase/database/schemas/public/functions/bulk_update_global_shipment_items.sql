CREATE FUNCTION public.bulk_update_global_shipment_items (
  p_shipment_id bigint,
  p_updates     jsonb
)
  RETURNS SETOF public.global_shipment_items
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_update jsonb;
  v_id bigint;
  v_ship public.global_shipments%ROWTYPE;
BEGIN
  IF p_shipment_id IS NULL THEN
    RAISE EXCEPTION 'shipment_id is required';
  END IF;

  SELECT * INTO v_ship
  FROM public.global_shipments
  WHERE id = p_shipment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.user_can_manage_parent_tenant(v_ship.tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF public.global_shipment_costs_are_locked(v_ship) THEN
    RAISE EXCEPTION 'shipment costs are locked';
  END IF;

  PERFORM set_config('app.skip_item_landed_restamp', '1', true);

  FOR v_update IN SELECT * FROM jsonb_array_elements(p_updates)
  LOOP
    v_id := (v_update->>'id')::bigint;
    IF v_id IS NOT NULL THEN
      UPDATE public.global_shipment_items
      SET
        section_id = CASE
          WHEN v_update ? 'section_id' THEN nullif((v_update->>'section_id'), '')::bigint
          ELSE section_id
        END,
        vendor_id = CASE
          WHEN v_update ? 'vendor_id' THEN nullif((v_update->>'vendor_id'), '')::bigint
          ELSE vendor_id
        END,
        ordered_quantity = CASE
          WHEN v_update ? 'ordered_quantity' AND (v_update->>'ordered_quantity') IS NOT NULL THEN greatest(1, (v_update->>'ordered_quantity')::integer)
          ELSE ordered_quantity
        END,
        purchase_price = CASE
          WHEN v_update ? 'purchase_price' AND (v_update->>'purchase_price') IS NOT NULL THEN greatest(0, (v_update->>'purchase_price')::numeric)
          ELSE purchase_price
        END,
        product_weight = CASE
          WHEN v_update ? 'product_weight' AND (v_update->>'product_weight') IS NOT NULL THEN greatest(0, (v_update->>'product_weight')::numeric)
          ELSE product_weight
        END,
        package_weight = CASE
          WHEN v_update ? 'package_weight' AND (v_update->>'package_weight') IS NOT NULL THEN greatest(0, (v_update->>'package_weight')::numeric)
          ELSE package_weight
        END,
        barcode = CASE
          WHEN v_update ? 'barcode' THEN v_update->>'barcode'
          ELSE barcode
        END,
        product_code = CASE
          WHEN v_update ? 'product_code' THEN v_update->>'product_code'
          ELSE product_code
        END,
        name = CASE
          WHEN v_update ? 'name' AND (v_update->>'name') IS NOT NULL THEN v_update->>'name'
          ELSE name
        END,
        updated_at = now()
      WHERE id = v_id AND shipment_id = p_shipment_id;
    END IF;
  END LOOP;

  PERFORM set_config('app.skip_item_landed_restamp', '0', true);

  IF EXISTS (SELECT 1 FROM public.global_shipment_items WHERE shipment_id = p_shipment_id) THEN
    PERFORM public.stamp_global_shipment_landed_costs(p_shipment_id);
  END IF;

  RETURN QUERY
  SELECT *
  FROM public.global_shipment_items
  WHERE shipment_id = p_shipment_id
  ORDER BY sort_order ASC, id ASC;
END;
$function$;

GRANT ALL ON FUNCTION public.bulk_update_global_shipment_items(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.bulk_update_global_shipment_items(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.bulk_update_global_shipment_items(bigint, jsonb) TO service_role;