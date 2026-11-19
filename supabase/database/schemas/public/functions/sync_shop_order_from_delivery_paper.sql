-- When a vendor-catalog delivery paper moves to dispatched / delivered, align the source shop order status.

CREATE OR REPLACE FUNCTION public.sync_shop_order_from_delivery_paper (
  p_delivery_paper_id bigint,
  p_paper_status      public.delivery_paper_status
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_order public.shop_orders%rowtype;
  v_procurement text;
BEGIN
  IF p_delivery_paper_id IS NULL OR p_paper_status IS NULL THEN
    RETURN;
  END IF;

  IF p_paper_status NOT IN (
    'dispatched'::public.delivery_paper_status,
    'delivered'::public.delivery_paper_status
  ) THEN
    RETURN;
  END IF;

  SELECT * INTO v_paper
  FROM public.delivery_paper dp
  WHERE dp.id = p_delivery_paper_id;

  IF NOT FOUND
    OR v_paper.source_type <> 'shop_order'::public.delivery_paper_source_type THEN
    RETURN;
  END IF;

  SELECT * INTO v_order
  FROM public.shop_orders o
  WHERE o.id = v_paper.source_id;

  IF NOT FOUND OR v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RETURN;
  END IF;

  IF v_order.status IN (
    'cancelled'::public.shop_order_status,
    'closed'::public.shop_order_status
  ) THEN
    RETURN;
  END IF;

  IF p_paper_status = 'dispatched'::public.delivery_paper_status THEN
    v_procurement := public.normalize_shop_order_procurement_status(v_order.status);
    IF v_procurement <> 'procuring' AND v_order.status <> 'dispatch'::public.shop_order_status THEN
      RETURN;
    END IF;
    IF v_order.status = 'dispatch'::public.shop_order_status THEN
      RETURN;
    END IF;

    UPDATE public.shop_orders
    SET
      status = 'dispatch'::public.shop_order_status,
      placed_at = coalesce(placed_at, now()),
      updated_at = now()
    WHERE id = v_order.id;

    PERFORM public.notify_catalog_shop_order(
      p_order_id := v_order.id,
      p_notify_staff := false,
      p_notify_customer := true,
      p_event_type := 'catalog.order.dispatch',
      p_title := format('%s is dispatching', v_order.order_no),
      p_body := 'We will update you when it is delivered.'
    );
    RETURN;
  END IF;

  IF p_paper_status = 'delivered'::public.delivery_paper_status THEN
    IF v_order.status = 'delivered'::public.shop_order_status THEN
      RETURN;
    END IF;

    UPDATE public.shop_orders
    SET
      status = 'delivered'::public.shop_order_status,
      fulfilled_at = coalesce(fulfilled_at, now()),
      updated_at = now()
    WHERE id = v_order.id;

    PERFORM public.notify_catalog_shop_order(
      p_order_id := v_order.id,
      p_notify_staff := false,
      p_notify_customer := true,
      p_event_type := 'catalog.order.delivered',
      p_title := format('Order %s delivered', v_order.order_no),
      p_body := 'Open the order for details.'
    );
  END IF;
END;
$function$;

GRANT ALL ON FUNCTION public.sync_shop_order_from_delivery_paper(bigint, public.delivery_paper_status) TO anon;

GRANT ALL ON FUNCTION public.sync_shop_order_from_delivery_paper(bigint, public.delivery_paper_status) TO authenticated;

GRANT ALL ON FUNCTION public.sync_shop_order_from_delivery_paper(bigint, public.delivery_paper_status) TO service_role;