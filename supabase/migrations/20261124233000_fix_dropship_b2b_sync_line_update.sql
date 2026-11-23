-- Remove invalid updated_at on money_kernel.bill_lines (column does not exist).

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