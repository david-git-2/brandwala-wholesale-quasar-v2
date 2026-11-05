CREATE FUNCTION public.compute_thrift_landed_unit_cost (
  p_stock_id bigint
)
  RETURNS numeric
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_stock public.thrift_stocks%ROWTYPE;
  v_shipment public.thrift_shipments%ROWTYPE;
  v_settings public.thrift_settings%ROWTYPE;
  v_sum_qty numeric;
  v_u numeric;
  v_total_weight_kg numeric;
  v_line_weight_kg numeric;
  v_costing_qty numeric;
  v_product_unit_cost numeric;
  v_shipment_cargo_cost numeric;
  v_shipment_ops_cost numeric;
  v_cargo_share_per_unit numeric;
  v_ops_share_per_unit numeric;
  v_landed_unit_cost numeric;
BEGIN
  SELECT * INTO v_stock
  FROM public.thrift_stocks
  WHERE id = p_stock_id;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  SELECT * INTO v_shipment
  FROM public.thrift_shipments
  WHERE id = v_stock.shipment_id;

  SELECT * INTO v_settings
  FROM public.thrift_settings
  WHERE tenant_id = v_stock.tenant_id;

  -- Costing qty: SOLD with remaining 0 still counts as 1 unit for allocation.
  v_costing_qty := CASE
    WHEN v_stock.status = 'SOLD'::public.thrift_stock_status
         AND COALESCE(v_stock.quantity, 0) = 0 THEN 1::numeric
    ELSE GREATEST(COALESCE(v_stock.quantity, 0), 0)::numeric
  END;

  SELECT COALESCE(SUM(
    CASE
      WHEN s.status = 'SOLD'::public.thrift_stock_status
           AND COALESCE(s.quantity, 0) = 0 THEN 1::numeric
      ELSE GREATEST(COALESCE(s.quantity, 0), 0)::numeric
    END
  ), 0) INTO v_sum_qty
  FROM public.thrift_stocks s
  WHERE s.shipment_id = v_stock.shipment_id;

  v_u := GREATEST(v_sum_qty, 1.0);

  SELECT COALESCE(SUM(
    (
      (COALESCE(s.product_weight, 0.0) + COALESCE(s.extra_weight, 0.0))
      / 1000.0
    ) * CASE
      WHEN s.status = 'SOLD'::public.thrift_stock_status
           AND COALESCE(s.quantity, 0) = 0 THEN 1::numeric
      ELSE GREATEST(COALESCE(s.quantity, 0), 0)::numeric
    END
  ), 0.0) INTO v_total_weight_kg
  FROM public.thrift_stocks s
  WHERE s.shipment_id = v_stock.shipment_id;

  v_line_weight_kg :=
    (COALESCE(v_stock.product_weight, 0.0) + COALESCE(v_stock.extra_weight, 0.0))
    / 1000.0
    * v_costing_qty;

  v_product_unit_cost :=
    (COALESCE(v_stock.origin_unit_price, 0.0) + COALESCE(v_stock.extra_origin_unit_price, 0.0))
    * COALESCE(v_shipment.product_conversion_rate, 1.0);

  v_shipment_cargo_cost :=
    COALESCE(v_shipment.total_cargo_weight_kg, 0.0)
    * COALESCE(v_shipment.cargo_rate, 0.0)
    * COALESCE(v_shipment.cargo_conversion_rate, 0.0);

  v_shipment_ops_cost :=
    (COALESCE(v_settings.hand_tag_unit_cost, 0.0) * v_u)
    + (COALESCE(v_settings.sticker_unit_cost, 0.0) * v_u)
    + COALESCE(v_shipment.labor_total_cost, 0.0)
    + COALESCE(v_shipment.transportation_total_cost, 0.0)
    + COALESCE(v_shipment.washing_total_cost, 0.0);

  IF v_total_weight_kg > 0 AND v_costing_qty > 0 THEN
    v_cargo_share_per_unit :=
      ((v_line_weight_kg / v_total_weight_kg) * v_shipment_cargo_cost)
      / v_costing_qty;
  ELSE
    v_cargo_share_per_unit := v_shipment_cargo_cost / v_u;
  END IF;

  v_ops_share_per_unit := v_shipment_ops_cost / v_u;

  v_landed_unit_cost :=
    v_product_unit_cost
    + v_cargo_share_per_unit
    + v_ops_share_per_unit
    + COALESCE(v_stock.additional_charges_cost, 0.0);

  RETURN COALESCE(v_landed_unit_cost, 0.0);
END;
$function$;

GRANT ALL ON FUNCTION public.compute_thrift_landed_unit_cost(bigint) TO anon;

GRANT ALL ON FUNCTION public.compute_thrift_landed_unit_cost(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.compute_thrift_landed_unit_cost(bigint) TO service_role;