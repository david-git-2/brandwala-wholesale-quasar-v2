-- Management list: save delivered-row settlement + resync draft AR bills.

CREATE OR REPLACE FUNCTION public._sync_dropship_courier_ar_bill_details(
  p_bill_id bigint,
  p_order_id bigint,
  p_allow_line_sync boolean DEFAULT true
) RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO public
AS $$
DECLARE
  v_bill public.bills;
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
BEGIN
  SELECT * INTO v_bill FROM public.bills WHERE id = p_bill_id;
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

  v_meta := coalesce(v_bill.channel_meta, '{}'::jsonb) || jsonb_build_object(
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
    'dropship_courier_ar', true
  );

  UPDATE public.bills
  SET
    note = v_note,
    subtotal_amount = v_cod_face,
    discount_amount = v_discount,
    total_amount = v_net,
    due_amount = greatest(v_net - coalesce(paid_amount, 0), 0),
    recipient_name = v_order.recipient_name,
    recipient_phone = v_order.recipient_phone,
    recipient_address = v_order.shipping_address,
    channel_meta = v_meta,
    updated_at = now()
  WHERE id = p_bill_id;

  IF NOT p_allow_line_sync THEN
    RETURN;
  END IF;

  DELETE FROM public.bill_lines
  WHERE invoice_id = p_bill_id
    AND line_kind IN ('charge', 'description');

  IF v_cod_face > 0 THEN
    INSERT INTO public.bill_lines (
      invoice_id, tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) VALUES (
      p_bill_id, v_bill.tenant_id, 'charge', 'COD collect', 1,
      v_cod_face, 0, v_cod_face, v_cod_face,
      coalesce(v_bill.currency_code, 'BDT'), jsonb_build_object('courier_ar_line', 'cod')
    );
  END IF;

  IF v_rate > 0 THEN
    INSERT INTO public.bill_lines (
      invoice_id, tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) VALUES (
      p_bill_id, v_bill.tenant_id, 'charge', 'COD rate (deduction)', 1,
      v_rate, 0, v_rate, v_rate,
      coalesce(v_bill.currency_code, 'BDT'), jsonb_build_object('courier_ar_line', 'rate')
    );
  END IF;

  IF v_delivery > 0 THEN
    INSERT INTO public.bill_lines (
      invoice_id, tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) VALUES (
      p_bill_id, v_bill.tenant_id, 'charge', 'Delivery (deduction)', 1,
      v_delivery, 0, v_delivery, v_delivery,
      coalesce(v_bill.currency_code, 'BDT'), jsonb_build_object('courier_ar_line', 'delivery')
    );
  END IF;

  PERFORM public.recompute_global_invoice_totals(p_bill_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_dropship_draft_bills_after_settlement(p_order_id bigint)
RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO public
AS $$
DECLARE
  v_order public.shop_orders;
  v_settlement public.dropship_order_settlements;
  v_customer public.bills;
  v_courier public.bills;
  v_courier_bill_id bigint;
  v_sync jsonb;
  v_cod_face numeric(12, 2);
  v_rate numeric(12, 2);
  v_delivery numeric(12, 2);
  v_courier_net numeric(12, 2);
  v_payout_note text;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF v_order.id IS NULL THEN
    RAISE EXCEPTION 'order not found';
  END IF;

  SELECT * INTO v_settlement
  FROM public.dropship_order_settlements
  WHERE shop_order_id = p_order_id;

  IF v_order.global_invoice_id IS NOT NULL THEN
    SELECT * INTO v_customer FROM public.bills WHERE id = v_order.global_invoice_id FOR UPDATE;
    IF v_customer.id IS NOT NULL
       AND v_customer.invoice_status IS DISTINCT FROM 'draft'::public.global_invoice_status THEN
      RAISE EXCEPTION 'customer bill is not draft; use pay-in or bill adjustments instead';
    END IF;
  END IF;

  v_courier_bill_id := public.resolve_dropship_courier_ap_bill_id(p_order_id, v_order.tenant_id);
  IF v_courier_bill_id IS NOT NULL THEN
    SELECT * INTO v_courier FROM public.bills WHERE id = v_courier_bill_id FOR UPDATE;
    IF v_courier.id IS NOT NULL
       AND v_courier.invoice_status IS DISTINCT FROM 'draft'::public.global_invoice_status THEN
      RAISE EXCEPTION 'courier bill is not draft; use pay-in or bill adjustments instead';
    END IF;
  END IF;

  IF v_order.global_invoice_id IS NOT NULL AND v_customer.id IS NOT NULL THEN
    v_sync := public.sync_dropship_tenant_b2b_invoice_from_order(p_order_id);
    IF coalesce(v_sync->>'success', 'false') <> 'true' THEN
      RAISE EXCEPTION '%', coalesce(v_sync->>'error', 'failed to sync customer bill');
    END IF;

    SELECT * INTO v_customer FROM public.bills WHERE id = v_order.global_invoice_id;

    v_cod_face := round(
      greatest(
        coalesce(v_settlement.collected_cod_amount, v_order.cod_collect_amount, 0),
        0
      ),
      2
    );
    v_rate := round(coalesce(v_order.cod_charge_amount, 0), 2);
    v_delivery := round(coalesce(v_order.delivery_charge_amount, 0), 2);
    v_courier_net := greatest(v_cod_face - v_rate - v_delivery, 0);

    v_payout_note := format(
      'Expected amount after all payment: %s BDT (informative; payout posts on remittance)',
      greatest(v_courier_net - coalesce(v_customer.total_amount, 0), 0)
    );

    UPDATE public.bills
    SET note = v_payout_note, updated_at = now()
    WHERE id = v_customer.id
      AND invoice_status = 'draft'::public.global_invoice_status;

    PERFORM public.sync_sales_invoice_charges_from_header(v_customer.id);
  END IF;

  IF v_courier_bill_id IS NOT NULL THEN
    PERFORM public._sync_dropship_courier_ar_bill_details(v_courier_bill_id, p_order_id, true);
  END IF;

  RETURN jsonb_build_object('success', true, 'order_id', p_order_id);
END;
$$;

CREATE OR REPLACE FUNCTION public.save_dropship_management_list_settlement(
  p_tenant_id bigint,
  p_order_id bigint,
  p_payload jsonb
)
RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO public
AS $$
DECLARE
  v_order public.shop_orders;
  v_settlement public.dropship_order_settlements;
  v_settlement_id bigint;
  v_save jsonb;
  v_sync jsonb;
  v_collected numeric(15, 2);
  v_delivery numeric(15, 2);
  v_cod_rate numeric(15, 2);
  v_discount_company_pay numeric(15, 2);
  v_return_reason_note text;
  v_charge_lines jsonb;
  v_payload_settlement jsonb;
  v_customer public.bills;
  v_courier_bill_id bigint;
BEGIN
  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  SELECT * INTO v_order
  FROM public.shop_orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order not found';
  END IF;

  IF v_order.tenant_id IS DISTINCT FROM p_tenant_id THEN
    RAISE EXCEPTION 'tenant mismatch';
  END IF;

  IF v_order.shop_type_snapshot <> 'dropship' THEN
    RAISE EXCEPTION 'not a dropship order';
  END IF;

  IF v_order.status <> 'delivered'::public.shop_order_status THEN
    RAISE EXCEPTION 'settlement save on list requires delivered status (current: %)', v_order.status;
  END IF;

  v_collected := round(greatest(coalesce((p_payload->>'collected_cod_amount')::numeric, 0), 0), 2);
  v_delivery := round(greatest(coalesce((p_payload->>'delivery_charge_amount')::numeric, 0), 0), 2);
  v_cod_rate := round(greatest(coalesce((p_payload->>'cod_charge_amount')::numeric, 0), 0), 2);

  SELECT dos.id, dos.discount_company_pay, dos.return_reason_note
  INTO v_settlement_id, v_discount_company_pay, v_return_reason_note
  FROM public.dropship_order_settlements dos
  WHERE dos.shop_order_id = p_order_id;

  v_discount_company_pay := coalesce(v_discount_company_pay, 0);
  v_return_reason_note := coalesce(v_return_reason_note, '');

  v_charge_lines := public.build_dropship_management_charge_lines(v_order, v_settlement_id);

  SELECT coalesce(
    jsonb_agg(
      CASE
        WHEN elem.value->>'charge_type' = 'delivery' THEN
          jsonb_set(elem.value, '{amount}', to_jsonb(v_delivery))
        WHEN elem.value->>'charge_type' = 'cod' THEN
          jsonb_set(elem.value, '{amount}', to_jsonb(v_cod_rate))
        ELSE elem.value
      END
      ORDER BY elem.value->>'charge_type'
    ),
    '[]'::jsonb
  )
  INTO v_charge_lines
  FROM jsonb_array_elements(v_charge_lines) AS elem(value);

  v_payload_settlement := jsonb_build_object(
    'collected_cod_amount', v_collected,
    'discount_company_pay', v_discount_company_pay,
    'return_reason_note', v_return_reason_note,
    'charge_lines', v_charge_lines
  );

  v_save := public.save_dropship_settlement_draft(p_tenant_id, p_order_id, v_payload_settlement);
  IF coalesce(v_save->>'success', 'false') <> 'true' THEN
    RETURN v_save;
  END IF;

  v_sync := public.sync_dropship_draft_bills_after_settlement(p_order_id);

  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  SELECT dos.collected_cod_amount INTO v_collected
  FROM public.dropship_order_settlements dos
  WHERE dos.shop_order_id = p_order_id;

  SELECT * INTO v_customer FROM public.bills WHERE id = v_order.global_invoice_id;
  v_courier_bill_id := public.resolve_dropship_courier_ap_bill_id(p_order_id, v_order.tenant_id);

  RETURN jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'collected_cod_amount', v_collected,
    'delivery_charge_amount', v_order.delivery_charge_amount,
    'cod_charge_amount', v_order.cod_charge_amount,
    'dropshipper_bill_amount', v_customer.total_amount,
    'global_invoice_id', v_order.global_invoice_id,
    'courier_ar_bill_id', v_courier_bill_id,
    'settlement', v_save->'settlement',
    'bill_sync', v_sync
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', sqlerrm);
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_dropship_draft_bills_after_settlement(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_dropship_management_list_settlement(bigint, bigint, jsonb) TO authenticated;

DROP FUNCTION IF EXISTS public.list_dropship_shop_orders_for_staff(
  bigint,
  integer,
  integer,
  text,
  text,
  text[]
);

CREATE OR REPLACE FUNCTION public.list_dropship_shop_orders_for_staff(
  p_tenant_id bigint,
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0,
  p_status text DEFAULT NULL,
  p_search text DEFAULT NULL,
  p_statuses text[] DEFAULT NULL
)
RETURNS TABLE (
  id bigint,
  order_no text,
  status public.shop_order_status,
  created_at timestamptz,
  customer_group_name text,
  created_by_email text,
  recipient_name text,
  recipient_phone text,
  courier_name text,
  courier_awb_number text,
  cod_collect_amount numeric,
  total_amount numeric,
  global_invoice_id bigint,
  courier_remittance_ref text,
  collection_source public.collection_source_type,
  payout_settlement_status text,
  tenant_id bigint,
  tenant_name text,
  cod_charge_amount numeric,
  delivery_charge_amount numeric,
  collected_cod_amount numeric,
  dropshipper_bill_amount numeric,
  customer_invoice_no text,
  courier_ar_bill_id bigint,
  customer_invoice_status text,
  courier_ar_invoice_status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  RETURN QUERY
  SELECT
    o.id,
    o.order_no,
    o.status,
    o.created_at,
    cg.name AS customer_group_name,
    o.created_by_email,
    o.recipient_name,
    o.recipient_phone,
    coalesce(cs.name, o.courier_name) AS courier_name,
    o.courier_awb_number,
    o.cod_collect_amount,
    coalesce(
      (
        SELECT sum(
          coalesce(
            final_price_amount,
            staff_offer_amount,
            customer_offer_amount,
            unit_sell_price_amount,
            unit_list_price_amount
          ) * quantity
        )
        FROM public.shop_order_items
        WHERE order_id = o.id
      ),
      0
    )::numeric AS total_amount,
    o.global_invoice_id,
    o.courier_remittance_ref,
    o.collection_source,
    o.payout_settlement_status,
    o.tenant_id,
    coalesce(t.name, '')::text AS tenant_name,
    coalesce(o.cod_charge_amount, 0)::numeric AS cod_charge_amount,
    coalesce(o.delivery_charge_amount, 0)::numeric AS delivery_charge_amount,
    coalesce(dos.collected_cod_amount, o.cod_collect_amount)::numeric AS collected_cod_amount,
    coalesce(
      b.total_amount,
      rp.reseller_purchase_cost,
      0
    )::numeric AS dropshipper_bill_amount,
    b.invoice_no AS customer_invoice_no,
    public.resolve_dropship_courier_ap_bill_id(o.id, o.tenant_id) AS courier_ar_bill_id,
    b.invoice_status::text AS customer_invoice_status,
    (
      SELECT cab.invoice_status::text
      FROM public.bills cab
      WHERE cab.id = public.resolve_dropship_courier_ap_bill_id(o.id, o.tenant_id)
    ) AS courier_ar_invoice_status
  FROM public.shop_orders o
  JOIN public.customer_groups cg ON cg.id = o.customer_group_id
  LEFT JOIN public.courier_services cs ON cs.id::text = o.courier_service_id::text
  LEFT JOIN public.tenants t ON t.id = o.tenant_id
  LEFT JOIN public.dropship_order_settlements dos ON dos.shop_order_id = o.id
  LEFT JOIN public.bills b ON b.id = o.global_invoice_id
  LEFT JOIN LATERAL public.compute_dropship_order_reseller_purchase(o.id) rp ON true
  WHERE o.tenant_id = p_tenant_id
    AND o.shop_type_snapshot = 'dropship'
    AND (
      CASE
        WHEN p_statuses IS NOT NULL AND cardinality(p_statuses) > 0 THEN
          o.status::text = ANY (p_statuses)
        WHEN p_status IS NOT NULL THEN
          o.status::text = p_status
        ELSE
          o.status::text IN (
            'submitted',
            'confirmed',
            'placed',
            'processing',
            'ready_for_pickup',
            'shipped',
            'delivered',
            'returned',
            'payment_received',
            'reseller_paid'
          )
      END
    )
    AND (
      p_search IS NULL
      OR o.order_no ILIKE ('%' || p_search || '%')
      OR o.recipient_name ILIKE ('%' || p_search || '%')
      OR o.recipient_phone ILIKE ('%' || p_search || '%')
      OR o.courier_awb_number ILIKE ('%' || p_search || '%')
      OR o.courier_name ILIKE ('%' || p_search || '%')
      OR cs.name ILIKE ('%' || p_search || '%')
      OR cg.name ILIKE ('%' || p_search || '%')
      OR o.created_by_email ILIKE ('%' || p_search || '%')
      OR t.name ILIKE ('%' || p_search || '%')
    )
  ORDER BY o.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_dropship_shop_orders_for_staff(
  bigint,
  integer,
  integer,
  text,
  text,
  text[]
) TO authenticated;