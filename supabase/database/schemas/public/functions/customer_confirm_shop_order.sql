CREATE FUNCTION public.customer_confirm_shop_order (
  p_order_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
DECLARE
  v_order record;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'customer_confirm_shop_order is only valid for vendor_catalog orders.';
  END IF;

  IF v_order.status <> 'final_offered' AND v_order.status <> 'priced' THEN
    RAISE EXCEPTION 'Order % cannot be confirmed from status %', p_order_id, v_order.status;
  END IF;

  -- Set confirmed_quantity = quantity where confirmed_quantity is null
  UPDATE public.shop_order_items
  SET
    confirmed_quantity = COALESCE(confirmed_quantity, quantity),
    updated_at = now()
  WHERE order_id = p_order_id;

  -- Update order status to confirmed
  UPDATE public.shop_orders
  SET
    status = 'confirmed'::public.shop_order_status,
    updated_at = now()
  WHERE id = p_order_id;

  PERFORM public.notify_catalog_shop_order(
    p_order_id := p_order_id,
    p_notify_staff := true,
    p_notify_customer := false,
    p_event_type := 'catalog.order.confirmed',
    p_title := format('Order %s confirmed', v_order.order_no),
    p_body := 'Start buying when ready.'
  );
END;
$function$;

GRANT ALL ON FUNCTION public.customer_confirm_shop_order(bigint) TO anon;

GRANT ALL ON FUNCTION public.customer_confirm_shop_order(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.customer_confirm_shop_order(bigint) TO service_role;