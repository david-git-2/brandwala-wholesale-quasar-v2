CREATE FUNCTION public.staff_close_catalog_procurement (
  p_order_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_order record;
  v_desk_tenant_id bigint;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  v_desk_tenant_id := coalesce(v_order.parent_tenant_id, v_order.tenant_id);

  IF NOT public.is_tenant_staff(v_desk_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'staff_close_catalog_procurement is only valid for vendor_catalog orders.';
  END IF;

  IF public.normalize_shop_order_procurement_status(v_order.status) <> 'delivered' THEN
    RAISE EXCEPTION 'order must be delivered to close';
  END IF;

  UPDATE public.shop_orders
  SET status = 'closed'::public.shop_order_status, updated_at = now()
  WHERE id = p_order_id;

  RETURN public.get_shop_order_for_staff(v_desk_tenant_id, p_order_id);
END;
$function$;

GRANT ALL ON FUNCTION public.staff_close_catalog_procurement(bigint) TO anon;

GRANT ALL ON FUNCTION public.staff_close_catalog_procurement(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.staff_close_catalog_procurement(bigint) TO service_role;