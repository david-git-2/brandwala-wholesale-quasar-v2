-- Fix management list settlement save: write money_kernel bills/lines (public.bill_lines is a view).

CREATE OR REPLACE FUNCTION public._sync_dropship_courier_ar_bill_details(
  p_bill_id bigint,
  p_order_id bigint,
  p_allow_line_sync boolean DEFAULT true
) RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO money_kernel, public, pg_temp
AS $$
DECLARE
  v_bill money_kernel.bills;
  v_order public.shop_orders;
  v_courier public.courier_services;
  v_collected_settlement numeric(12, 2);
  v_cod_face numeric(12, 2);
  v_rate numeric(12, 2);
  v_delivery numeric(12, 2);
  v_discount numeric(12, 2);
  v_net numeric(12, 2);
  v_note text;
  v_meta jsonb;
  v_line_no int := 0;
BEGIN
  SELECT * INTO v_bill FROM money_kernel.bills WHERE id = p_bill_id;
  IF v_bill.id IS NULL THEN
    RETURN;
  END IF;

  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF v_order.id IS NULL THEN
    RETURN;
  END IF;

  SELECT dos.collected_cod_amount
  INTO v_collected_settlement
  FROM public.dropship_order_settlements dos
  WHERE dos.shop_order_id = p_order_id;

  SELECT * INTO v_courier FROM public.courier_services WHERE id = v_order.courier_service_id;

  PERFORM public.recompute_dropship_cod_collect_amount(p_order_id);
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;

  v_cod_face := round(
    greatest(coalesce(v_collected_settlement, v_order.cod_collect_amount, 0), 0),
    2
  );
  v_rate := round(coalesce(v_order.cod_charge_amount, 0), 2);
  v_delivery := round(coalesce(v_order.delivery_charge_amount, 0), 2);
  v_discount := round(v_rate + v_delivery, 2);
  v_net := greatest(v_cod_face - v_discount, 0);

  v_note := format(
    'Courier receivable — %s — order %s%s',
    coalesce(v_courier.name, 'Courier'),
    v_order.order_no,
    CASE
      WHEN nullif(trim(coalesce(v_order.courier_awb_number, '')), '') IS NOT NULL
      THEN format(' (AWB %s)', trim(v_order.courier_awb_number))
      ELSE ''
    END
  );

  v_meta := coalesce(v_bill.meta, '{}'::jsonb) || jsonb_build_object(
    'shop_order_id', p_order_id,
    'order_no', v_order.order_no,
    'courier_service_id', v_order.courier_service_id,
    'courier_name', v_courier.name,
    'courier_awb_number', v_order.courier_awb_number,
    'tracking_url', v_order.tracking_url,
    'cod_collect_amount', v_cod_face,
    'cod_charge_amount', v_rate,
    'delivery_charge_amount', v_delivery,
    'courier_ar_net', v_net,
    'discount_amount', v_discount,
    'subtotal_amount', v_cod_face,
    'dropship_courier_ar', true,
    'recipient_name', v_order.recipient_name,
    'recipient_phone', v_order.recipient_phone,
    'recipient_address', v_order.shipping_address
  );

  UPDATE money_kernel.bills
  SET
    note = v_note,
    total_amount = v_net,
    due_amount = greatest(v_net - coalesce(paid_amount, 0), 0),
    meta = v_meta,
    updated_at = now()
  WHERE id = p_bill_id;

  IF NOT p_allow_line_sync THEN
    RETURN;
  END IF;

  DELETE FROM money_kernel.bill_lines
  WHERE bill_id = p_bill_id
    AND tenant_id = v_bill.tenant_id
    AND item_kind = 'charge';

  IF v_cod_face > 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO money_kernel.bill_lines (
      tenant_id, bill_id, line_no, item_kind, description,
      quantity, unit_price, line_total, meta
    ) VALUES (
      v_bill.tenant_id, p_bill_id, v_line_no, 'charge', 'COD collect',
      1, v_cod_face, v_cod_face, jsonb_build_object('courier_ar_line', 'cod')
    );
  END IF;

  IF v_rate > 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO money_kernel.bill_lines (
      tenant_id, bill_id, line_no, item_kind, description,
      quantity, unit_price, line_total, meta
    ) VALUES (
      v_bill.tenant_id, p_bill_id, v_line_no, 'charge', 'COD rate (deduction)',
      1, v_rate, v_rate, jsonb_build_object('courier_ar_line', 'rate')
    );
  END IF;

  IF v_delivery > 0 THEN
    v_line_no := v_line_no + 1;
    INSERT INTO money_kernel.bill_lines (
      tenant_id, bill_id, line_no, item_kind, description,
      quantity, unit_price, line_total, meta
    ) VALUES (
      v_bill.tenant_id, p_bill_id, v_line_no, 'charge', 'Delivery (deduction)',
      1, v_delivery, v_delivery, jsonb_build_object('courier_ar_line', 'delivery')
    );
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_dropship_draft_bills_after_settlement(p_order_id bigint)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO money_kernel, public, pg_temp
AS $$
DECLARE
  v_order public.shop_orders;
  v_settlement public.dropship_order_settlements;
  v_customer money_kernel.bills;
  v_courier money_kernel.bills;
  v_courier_bill_id bigint;
  v_sync jsonb;
  v_cod_face numeric(12, 2);
  v_rate numeric(12, 2);
  v_delivery numeric(12, 2);
  v_courier_net numeric(12, 2);
  v_payout_note text;
  v_customer_total numeric(12, 2);
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'order not found';
  END IF;

  SELECT * INTO v_settlement
  FROM public.dropship_order_settlements
  WHERE shop_order_id = p_order_id;

  IF v_order.global_invoice_id IS NOT NULL THEN
    SELECT * INTO v_customer
    FROM money_kernel.bills
    WHERE id = v_order.global_invoice_id
    FOR UPDATE;

    IF v_customer.id IS NOT NULL AND v_customer.status IS DISTINCT FROM 'draft' THEN
      RAISE EXCEPTION 'customer bill is not draft; use pay-in or bill adjustments instead';
    END IF;
  END IF;

  v_courier_bill_id := public.resolve_dropship_courier_ap_bill_id(p_order_id, v_order.tenant_id);
  IF v_courier_bill_id IS NOT NULL THEN
    SELECT * INTO v_courier
    FROM money_kernel.bills
    WHERE id = v_courier_bill_id
    FOR UPDATE;

    IF v_courier.id IS NOT NULL AND v_courier.status IS DISTINCT FROM 'draft' THEN
      RAISE EXCEPTION 'courier bill is not draft; use pay-in or bill adjustments instead';
    END IF;
  END IF;

  IF v_order.global_invoice_id IS NOT NULL AND v_customer.id IS NOT NULL THEN
    v_sync := public.sync_dropship_tenant_b2b_invoice_from_order(p_order_id);
    IF coalesce(v_sync->>'success', 'false') <> 'true' THEN
      RAISE EXCEPTION '%', coalesce(v_sync->>'error', 'failed to sync customer bill');
    END IF;

    SELECT kb.total_amount
    INTO v_customer_total
    FROM money_kernel.bills kb
    WHERE kb.id = v_order.global_invoice_id;

    v_cod_face := round(
      greatest(coalesce(v_settlement.collected_cod_amount, v_order.cod_collect_amount, 0), 0),
      2
    );
    v_rate := round(coalesce(v_order.cod_charge_amount, 0), 2);
    v_delivery := round(coalesce(v_order.delivery_charge_amount, 0), 2);
    v_courier_net := greatest(v_cod_face - v_rate - v_delivery, 0);

    v_payout_note := format(
      'Expected amount after all payment: %s BDT (informative; payout posts on remittance)',
      greatest(v_courier_net - coalesce(v_customer_total, 0), 0)
    );

    PERFORM public._kernel_patch_bill_header(v_order.global_invoice_id, v_payout_note);
    PERFORM public.stamp_bill_kernel_fields(v_order.global_invoice_id);
  END IF;

  IF v_courier_bill_id IS NOT NULL THEN
    PERFORM public._sync_dropship_courier_ar_bill_details(v_courier_bill_id, p_order_id, true);
    PERFORM public.stamp_bill_kernel_fields(v_courier_bill_id);
  END IF;

  RETURN jsonb_build_object('success', true, 'order_id', p_order_id);
END;
$$;