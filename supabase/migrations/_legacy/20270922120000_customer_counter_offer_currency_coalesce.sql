CREATE OR REPLACE FUNCTION "public"."customer_counter_offer"("p_order_id" bigint, "p_items" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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
      UPDATE public.shop_order_items soi
      SET
        customer_offer_amount = v_item.customer_offer_amount,
        customer_offer_currency_id = coalesce(
          nullif(v_item.customer_offer_currency_id, 0),
          soi.staff_offer_currency_id,
          soi.unit_sell_price_currency_id,
          soi.unit_list_price_currency_id,
          soi.customer_offer_currency_id
        ),
        customer_counter_at = now(),
        updated_at = now()
      WHERE soi.id = v_item.id AND soi.order_id = p_order_id;
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

      PERFORM public.notify_catalog_shop_order(
        p_order_id := p_order_id,
        p_notify_staff := true,
        p_notify_customer := false,
        p_event_type := 'catalog.offer.countered',
        p_title := format('%s needs a final price', v_order.order_no),
        p_body := 'Open the order and send the last offer.'
      );
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

      PERFORM public.notify_catalog_shop_order(
        p_order_id := p_order_id,
        p_notify_staff := true,
        p_notify_customer := false,
        p_event_type := 'catalog.order.confirmed',
        p_title := format('Order %s confirmed', v_order.order_no),
        p_body := 'Start buying when ready.'
      );
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
      UPDATE public.shop_order_items soi
      SET
        customer_offer_amount = v_item.customer_offer_amount,
        customer_offer_currency_id = coalesce(
          nullif(v_item.customer_offer_currency_id, 0),
          soi.staff_offer_currency_id,
          soi.unit_sell_price_currency_id,
          soi.unit_list_price_currency_id,
          soi.customer_offer_currency_id
        ),
        updated_at = now()
      WHERE soi.id = v_item.id AND soi.order_id = p_order_id;
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
