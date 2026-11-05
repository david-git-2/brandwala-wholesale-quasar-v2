CREATE FUNCTION public._guard_global_shipment_costs_locked()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
BEGIN
  IF tg_op = 'UPDATE' THEN
    IF NEW.costs_locked IS DISTINCT FROM OLD.costs_locked
       AND current_setting('app.allow_costs_lock', true) IS DISTINCT FROM '1' THEN
      RAISE EXCEPTION 'use lock_global_shipment_costs to lock shipment costs';
    END IF;

    IF OLD.costs_locked THEN
      IF NEW.received_weight IS DISTINCT FROM OLD.received_weight
         OR NEW.total_weight_kg IS DISTINCT FROM OLD.total_weight_kg THEN
        RAISE EXCEPTION 'shipment costs are locked';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$function$;

GRANT ALL ON FUNCTION public._guard_global_shipment_costs_locked() TO anon;

GRANT ALL ON FUNCTION public._guard_global_shipment_costs_locked() TO authenticated;

GRANT ALL ON FUNCTION public._guard_global_shipment_costs_locked() TO service_role;