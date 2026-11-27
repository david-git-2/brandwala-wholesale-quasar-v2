-- Management list settlement save: kernel bill_lines + kernel customer B2B sync (public.bill_lines is read-only).

CREATE OR REPLACE FUNCTION public.sync_dropship_tenant_b2b_invoice_from_order(p_order_id bigint)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO money_kernel, public, pg_temp
AS $$
DECLARE
  v_order public.shop_orders;
  v_invoice public.bills;
  v_pick record;
  v_item_sell_price numeric(12, 2);
  v_item_line_total numeric(12, 2);
  v_charges record;
  v_subtotal numeric(12, 2) := 0;
  v_charges_sum numeric(12, 2) := 0;
  v_discount numeric(12, 2) := 0;
  v_paid numeric(12, 2) := 0;
  v_total numeric(12, 2) := 0;
  v_meta_patch jsonb;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order not found');
  END IF;

  IF v_order.shop_type_snapshot <> 'dropship' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Order is not a dropship order');
  END IF;

  IF v_order.global_invoice_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'No tenant B2B invoice linked to order');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM money_kernel.bills kb WHERE kb.id = v_order.global_invoice_id FOR UPDATE
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Linked invoice not found');
  END IF;

  SELECT * INTO v_invoice FROM public.bills WHERE id = v_order.global_invoice_id;

  IF v_invoice.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Linked invoice not found');
  END IF;

  IF v_invoice.invoice_type <> 'dropship'::public.global_invoice_type THEN
    RETURN jsonb_build_object('success', false, 'error', 'Linked invoice is not a dropship B2B invoice');
  END IF;

  IF v_invoice.invoice_status = 'voided'::public.global_invoice_status THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot sync a voided invoice');
  END IF;

  IF v_invoice.payment_status IN ('paid', 'partially_paid') THEN
    RAISE EXCEPTION
      'Cannot sync dropship B2B invoice after payment (invoice %). Use scripts/sql/backfill_dropship_invoice_charge_payer_mismatch.sql',
      v_invoice.id;
  END IF;

  SELECT * INTO v_charges FROM public.get_dropship_merchant_billable_charges(p_order_id);

  FOR v_pick IN (
    SELECT
      sp.quantity AS pick_quantity,
      sp.held_stock_id,
      soi.unit_sell_price_amount,
      soi.final_price_amount
    FROM public.shop_order_item_stock_picks sp
    JOIN public.shop_order_items soi ON soi.id = sp.order_item_id
    WHERE sp.order_id = v_order.id
      AND sp.quantity > 0
      AND coalesce(soi.is_fulfillment_unavailable, false) = false
  ) LOOP
    v_item_sell_price := coalesce(v_pick.unit_sell_price_amount, v_pick.final_price_amount, 0);
    v_item_line_total := v_pick.pick_quantity * v_item_sell_price;

    UPDATE money_kernel.bill_lines bl
    SET
      quantity = v_pick.pick_quantity,
      unit_price = v_item_sell_price,
      line_total = v_item_line_total
    WHERE bl.bill_id = v_invoice.id
      AND bl.global_stock_id = v_pick.held_stock_id
      AND bl.item_kind = 'stock';
  END LOOP;

  v_discount := coalesce(v_order.discount_amount, 0);
  v_meta_patch := jsonb_build_object(
    'shipping_charge', coalesce(v_charges.delivery, 0),
    'print_charge', coalesce(v_charges.print, 0),
    'wrapping_charge', coalesce(v_charges.packing, 0),
    'cod_charge_amount', coalesce(v_charges.cod, 0),
    'discount_amount', v_discount,
    'collection_source', 'billing_profile'
  );

  PERFORM public._kernel_patch_bill_header(v_invoice.id, NULL, v_meta_patch, NULL);

  SELECT coalesce(sum(bl.line_total), 0)
  INTO v_subtotal
  FROM money_kernel.bill_lines bl
  WHERE bl.bill_id = v_invoice.id
    AND bl.item_kind = 'stock';

  v_charges_sum :=
    coalesce((v_meta_patch->>'shipping_charge')::numeric, 0)
    + coalesce((v_meta_patch->>'wrapping_charge')::numeric, 0)
    + coalesce((v_meta_patch->>'print_charge')::numeric, 0);

  SELECT coalesce(kb.paid_amount, 0)
  INTO v_paid
  FROM money_kernel.bills kb
  WHERE kb.id = v_invoice.id;

  v_total := greatest(v_subtotal + v_charges_sum - v_discount, 0);

  UPDATE money_kernel.bills kb
  SET
    total_amount = v_total,
    due_amount = greatest(v_total - v_paid, 0),
    meta = coalesce(kb.meta, '{}'::jsonb)
      || v_meta_patch
      || jsonb_build_object('subtotal_amount', v_subtotal),
    updated_at = now()
  WHERE kb.id = v_invoice.id;

  PERFORM public.stamp_bill_kernel_fields(v_invoice.id);
  PERFORM public.recompute_global_invoice_payment_status(v_invoice.id);

  SELECT * INTO v_invoice FROM public.bills WHERE id = v_invoice.id;

  RETURN jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_status', v_invoice.invoice_status,
    'payment_status', v_invoice.payment_status,
    'total_amount', v_invoice.total_amount,
    'due_amount', v_invoice.due_amount
  );
END;
$$;

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

GRANT EXECUTE ON FUNCTION public.sync_dropship_tenant_b2b_invoice_from_order(bigint) TO authenticated;