-- Re-stamp landed costs when line weights/prices change (inline edit, weight balance, etc.)

CREATE OR REPLACE FUNCTION public.trg_global_shipment_items_restamp_landed_cost()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_ship public.global_shipments%ROWTYPE;
BEGIN
  IF tg_op <> 'UPDATE' THEN
    RETURN NEW;
  END IF;

  IF coalesce(current_setting('app.skip_item_landed_restamp', true), '') = '1' THEN
    RETURN NEW;
  END IF;

  IF NOT (
    NEW.product_weight IS DISTINCT FROM OLD.product_weight
    OR NEW.package_weight IS DISTINCT FROM OLD.package_weight
    OR NEW.purchase_price IS DISTINCT FROM OLD.purchase_price
    OR NEW.ordered_quantity IS DISTINCT FROM OLD.ordered_quantity
  ) THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_ship FROM public.global_shipments WHERE id = NEW.shipment_id;
  IF NOT FOUND OR public.global_shipment_costs_are_locked(v_ship) THEN
    RETURN NEW;
  END IF;

  PERFORM public.stamp_global_shipment_landed_costs(NEW.shipment_id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_global_shipment_items_restamp_landed_cost ON public.global_shipment_items;
CREATE TRIGGER trg_global_shipment_items_restamp_landed_cost
  AFTER UPDATE OF product_weight, package_weight, purchase_price, ordered_quantity
  ON public.global_shipment_items
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_global_shipment_items_restamp_landed_cost();

CREATE OR REPLACE FUNCTION public.apply_global_shipment_weight_balance(
  p_shipment_id bigint,
  p_adjustments jsonb,
  p_transaction_rate numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  v_shipment public.global_shipments%ROWTYPE;
  v_adjustment_count int;
  v_valid_count int;
  v_estimated_kg numeric;
  v_actual_kg numeric;
BEGIN
  IF p_adjustments IS NULL OR jsonb_typeof(p_adjustments) <> 'array' OR jsonb_array_length(p_adjustments) = 0 THEN
    RAISE EXCEPTION 'At least one package weight adjustment is required.';
  END IF;

  SELECT *
  INTO v_shipment
  FROM public.global_shipments
  WHERE id = p_shipment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Shipment not found.';
  END IF;

  v_actual_kg := round(coalesce(v_shipment.received_weight, 0), 2);

  IF v_actual_kg <= 0 THEN
    RAISE EXCEPTION 'Cargo Invoice Weight must be saved before applying weight balance.';
  END IF;

  SELECT count(*)
  INTO v_adjustment_count
  FROM jsonb_to_recordset(p_adjustments) AS a(item_id bigint, package_weight numeric);

  SELECT count(*)
  INTO v_valid_count
  FROM jsonb_to_recordset(p_adjustments) AS a(item_id bigint, package_weight numeric)
  INNER JOIN public.global_shipment_items gsi
    ON gsi.id = a.item_id
   AND gsi.shipment_id = p_shipment_id;

  IF v_adjustment_count <> v_valid_count THEN
    RAISE EXCEPTION 'One or more adjustment rows do not belong to this shipment.';
  END IF;

  IF public.global_shipment_costs_are_locked(v_shipment) THEN
    RAISE EXCEPTION 'shipment costs are locked';
  END IF;

  PERFORM set_config('app.skip_item_landed_restamp', '1', true);

  UPDATE public.global_shipment_items gsi
  SET
    package_weight = adj.package_weight,
    updated_at = now()
  FROM jsonb_to_recordset(p_adjustments) AS adj(item_id bigint, package_weight numeric)
  WHERE gsi.id = adj.item_id
    AND gsi.shipment_id = p_shipment_id;

  UPDATE public.products p
  SET
    package_weight = adj.package_weight,
    updated_at = now()
  FROM jsonb_to_recordset(p_adjustments) AS adj(item_id bigint, package_weight numeric)
  INNER JOIN public.global_shipment_items gsi
    ON gsi.id = adj.item_id
   AND gsi.shipment_id = p_shipment_id
  WHERE p.id = gsi.product_id
    AND gsi.product_id IS NOT NULL;

  PERFORM set_config('app.skip_item_landed_restamp', '0', true);
  PERFORM public.stamp_global_shipment_landed_costs(p_shipment_id);

  UPDATE public.global_shipments
  SET updated_at = now()
  WHERE id = p_shipment_id;

  SELECT coalesce(
    sum((coalesce(gsi.product_weight, 0) + coalesce(gsi.package_weight, 0)) * gsi.ordered_quantity),
    0
  ) / 1000.0
  INTO v_estimated_kg
  FROM public.global_shipment_items gsi
  WHERE gsi.shipment_id = p_shipment_id;

  RETURN jsonb_build_object(
    'estimated_kg', v_estimated_kg,
    'actual_kg', v_actual_kg,
    'delta_kg', v_actual_kg - v_estimated_kg
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.bulk_update_global_shipment_items(p_shipment_id bigint, p_updates jsonb)
RETURNS SETOF public.global_shipment_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
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

  IF NOT public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) THEN
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
$$;
