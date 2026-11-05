CREATE FUNCTION public.trg_global_shipment_items_restamp_landed_cost()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.trg_global_shipment_items_restamp_landed_cost() TO anon;

GRANT ALL ON FUNCTION public.trg_global_shipment_items_restamp_landed_cost() TO authenticated;

GRANT ALL ON FUNCTION public.trg_global_shipment_items_restamp_landed_cost() TO service_role;