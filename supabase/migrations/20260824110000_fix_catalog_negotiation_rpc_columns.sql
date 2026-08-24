-- Fix catalog negotiation RPCs: use real shop_order_items columns
-- (weight_kg, final_price_amount — not gross_weight_kg / final_offer_amount / cbm)
-- See doc/shop_order/CATALOG_NEGOTIATION.md §5.2.1

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
SET search_path = public
AS $$
DECLARE
  v_order record;
  v_elem jsonb;
  v_item_id bigint;
  v_offer_amount numeric;
  v_offer_currency_id bigint;
  v_weight_kg numeric;
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
    conversion_rate = COALESCE(p_fx_rate, conversion_rate),
    cargo_rate = COALESCE(p_cargo_rate, cargo_rate),
    first_offer_rate = COALESCE(p_profit_pct, first_offer_rate),
    profit_rate = COALESCE(p_profit_pct, profit_rate),
    status = 'priced'::public.shop_order_status,
    updated_at = now()
  WHERE id = p_order_id;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_item_id := (v_elem->>'id')::bigint;
    v_offer_amount := (v_elem->>'staff_offer_amount')::numeric;
    v_offer_currency_id := (v_elem->>'staff_offer_currency_id')::bigint;
    v_weight_kg := COALESCE(
      NULLIF(v_elem->>'weight_kg', '')::numeric,
      NULLIF(v_elem->>'gross_weight_kg', '')::numeric,
      NULL
    );

    UPDATE public.shop_order_items
    SET
      staff_offer_amount = v_offer_amount,
      staff_offer_currency_id = v_offer_currency_id,
      weight_kg = COALESCE(v_weight_kg, weight_kg),
      staff_offer_at = now(),
      updated_at = now()
    WHERE id = v_item_id AND order_id = p_order_id;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.staff_finalize_catalog_prices(
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

GRANT EXECUTE ON FUNCTION public.staff_price_shop_order(bigint, jsonb, text, numeric, numeric, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_finalize_catalog_prices(bigint, jsonb) TO authenticated;
