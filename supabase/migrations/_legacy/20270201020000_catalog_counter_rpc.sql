-- Migration: Phase P3 — Catalog Counter RPC
-- Scope: vendor_catalog only. Guard against non-catalog/dropship execution & non-negotiable orders.
-- Transitions status to 'countered'

CREATE OR REPLACE FUNCTION public.customer_counter_offer(
  p_order_id bigint,
  p_items jsonb -- Array: { id: bigint, customer_offer_amount: numeric, customer_offer_currency_id: bigint }
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order record;
  v_item record;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  
  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'order not found';
  END IF;

  IF v_order.shop_type_snapshot = 'vendor_catalog' THEN
    IF NOT COALESCE(v_order.is_negotiable_snapshot, false) THEN
      RAISE EXCEPTION 'Order % is not negotiable', p_order_id;
    END IF;

    IF v_order.status <> 'priced' THEN
      RAISE EXCEPTION 'Catalog order % cannot be countered from status %', p_order_id, v_order.status;
    END IF;

    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(id bigint, customer_offer_amount numeric, customer_offer_currency_id bigint) LOOP
      UPDATE public.shop_order_items
      SET
        customer_offer_amount = v_item.customer_offer_amount,
        customer_offer_currency_id = v_item.customer_offer_currency_id,
        customer_counter_at = now(),
        updated_at = now()
      WHERE id = v_item.id AND order_id = p_order_id;
    END LOOP;

    UPDATE public.shop_orders
    SET
      status = 'countered'::public.shop_order_status,
      negotiate_round = negotiate_round + 1,
      updated_at = now()
    WHERE id = p_order_id;
  ELSE
    -- Legacy / non-catalog fallback behavior
    IF NOT public.is_cart_owner(v_order.customer_group_id, v_order.tenant_id) THEN
      RAISE EXCEPTION 'access denied';
    END IF;

    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(id bigint, customer_offer_amount numeric, customer_offer_currency_id bigint) LOOP
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

GRANT EXECUTE ON FUNCTION public.customer_counter_offer(bigint, jsonb) TO authenticated;
NOTIFY pgrst, 'reload schema';
