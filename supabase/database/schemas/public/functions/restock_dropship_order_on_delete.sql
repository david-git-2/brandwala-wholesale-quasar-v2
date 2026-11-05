CREATE FUNCTION public.restock_dropship_order_on_delete()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_is_dropship boolean := false;
BEGIN
  IF OLD.shop_type_snapshot = 'dropship' THEN
    v_is_dropship := true;
  ELSE
    SELECT (shop_type = 'dropship') INTO v_is_dropship
    FROM public.shops
    WHERE id = OLD.shop_id;
  END IF;

  IF NOT coalesce(v_is_dropship, false) THEN
    RETURN OLD;
  END IF;

  PERFORM public.release_dropship_order_stock(
    OLD.id,
    OLD.status IS DISTINCT FROM 'cancelled'
  );

  RETURN OLD;
END;
$function$;

GRANT ALL ON FUNCTION public.restock_dropship_order_on_delete() TO anon;

GRANT ALL ON FUNCTION public.restock_dropship_order_on_delete() TO authenticated;

GRANT ALL ON FUNCTION public.restock_dropship_order_on_delete() TO service_role;