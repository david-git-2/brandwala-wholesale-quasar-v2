-- Catalog negotiation status flow (see doc/shop_order/CATALOG_NEGOTIATION.md)

-- 1. Customer response: accept-all at priced -> confirmed; any real counter -> countered
CREATE OR REPLACE FUNCTION public.customer_counter_offer(
  p_order_id bigint,
  p_items jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order record;
  v_item record;
  v_has_counter boolean := false;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;

  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'order not found';
  END IF;

  IF v_order.shop_type_snapshot = 'vendor_catalog' THEN
    IF NOT COALESCE(v_order.is_negotiable_snapshot, false) THEN
      RAISE EXCEPTION 'Order % is not negotiable', p_order_id;
    END IF;

    IF v_order.status <> 'priced'::public.shop_order_status THEN
      RAISE EXCEPTION 'Catalog order % cannot respond from status %', p_order_id, v_order.status;
    END IF;

    FOR v_item IN
      SELECT * FROM jsonb_to_recordset(p_items) AS x(
        id bigint,
        customer_offer_amount numeric,
        customer_offer_currency_id bigint
      )
    LOOP
      UPDATE public.shop_order_items
      SET
        customer_offer_amount = v_item.customer_offer_amount,
        customer_offer_currency_id = v_item.customer_offer_currency_id,
        customer_counter_at = now(),
        updated_at = now()
      WHERE id = v_item.id AND order_id = p_order_id;
    END LOOP;

    SELECT EXISTS (
      SELECT 1
      FROM public.shop_order_items soi
      WHERE soi.order_id = p_order_id
        AND soi.customer_offer_amount IS NOT NULL
        AND soi.staff_offer_amount IS NOT NULL
        AND soi.customer_offer_amount <> soi.staff_offer_amount
    )
    INTO v_has_counter;

    IF v_has_counter THEN
      UPDATE public.shop_orders
      SET
        status = 'countered'::public.shop_order_status,
        negotiate_round = negotiate_round + 1,
        updated_at = now()
      WHERE id = p_order_id;
    ELSE
      UPDATE public.shop_order_items
      SET
        confirmed_quantity = COALESCE(confirmed_quantity, quantity),
        updated_at = now()
      WHERE order_id = p_order_id;

      UPDATE public.shop_orders
      SET
        status = 'confirmed'::public.shop_order_status,
        updated_at = now()
      WHERE id = p_order_id;
    END IF;
  ELSE
    IF NOT public.is_cart_owner(v_order.customer_group_id, v_order.tenant_id) THEN
      RAISE EXCEPTION 'access denied';
    END IF;

    FOR v_item IN
      SELECT * FROM jsonb_to_recordset(p_items) AS x(
        id bigint,
        customer_offer_amount numeric,
        customer_offer_currency_id bigint
      )
    LOOP
      UPDATE public.shop_order_items
      SET
        customer_offer_amount = v_item.customer_offer_amount,
        customer_offer_currency_id = v_item.customer_offer_currency_id,
        updated_at = now()
      WHERE id = v_item.id AND order_id = p_order_id;
    END LOOP;

    UPDATE public.shop_orders
    SET
      status = 'negotiating'::public.shop_order_status,
      negotiate_round = negotiate_round + 1,
      updated_at = now()
    WHERE id = p_order_id;
  END IF;
END;
$$;

-- 2. Staff first offer: only from submitted / legacy costing_pending
CREATE OR REPLACE FUNCTION public.staff_price_shop_order(
  p_order_id bigint,
  p_items jsonb,
  p_profit_basis text DEFAULT NULL,
  p_fx_rate numeric DEFAULT NULL,
  p_cargo_rate numeric DEFAULT NULL,
  p_profit_pct numeric DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order record;
  v_elem jsonb;
  v_item_id bigint;
  v_offer_amount numeric;
  v_offer_currency_id bigint;
  v_gross_weight numeric;
  v_cbm numeric;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'staff_price_shop_order is only valid for vendor_catalog orders.';
  END IF;

  IF v_order.status NOT IN ('submitted'::public.shop_order_status, 'costing_pending'::public.shop_order_status) THEN
    RAISE EXCEPTION 'Order % cannot send first offer from status %', p_order_id, v_order.status;
  END IF;

  UPDATE public.shop_orders
  SET
    profit_basis = COALESCE(p_profit_basis, profit_basis),
    status = 'priced'::public.shop_order_status,
    updated_at = now()
  WHERE id = p_order_id;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_item_id := (v_elem->>'id')::bigint;
    v_offer_amount := (v_elem->>'staff_offer_amount')::numeric;
    v_offer_currency_id := (v_elem->>'staff_offer_currency_id')::bigint;
    v_gross_weight := CASE WHEN v_elem ? 'gross_weight_kg' THEN (v_elem->>'gross_weight_kg')::numeric ELSE NULL END;
    v_cbm := CASE WHEN v_elem ? 'cbm' THEN (v_elem->>'cbm')::numeric ELSE NULL END;

    UPDATE public.shop_order_items
    SET
      staff_offer_amount = v_offer_amount,
      staff_offer_currency_id = v_offer_currency_id,
      gross_weight_kg = COALESCE(v_gross_weight, gross_weight_kg),
      cbm = COALESCE(v_cbm, cbm),
      staff_offer_at = now(),
      updated_at = now()
    WHERE id = v_item_id AND order_id = p_order_id;
  END LOOP;
END;
$$;

-- 3. Staff final offer: only from countered
CREATE OR REPLACE FUNCTION public.staff_finalize_catalog_prices(
  p_order_id bigint,
  p_items jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order record;
  v_elem jsonb;
  v_item_id bigint;
  v_final_amount numeric;
  v_final_currency_id bigint;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'staff_finalize_catalog_prices is only valid for vendor_catalog orders.';
  END IF;

  IF v_order.status <> 'countered'::public.shop_order_status THEN
    RAISE EXCEPTION 'Order % cannot send final offer from status %', p_order_id, v_order.status;
  END IF;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_item_id := (v_elem->>'id')::bigint;
    v_final_amount := (v_elem->>'final_offer_amount')::numeric;
    v_final_currency_id := (v_elem->>'final_offer_currency_id')::bigint;

    UPDATE public.shop_order_items
    SET
      final_offer_amount = v_final_amount,
      final_offer_currency_id = v_final_currency_id,
      final_price_amount = v_final_amount,
      final_price_currency_id = v_final_currency_id,
      final_offer_at = now(),
      updated_at = now()
    WHERE id = v_item_id AND order_id = p_order_id;
  END LOOP;

  UPDATE public.shop_orders
  SET
    status = 'final_offered'::public.shop_order_status,
    updated_at = now()
  WHERE id = p_order_id;
END;
$$;

NOTIFY pgrst, 'reload schema';
