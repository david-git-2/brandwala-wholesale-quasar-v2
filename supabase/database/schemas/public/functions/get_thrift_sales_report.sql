CREATE FUNCTION public.get_thrift_sales_report (
  p_tenant_id    bigint,
  p_date_from    timestamp with time zone,
  p_date_to      timestamp with time zone,
  p_sale_channel text                     DEFAULT NULL::text,
  p_outcome      text                     DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_channel TEXT;
  v_outcome TEXT;
  v_date_from DATE;
  v_date_to DATE;
  v_summary JSONB;
  v_by_channel JSONB;
  v_by_outcome JSONB;
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

  v_date_from := (p_date_from AT TIME ZONE 'UTC')::DATE;
  v_date_to := (p_date_to AT TIME ZONE 'UTC')::DATE;

  v_channel := NULLIF(trim(COALESCE(p_sale_channel, '')), '');
  IF v_channel IS NOT NULL AND v_channel NOT IN ('IN_STORE', 'ONLINE') THEN
    RAISE EXCEPTION 'Invalid sale_channel: % (expected IN_STORE, ONLINE, or null)', v_channel;
  END IF;

  v_outcome := NULLIF(upper(trim(COALESCE(p_outcome, ''))), '');
  IF v_outcome IS NOT NULL AND v_outcome NOT IN ('DELIVERED', 'RTO', 'CUSTOMER_RETURN') THEN
    RAISE EXCEPTION 'Invalid outcome: % (expected DELIVERED, RTO, CUSTOMER_RETURN, or null)', p_outcome;
  END IF;

  WITH pnl AS (
    SELECT
      p.invoice_id,
      p.outcome,
      p.quantity,
      p.sell_amount,
      p.allocated_shop_delivery,
      p.allocated_shop_cod_fee,
      p.allocated_shop_packing,
      p.allocated_return_courier,
      p.allocated_fees_total,
      p.cogs_is_loss,
      COALESCE(inv.sale_channel, 'IN_STORE') AS sale_channel,
      CASE
        WHEN p.sell_amount > 0 OR p.cogs_is_loss THEN
          ROUND(
            ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2)
            * p.quantity,
            2
          )
        ELSE 0.00
      END AS cogs
    FROM public.thrift_sales_pnl_lines p
    JOIN public.thrift_sales_invoices inv
      ON inv.id = p.invoice_id
     AND inv.tenant_id = p.tenant_id
    WHERE p.tenant_id = p_tenant_id
      AND p.event_date >= v_date_from
      AND p.event_date <= v_date_to
      AND (v_channel IS NULL OR COALESCE(inv.sale_channel, 'IN_STORE') = v_channel)
      AND (v_outcome IS NULL OR p.outcome = v_outcome)
  ),
  summary_agg AS (
    SELECT
      COUNT(DISTINCT invoice_id)::BIGINT AS invoice_count,
      COALESCE(SUM(quantity), 0)::BIGINT AS units_sold,
      COALESCE(SUM(sell_amount), 0)::NUMERIC(14,2) AS net_revenue,
      COALESCE(SUM(cogs), 0)::NUMERIC(14,2) AS cogs,
      COALESCE(SUM(allocated_shop_delivery), 0)::NUMERIC(14,2) AS allocated_shop_delivery,
      COALESCE(SUM(allocated_shop_cod_fee), 0)::NUMERIC(14,2) AS allocated_shop_cod_fee,
      COALESCE(SUM(allocated_shop_packing), 0)::NUMERIC(14,2) AS allocated_shop_packing,
      COALESCE(SUM(allocated_return_courier), 0)::NUMERIC(14,2) AS allocated_return_courier,
      COALESCE(SUM(allocated_fees_total), 0)::NUMERIC(14,2) AS allocated_fees_total,
      COALESCE(SUM(sell_amount - cogs - allocated_fees_total), 0)::NUMERIC(14,2) AS net_profit,
      COUNT(*) FILTER (WHERE outcome = 'RTO')::BIGINT AS rto_count,
      COALESCE(SUM(allocated_fees_total) FILTER (WHERE outcome = 'RTO'), 0)::NUMERIC(14,2)
        AS rto_amount,
      COUNT(*) FILTER (WHERE outcome = 'CUSTOMER_RETURN')::BIGINT AS customer_return_count,
      COALESCE(
        SUM(allocated_fees_total) FILTER (WHERE outcome = 'CUSTOMER_RETURN'),
        0
      )::NUMERIC(14,2) AS customer_return_amount,
      -- BC aliases used by existing UI
      COALESCE(SUM(sell_amount - cogs), 0)::NUMERIC(14,2) AS line_profit,
      COALESCE(SUM(allocated_fees_total), 0)::NUMERIC(14,2) AS total_fees,
      COALESCE(SUM(sell_amount - cogs - allocated_fees_total), 0)::NUMERIC(14,2)
        AS net_after_fees,
      COUNT(*) FILTER (WHERE outcome IN ('RTO', 'CUSTOMER_RETURN'))::BIGINT AS refund_count,
      COALESCE(
        SUM(allocated_fees_total) FILTER (WHERE outcome IN ('RTO', 'CUSTOMER_RETURN')),
        0
      )::NUMERIC(14,2) AS refund_amount
    FROM pnl
  ),
  channel_rows AS (
    SELECT
      sale_channel,
      COUNT(DISTINCT invoice_id)::BIGINT AS invoice_count,
      COALESCE(SUM(quantity), 0)::BIGINT AS units_sold,
      COALESCE(SUM(sell_amount), 0)::NUMERIC(14,2) AS net_revenue,
      COALESCE(SUM(cogs), 0)::NUMERIC(14,2) AS cogs,
      COALESCE(SUM(allocated_fees_total), 0)::NUMERIC(14,2) AS total_fees,
      COALESCE(SUM(sell_amount - cogs), 0)::NUMERIC(14,2) AS line_profit,
      COALESCE(SUM(sell_amount - cogs - allocated_fees_total), 0)::NUMERIC(14,2)
        AS net_after_fees,
      COUNT(*) FILTER (WHERE outcome = 'RTO')::BIGINT AS rto_count,
      COALESCE(SUM(allocated_fees_total) FILTER (WHERE outcome = 'RTO'), 0)::NUMERIC(14,2)
        AS rto_amount,
      COUNT(*) FILTER (WHERE outcome = 'CUSTOMER_RETURN')::BIGINT AS customer_return_count,
      COALESCE(
        SUM(allocated_fees_total) FILTER (WHERE outcome = 'CUSTOMER_RETURN'),
        0
      )::NUMERIC(14,2) AS customer_return_amount,
      COUNT(*) FILTER (WHERE outcome IN ('RTO', 'CUSTOMER_RETURN'))::BIGINT AS refund_count,
      COALESCE(
        SUM(allocated_fees_total) FILTER (WHERE outcome IN ('RTO', 'CUSTOMER_RETURN')),
        0
      )::NUMERIC(14,2) AS refund_amount
    FROM pnl
    GROUP BY sale_channel
  ),
  outcome_rows AS (
    SELECT
      outcome,
      COUNT(DISTINCT invoice_id)::BIGINT AS invoice_count,
      COALESCE(SUM(quantity), 0)::BIGINT AS units,
      COALESCE(SUM(sell_amount), 0)::NUMERIC(14,2) AS net_revenue,
      COALESCE(SUM(cogs), 0)::NUMERIC(14,2) AS cogs,
      COALESCE(SUM(allocated_fees_total), 0)::NUMERIC(14,2) AS allocated_fees_total,
      COALESCE(SUM(sell_amount - cogs - allocated_fees_total), 0)::NUMERIC(14,2) AS net_profit
    FROM pnl
    GROUP BY outcome
  )
  SELECT
    jsonb_build_object(
      'invoice_count', s.invoice_count,
      'units_sold', s.units_sold,
      'units', s.units_sold,
      'net_revenue', s.net_revenue,
      'cogs', s.cogs,
      'line_profit', s.line_profit,
      'allocated_shop_delivery', s.allocated_shop_delivery,
      'allocated_shop_cod_fee', s.allocated_shop_cod_fee,
      'allocated_shop_packing', s.allocated_shop_packing,
      'allocated_return_courier', s.allocated_return_courier,
      'allocated_fees_total', s.allocated_fees_total,
      'net_profit', s.net_profit,
      'courier_cod_amount', s.allocated_shop_delivery + s.allocated_shop_cod_fee,
      'other_expense_amount', s.allocated_shop_packing + s.allocated_return_courier,
      'total_fees', s.total_fees,
      'net_after_fees', s.net_after_fees,
      'refund_count', s.refund_count,
      'refund_amount', s.refund_amount,
      'rto_count', s.rto_count,
      'rto_amount', s.rto_amount,
      'customer_return_count', s.customer_return_count,
      'customer_return_amount', s.customer_return_amount
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
            'net_after_fees', c.net_after_fees,
            'refund_count', c.refund_count,
            'refund_amount', c.refund_amount,
            'rto_count', c.rto_count,
            'rto_amount', c.rto_amount,
            'customer_return_count', c.customer_return_count,
            'customer_return_amount', c.customer_return_amount
          )
          ORDER BY c.sale_channel
        )
        FROM channel_rows c
      ),
      '[]'::jsonb
    ),
    COALESCE(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'outcome', o.outcome,
            'invoice_count', o.invoice_count,
            'units', o.units,
            'net_revenue', o.net_revenue,
            'cogs', o.cogs,
            'allocated_fees_total', o.allocated_fees_total,
            'net_profit', o.net_profit
          )
          ORDER BY o.outcome
        )
        FROM outcome_rows o
      ),
      '[]'::jsonb
    )
  INTO v_summary, v_by_channel, v_by_outcome
  FROM summary_agg s;

  SELECT jsonb_build_object(
    'invoice_count', COUNT(*)::BIGINT,
    'cod_expected_total', COALESCE(SUM(COALESCE(inv.cod_expected, 0)), 0)::NUMERIC(14,2),
    'cod_remitted_total', COALESCE(SUM(COALESCE(inv.cod_remitted_amount, 0)), 0)::NUMERIC(14,2)
  )
  INTO v_cod_outstanding
  FROM public.thrift_sales_invoices inv
  WHERE inv.tenant_id = p_tenant_id
    AND COALESCE(inv.status, 'ACTIVE') IN ('ACTIVE', 'PARTIALLY_RETURNED')
    AND inv.payment_status = 'COD_PENDING';

  RETURN jsonb_build_object(
    'date_from', p_date_from,
    'date_to', p_date_to,
    'sale_channel', v_channel,
    'outcome', v_outcome,
    'summary', COALESCE(v_summary, '{}'::jsonb),
    'by_channel', COALESCE(v_by_channel, '[]'::jsonb),
    'by_outcome', COALESCE(v_by_outcome, '[]'::jsonb),
    'cod_outstanding', COALESCE(v_cod_outstanding, jsonb_build_object(
      'invoice_count', 0,
      'cod_expected_total', 0,
      'cod_remitted_total', 0
    ))
  );
END;
$function$;

COMMENT ON FUNCTION public.get_thrift_sales_report(bigint,timestamp with time zone,timestamp with time zone,text,text) IS 'Period P&L from thrift_sales_pnl_lines + live COGS (cogs_is_loss). Includes RTO and customer-return cards.';

GRANT ALL ON FUNCTION public.get_thrift_sales_report(bigint, timestamp WITH time zone, timestamp WITH time zone, text, text) TO anon;

GRANT ALL ON FUNCTION public.get_thrift_sales_report(bigint, timestamp WITH time zone, timestamp WITH time zone, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.get_thrift_sales_report(bigint, timestamp WITH time zone, timestamp WITH time zone, text, text) TO service_role;