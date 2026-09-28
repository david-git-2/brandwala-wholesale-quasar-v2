-- RT6: include remitted orders (payment_received) in COD ops report
CREATE OR REPLACE FUNCTION public.get_tenant_courier_cod_report(
  p_tenant_id bigint,
  p_start_date date DEFAULT NULL,
  p_end_date date DEFAULT NULL,
  p_courier_service_id uuid DEFAULT NULL,
  p_page integer DEFAULT 1,
  p_page_size integer DEFAULT 50,
  p_skip_count boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_books_id bigint;
  v_totals jsonb;
  v_rows jsonb;
  v_orders jsonb := NULL;
  v_total_count bigint;
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_offset integer := (greatest(coalesce(p_page, 1), 1) - 1) * greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_start_ts timestamptz := CASE WHEN p_start_date IS NULL THEN NULL ELSE p_start_date::timestamptz END;
  v_end_ts timestamptz := CASE WHEN p_end_date IS NULL THEN NULL ELSE (p_end_date + interval '1 day' - interval '1 microsecond') END;
BEGIN
  IF p_tenant_id IS NULL THEN RAISE EXCEPTION 'Tenant ID is required'; END IF;
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN RAISE EXCEPTION 'Not authorized'; END IF;

  WITH delivered_orders AS (
    SELECT
      so.id AS order_id,
      so.order_no,
      coalesce(so.courier_awb_number, so.courier_tracking_number) AS awb,
      coalesce(so.cod_collect_amount, 0)::numeric(12,2) AS cod_collect_amount,
      so.courier_remittance_ref AS remittance_ref,
      so.delivered_at,
      so.courier_service_id,
      coalesce(cs.name, so.courier_name, 'Unassigned') AS courier_name,
      round(coalesce((
        SELECT l.amount
        FROM public.universal_wallet_ledger l
        WHERE l.parent_tenant_id = v_books_id
          AND l.entity_type = 'tenant'
          AND l.source_type = 'shop_order'
          AND l.source_id = so.id::text
          AND coalesce(l.metadata->>'purpose', '') = 'tenant_remittance_received'
        LIMIT 1
      ), 0), 2) AS remitted_amount
    FROM public.shop_orders so
    LEFT JOIN public.courier_services cs ON cs.id = so.courier_service_id
    WHERE public.resolve_parent_tenant_id(so.tenant_id) = v_books_id
      AND so.status IN ('delivered'::public.shop_order_status, 'payment_received'::public.shop_order_status)
      AND so.shop_type_snapshot = 'dropship'::public.shop_type_enum
      AND coalesce(so.cod_collect_amount, 0) > 0
      AND (v_start_ts IS NULL OR so.delivered_at >= v_start_ts)
      AND (v_end_ts IS NULL OR so.delivered_at <= v_end_ts)
      AND (p_courier_service_id IS NULL OR so.courier_service_id = p_courier_service_id)
  ),
  order_amounts AS (
    SELECT *,
      remitted_amount AS remitted,
      round(greatest(cod_collect_amount - remitted_amount, 0), 2) AS unremitted,
      round(remitted_amount - cod_collect_amount, 2) AS short_over
    FROM delivered_orders
  ),
  courier_rows AS (
    SELECT
      courier_service_id,
      courier_name,
      round(coalesce(sum(cod_collect_amount), 0), 2) AS delivered_cod,
      round(coalesce(sum(remitted), 0), 2) AS remitted,
      round(coalesce(sum(unremitted), 0), 2) AS unremitted,
      round(coalesce(sum(short_over), 0), 2) AS short_over,
      count(*)::bigint AS order_count
    FROM order_amounts
    GROUP BY courier_service_id, courier_name
  ),
  totals_calc AS (
    SELECT round(coalesce(sum(delivered_cod), 0), 2) AS delivered_cod,
      round(coalesce(sum(remitted), 0), 2) AS remitted,
      round(coalesce(sum(unremitted), 0), 2) AS unremitted,
      round(coalesce(sum(short_over), 0), 2) AS short_over,
      coalesce(sum(order_count), 0)::bigint AS order_count
    FROM courier_rows
  ),
  paged AS (
    SELECT * FROM courier_rows ORDER BY delivered_cod DESC, courier_name ASC OFFSET v_offset LIMIT v_page_size
  )
  SELECT (SELECT count(*) FROM courier_rows),
    (SELECT jsonb_build_object('delivered_cod', delivered_cod, 'remitted', remitted, 'unremitted', unremitted,
      'short_over', short_over, 'order_count', order_count) FROM totals_calc),
    coalesce((SELECT jsonb_agg(jsonb_build_object(
      'courier_service_id', courier_service_id, 'courier_name', courier_name,
      'delivered_cod', delivered_cod, 'remitted', remitted, 'unremitted', unremitted,
      'short_over', short_over, 'order_count', order_count
    ) ORDER BY delivered_cod DESC, courier_name ASC) FROM paged), '[]'::jsonb)
  INTO v_total_count, v_totals, v_rows;

  IF p_courier_service_id IS NOT NULL THEN
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      'order_id', order_id, 'order_no', order_no, 'awb', awb,
      'cod_collect_amount', cod_collect_amount, 'remittance_ref', remittance_ref, 'delivered_at', delivered_at,
      'remitted', remitted
    ) ORDER BY delivered_at DESC NULLS LAST, order_id DESC), '[]'::jsonb)
    INTO v_orders
    FROM order_amounts;
  END IF;

  RETURN jsonb_build_object('totals', coalesce(v_totals, '{}'::jsonb), 'rows', coalesce(v_rows, '[]'::jsonb),
    'orders', v_orders, 'page', v_page, 'page_size', v_page_size,
    'total_count', CASE WHEN coalesce(p_skip_count, true) THEN NULL ELSE v_total_count END);
END;
$$;
