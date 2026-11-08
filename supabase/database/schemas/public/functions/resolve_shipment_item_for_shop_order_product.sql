CREATE OR REPLACE FUNCTION public.resolve_shipment_item_for_shop_order_product (
  p_books_tenant_id     bigint,
  p_shop_order_item_id  bigint,
  p_product_id          bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_shipment_item_id bigint;
  v_shipment_id bigint;
BEGIN
  IF p_shop_order_item_id IS NOT NULL THEN
    SELECT sp.shipment_item_id, sp.shipment_id
    INTO v_shipment_item_id, v_shipment_id
    FROM public.shop_order_item_stock_picks sp
    WHERE sp.order_item_id = p_shop_order_item_id
    ORDER BY sp.quantity DESC, sp.id DESC
    LIMIT 1;
  END IF;

  IF v_shipment_item_id IS NULL AND p_product_id IS NOT NULL AND p_books_tenant_id IS NOT NULL THEN
    SELECT gsi.id, gsi.shipment_id
    INTO v_shipment_item_id, v_shipment_id
    FROM public.global_shipment_items gsi
    INNER JOIN public.global_shipments s ON s.id = gsi.shipment_id
    WHERE gsi.product_id = p_product_id
      AND s.tenant_id = p_books_tenant_id
    ORDER BY s.received_date DESC NULLS LAST, gsi.id DESC
    LIMIT 1;
  END IF;

  IF v_shipment_item_id IS NULL THEN
    RETURN '{}'::jsonb;
  END IF;

  RETURN jsonb_build_object(
    'shipment_item_id', v_shipment_item_id,
    'shipment_id', v_shipment_id
  );
END;
$function$;

COMMENT ON FUNCTION public.resolve_shipment_item_for_shop_order_product(bigint, bigint, bigint) IS 'Resolve shipment batch line for a shop order item: stock picks first, else latest shipment item with same product on books tenant.';

GRANT ALL ON FUNCTION public.resolve_shipment_item_for_shop_order_product(bigint, bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.resolve_shipment_item_for_shop_order_product(bigint, bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.resolve_shipment_item_for_shop_order_product(bigint, bigint, bigint) TO service_role;
