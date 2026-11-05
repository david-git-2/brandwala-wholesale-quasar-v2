CREATE FUNCTION public._stock_spine_finalize_inbound_movement (
  p_movement_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_mov public.stock_movements%rowtype;
  v_line_count integer;
BEGIN
  SELECT * INTO v_mov
  FROM public.stock_movements
  WHERE id = p_movement_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'stock movement not found';
  END IF;

  IF v_mov.is_posted THEN
    RETURN;
  END IF;

  IF v_mov.movement_type <> 'receive_putaway'::public.stock_movement_type THEN
    RAISE EXCEPTION 'inbound finalize requires receive_putaway movement';
  END IF;

  IF coalesce(v_mov.reference_type, '') <> 'global_shipment' THEN
    RAISE EXCEPTION 'inbound finalize requires global_shipment reference';
  END IF;

  SELECT count(*)::integer INTO v_line_count
  FROM public.stock_movement_lines sml
  WHERE sml.movement_id = p_movement_id;

  IF v_line_count <= 0 THEN
    RAISE EXCEPTION 'inbound movement has no lines';
  END IF;

  UPDATE public.stock_movements
  SET is_posted = true, posted_at = now(), updated_at = now()
  WHERE id = p_movement_id;
END;
$function$;

GRANT ALL ON FUNCTION public._stock_spine_finalize_inbound_movement(bigint) TO anon;

GRANT ALL ON FUNCTION public._stock_spine_finalize_inbound_movement(bigint) TO authenticated;

GRANT ALL ON FUNCTION public._stock_spine_finalize_inbound_movement(bigint) TO service_role;