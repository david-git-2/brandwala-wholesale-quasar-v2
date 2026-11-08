CREATE FUNCTION public.delete_global_shipment_cost_entry (
  p_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_entry public.global_shipment_cost_entries%ROWTYPE;
  v_ship public.global_shipments%ROWTYPE;
BEGIN
  SELECT * INTO v_entry FROM public.global_shipment_cost_entries WHERE id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'cost entry not found';
  END IF;

  SELECT * INTO v_ship FROM public.global_shipments WHERE id = v_entry.shipment_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.user_can_manage_parent_tenant(v_ship.tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF public.global_shipment_costs_are_locked(v_ship) THEN
    RAISE EXCEPTION 'shipment costs are locked';
  END IF;

  DELETE FROM public.global_shipment_cost_entries WHERE id = p_id;

  IF EXISTS (SELECT 1 FROM public.global_shipment_items WHERE shipment_id = v_entry.shipment_id) THEN
    PERFORM public.stamp_global_shipment_landed_costs(v_entry.shipment_id);
  END IF;
END;
$function$;

GRANT ALL ON FUNCTION public.delete_global_shipment_cost_entry(bigint) TO anon;

GRANT ALL ON FUNCTION public.delete_global_shipment_cost_entry(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.delete_global_shipment_cost_entry(bigint) TO service_role;