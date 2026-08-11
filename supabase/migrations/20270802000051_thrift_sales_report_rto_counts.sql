-- Surfacing RTO on thrift sales report summary (already in refunds; add explicit RTO counts).

BEGIN;

CREATE OR REPLACE FUNCTION public.get_thrift_sales_report(
  p_tenant_id BIGINT,
  p_date_from TIMESTAMPTZ,
  p_date_to TIMESTAMPTZ,
  p_sale_channel TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_channel TEXT;
  v_summary JSONB;
  v_by_channel JSONB;
  v_cod_outstanding JSONB;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_reports', 'view') THEN
    RAISE EXCEPTION 'Thrift sales report requires thrift_reports view permission';
  END IF;

  IF p_date_from IS NULL OR p_date_to IS NULL THEN
    RAISE EXCEPTION 'p_date_from and p_date_to are required';
  END IF;

  IF p_date_from > p_date_to THEN
    RAISE EXCEPTION 'p_date_from must be <= p_date_to';
  END IF;

  v_channel := NULLIF(trim(COALESCE(p_sale_channel, '')), '');
  IF v_channel IS NOT NULL AND v_channel NOT IN ('IN_STORE', 'ONLINE') THEN
    RAISE EXCEPTION 'Invalid sale_channel: % (expected IN_STORE, ONLINE, or null)', v_channel;
  END IF;

  WITH active_inv AS (
    SELECT
      inv.id,
      COALESCE(inv.sale_channel, 'IN_STORE') AS sale_channel,
      inv.total_invoice_amount,
      CASE
        WHEN inv.courier_paid_by = 'SHOP' THEN COALESCE(inv.courier_amount, 0)
        ELSE 0
      END AS shop_courier_fee
    FROM public.thrift_sales_invoices inv
    WHERE inv.tenant_id = p_tenant_id
      AND COALESCE(inv.status, 'ACTIVE') = 'ACTIVE'
      AND inv.date >= p_date_from
      AND inv.date <= p_date_to
      AND (v_channel IS NULL OR COALESCE(inv.sale_channel, 'IN_STORE') = v_channel)
  ),
  active_lines AS (
    SELECT
      a.sale_channel,
      a.id AS invoice_id,
      a.total_invoice_amount,
      a.shop_courier_fee,
      COALESCE(SUM(i.quantity), 0) AS units,
      COALESCE(
        SUM(
          ROUND(COALESCE(public.compute_thrift_landed_unit_cost(i.stock_id), 0.00), 2)
          * i.quantity
        ),
        0
      ) AS cogs,
      COALESCE(
        SUM(
          (
            i.final_price
            - ROUND(COALESCE(public.compute_thrift_landed_unit_cost(i.stock_id), 0.00), 2)
          ) * i.quantity
        ),
        0
      ) AS line_profit
    FROM active_inv a
    LEFT JOIN public.thrift_sales_invoice_items i
      ON i.invoice_id = a.id
     AND i.tenant_id = p_tenant_id
    GROUP BY a.id, a.sale_channel, a.total_invoice_amount, a.shop_courier_fee
  ),
  active_agg AS (
    SELECT
      COUNT(*)::BIGINT AS invoice_count,
      COALESCE(SUM(units), 0)::BIGINT AS units_sold,
      COALESCE(SUM(total_invoice_amount), 0)::NUMERIC(14,2) AS net_revenue,
      COALESCE(SUM(cogs), 0)::NUMERIC(14,2) AS cogs,
      COALESCE(SUM(line_profit), 0)::NUMERIC(14,2) AS line_profit,
      COALESCE(SUM(shop_courier_fee), 0)::NUMERIC(14,2) AS total_fees,
      COALESCE(SUM(line_profit - shop_courier_fee), 0)::NUMERIC(14,2) AS net_after_fees
    FROM active_lines
  ),
  returned_agg AS (
    SELECT
      COUNT(*)::BIGINT AS refund_count,
      COALESCE(SUM(inv.total_invoice_amount), 0)::NUMERIC(14,2) AS refund_amount,
      COUNT(*) FILTER (
        WHERE COALESCE(inv.close_reason, inv.revert_reason, '') = 'RTO'
      )::BIGINT AS rto_count,
      COALESCE(
        SUM(inv.total_invoice_amount) FILTER (
          WHERE COALESCE(inv.close_reason, inv.revert_reason, '') = 'RTO'
        ),
        0
      )::NUMERIC(14,2) AS rto_amount
    FROM public.thrift_sales_invoices inv
    WHERE inv.tenant_id = p_tenant_id
      AND inv.status = 'RETURNED'
      AND inv.reverted_at IS NOT NULL
      AND inv.reverted_at >= p_date_from
      AND inv.reverted_at <= p_date_to
      AND (v_channel IS NULL OR COALESCE(inv.sale_channel, 'IN_STORE') = v_channel)
  ),
  channel_rows AS (
    SELECT
      al.sale_channel,
      COUNT(*)::BIGINT AS invoice_count,
      COALESCE(SUM(al.units), 0)::BIGINT AS units_sold,
      COALESCE(SUM(al.total_invoice_amount), 0)::NUMERIC(14,2) AS net_revenue,
      COALESCE(SUM(al.cogs), 0)::NUMERIC(14,2) AS cogs,
      COALESCE(SUM(al.line_profit), 0)::NUMERIC(14,2) AS line_profit,
      COALESCE(SUM(al.shop_courier_fee), 0)::NUMERIC(14,2) AS total_fees,
      COALESCE(SUM(al.line_profit - al.shop_courier_fee), 0)::NUMERIC(14,2) AS net_after_fees
    FROM active_lines al
    GROUP BY al.sale_channel
  )
  SELECT
    jsonb_build_object(
      'invoice_count', a.invoice_count,
      'units_sold', a.units_sold,
      'net_revenue', a.net_revenue,
      'cogs', a.cogs,
      'line_profit', a.line_profit,
      -- BC keys: courier_cod_amount = shop courier fee; other_expense always 0
      'courier_cod_amount', a.total_fees,
      'other_expense_amount', 0::NUMERIC(14,2),
      'total_fees', a.total_fees,
      'net_after_fees', a.net_after_fees,
      'refund_count', r.refund_count,
      'refund_amount', r.refund_amount,
      'rto_count', r.rto_count,
      'rto_amount', r.rto_amount
    ),
    COALESCE(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'sale_channel', c.sale_channel,
            'invoice_count', c.invoice_count,
            'units_sold', c.units_sold,
            'net_revenue', c.net_revenue,
            'cogs', c.cogs,
            'line_profit', c.line_profit,
            'courier_cod_amount', c.total_fees,
            'other_expense_amount', 0::NUMERIC(14,2),
            'total_fees', c.total_fees,
            'net_after_fees', c.net_after_fees
          )
          ORDER BY c.sale_channel
        )
        FROM channel_rows c
      ),
      '[]'::jsonb
    )
  INTO v_summary, v_by_channel
  FROM active_agg a
  CROSS JOIN returned_agg r;

  -- COD outstanding: snapshot of ALL open COD (not date-filtered).
  SELECT jsonb_build_object(
    'invoice_count', COUNT(*)::BIGINT,
    'cod_expected_total', COALESCE(SUM(COALESCE(inv.cod_expected, 0)), 0)::NUMERIC(14,2),
    'cod_remitted_total', COALESCE(SUM(COALESCE(inv.cod_remitted_amount, 0)), 0)::NUMERIC(14,2)
  )
  INTO v_cod_outstanding
  FROM public.thrift_sales_invoices inv
  WHERE inv.tenant_id = p_tenant_id
    AND COALESCE(inv.status, 'ACTIVE') = 'ACTIVE'
    AND inv.payment_status = 'COD_PENDING';

  RETURN jsonb_build_object(
    'date_from', p_date_from,
    'date_to', p_date_to,
    'sale_channel', v_channel,
    'summary', COALESCE(v_summary, '{}'::jsonb),
    'by_channel', COALESCE(v_by_channel, '[]'::jsonb),
    'cod_outstanding', COALESCE(v_cod_outstanding, jsonb_build_object(
      'invoice_count', 0,
      'cod_expected_total', 0,
      'cod_remitted_total', 0
    ))
  );
END;
$$;

COMMENT ON FUNCTION public.get_thrift_sales_report(BIGINT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) IS
  'Period ACTIVE sales totals + RETURNED refunds (includes RTO via reverted_at). Summary also exposes rto_count/rto_amount.';

COMMIT;
