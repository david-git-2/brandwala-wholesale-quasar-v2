CREATE FUNCTION public.update_shop_order_hidden_from_customer_for_staff (
  p_tenant_id            bigint,
  p_order_id             bigint,
  p_hidden_from_customer boolean
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_order public.shop_orders%rowtype;
BEGIN
  IF p_tenant_id IS NULL OR p_order_id IS NULL OR p_hidden_from_customer IS NULL THEN
    RAISE EXCEPTION 'tenant, order, and hidden_from_customer required';
  END IF;

  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;

  IF NOT FOUND OR v_order.tenant_id IS DISTINCT FROM p_tenant_id THEN
    RAISE EXCEPTION 'order not found';
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'only vendor catalog orders support customer visibility toggle';
  END IF;

  UPDATE public.shop_orders o
  SET
    hidden_from_customer = p_hidden_from_customer,
    updated_at = now()
  WHERE o.id = p_order_id;

  RETURN public.get_shop_order_for_staff(p_tenant_id, p_order_id);
END;
$function$;

GRANT ALL ON FUNCTION public.update_shop_order_hidden_from_customer_for_staff(bigint, bigint, boolean) TO anon;

GRANT ALL ON FUNCTION public.update_shop_order_hidden_from_customer_for_staff(bigint, bigint, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.update_shop_order_hidden_from_customer_for_staff(bigint, bigint, boolean) TO service_role;
