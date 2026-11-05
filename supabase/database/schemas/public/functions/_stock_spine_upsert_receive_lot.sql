CREATE FUNCTION public._stock_spine_upsert_receive_lot (
  p_parent_tenant_id bigint,
  p_shipment_item_id bigint,
  p_outcome_id       bigint,
  p_stock_type_id    bigint,
  p_delta            integer,
  p_location_id      bigint,
  p_availability     public.stock_availability,
  p_grade_tag_id     bigint
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_stock_id bigint;
BEGIN
  IF p_delta IS NULL OR p_delta <= 0 THEN
    RAISE EXCEPTION 'receive lot delta must be > 0';
  END IF;

  INSERT INTO public.global_stocks (
    parent_tenant_id,
    shipment_item_id,
    outcome_id,
    stock_type_id,
    quantity,
    is_usable,
    availability,
    location_id,
    grade_tag_id
  ) VALUES (
    p_parent_tenant_id,
    p_shipment_item_id,
    p_outcome_id,
    p_stock_type_id,
    p_delta,
    true,
    p_availability,
    p_location_id,
    p_grade_tag_id
  )
  ON CONFLICT (outcome_id, availability, location_id, grade_tag_id)
  DO UPDATE SET
    quantity = public.global_stocks.quantity + excluded.quantity,
    updated_at = now()
  RETURNING id INTO v_stock_id;

  RETURN v_stock_id;
END;
$function$;

GRANT ALL ON FUNCTION public._stock_spine_upsert_receive_lot(bigint, bigint, bigint, bigint, integer, bigint, public.stock_availability, bigint) TO anon;

GRANT ALL ON FUNCTION public._stock_spine_upsert_receive_lot(bigint, bigint, bigint, bigint, integer, bigint, public.stock_availability, bigint) TO authenticated;

GRANT ALL ON FUNCTION public._stock_spine_upsert_receive_lot(bigint, bigint, bigint, bigint, integer, bigint, public.stock_availability, bigint) TO service_role;