-- Redeploy catalog bill RPCs: shop_orders.tenant_id-only check (parent_tenant_id column retired).

CREATE OR REPLACE FUNCTION public.get_shop_order_bill_item_coverage_for_staff(
  p_tenant_id bigint,
  p_order_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.shop_orders%rowtype;
  v_bills_count int;
  v_items jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_order_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'tenant_id and order_id required');
  END IF;

  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  SELECT * INTO v_order FROM public.shop_orders o WHERE o.id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order not found');
  END IF;

  IF v_order.tenant_id IS DISTINCT FROM p_tenant_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'tenant mismatch');
  END IF;

  IF v_order.shop_type_snapshot IS DISTINCT FROM 'vendor_catalog'::public.shop_type_enum THEN
    RETURN jsonb_build_object('success', false, 'error', 'catalog coverage is for vendor_catalog orders only');
  END IF;

  SELECT count(*)::int INTO v_bills_count
  FROM public.bills b
  WHERE b.invoice_status IS DISTINCT FROM 'voided'::public.global_invoice_status
    AND (
      b.shop_order_id = p_order_id
      OR (b.source_type = 'shop_order' AND b.source_id = p_order_id::text)
    );

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'order_item_id', soi.id,
        'target_quantity', public._shop_order_item_target_qty(soi.id),
        'billed_quantity', public._shop_order_item_billed_qty(soi.id),
        'remaining_quantity', greatest(
          public._shop_order_item_target_qty(soi.id) - public._shop_order_item_billed_qty(soi.id),
          0
        ),
        'picked_quantity', coalesce((
          SELECT sum(sp.quantity) FROM public.shop_order_item_stock_picks sp WHERE sp.order_item_id = soi.id
        ), 0)
      )
      ORDER BY soi.id
    ),
    '[]'::jsonb
  )
  INTO v_items
  FROM public.shop_order_items soi
  WHERE soi.order_id = p_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'bills_count', v_bills_count,
    'items', v_items
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_catalog_shop_order_wholesale_draft_bill(
  p_tenant_id bigint,
  p_order_id bigint,
  p_settlement_kind public.bill_settlement_kind DEFAULT 'take'::public.bill_settlement_kind
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.shop_orders%rowtype;
  v_built jsonb;
  v_payload jsonb;
  v_result jsonb;
  v_invoice_id bigint;
  v_bill public.bills%rowtype;
BEGIN
  IF p_tenant_id IS NULL OR p_order_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'tenant_id and order_id required');
  END IF;

  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order not found');
  END IF;

  IF v_order.tenant_id IS DISTINCT FROM p_tenant_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'tenant mismatch');
  END IF;

  v_built := public.build_catalog_shop_order_wholesale_draft_payload(p_order_id, p_settlement_kind);
  IF coalesce(v_built->>'success', 'false') <> 'true' THEN
    RETURN v_built;
  END IF;

  v_payload := v_built->'payload';
  v_result := public.create_sales_invoice_from_payload(p_tenant_id, v_payload);

  IF coalesce(v_result->>'success', 'false') <> 'true' THEN
    RETURN coalesce(
      v_result,
      jsonb_build_object('success', false, 'error', 'failed to create draft bill')
    );
  END IF;

  v_invoice_id := nullif(v_result->>'invoice_id', '')::bigint;
  IF v_invoice_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'invoice_id missing');
  END IF;

  UPDATE public.bills
  SET
    source_type = 'shop_order',
    source_id = p_order_id::text,
    shop_order_id = p_order_id,
    updated_at = now()
  WHERE id = v_invoice_id;

  SELECT * INTO v_bill FROM public.bills WHERE id = v_invoice_id;

  RETURN jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice_id,
    'invoice_no', v_bill.invoice_no,
    'invoice_status', v_bill.invoice_status,
    'settlement_kind', v_bill.settlement_kind,
    'order_id', p_order_id
  );
END;
$$;