-- Phase 30: Period sales report RPC

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
      COALESCE(inv.courier_cod_amount, 0) AS courier_cod_amount,
      COALESCE(inv.other_expense_amount, 0) AS other_expense_amount
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
      a.courier_cod_amount,
      a.other_expense_amount,
      COALESCE(SUM(i.quantity), 0) AS units,
      COALESCE(SUM(i.landed_unit_cost_at_sale * i.quantity), 0) AS cogs,
      COALESCE(SUM(i.net_profit), 0) AS line_profit
    FROM active_inv a
    LEFT JOIN public.thrift_sales_invoice_items i
      ON i.invoice_id = a.id
     AND i.tenant_id = p_tenant_id
    GROUP BY a.id, a.sale_channel, a.total_invoice_amount, a.courier_cod_amount, a.other_expense_amount
  ),
  active_agg AS (
    SELECT
      COUNT(*)::BIGINT AS invoice_count,
      COALESCE(SUM(units), 0)::BIGINT AS units_sold,
      COALESCE(SUM(total_invoice_amount), 0)::NUMERIC(14,2) AS net_revenue,
      COALESCE(SUM(cogs), 0)::NUMERIC(14,2) AS cogs,
      COALESCE(SUM(line_profit), 0)::NUMERIC(14,2) AS line_profit,
      COALESCE(SUM(courier_cod_amount), 0)::NUMERIC(14,2) AS courier_cod_amount,
      COALESCE(SUM(other_expense_amount), 0)::NUMERIC(14,2) AS other_expense_amount,
      COALESCE(SUM(courier_cod_amount + other_expense_amount), 0)::NUMERIC(14,2) AS total_fees,
      COALESCE(SUM(line_profit - courier_cod_amount - other_expense_amount), 0)::NUMERIC(14,2) AS net_after_fees
    FROM active_lines
  ),
  returned_agg AS (
    SELECT
      COUNT(*)::BIGINT AS refund_count,
      COALESCE(SUM(inv.total_invoice_amount), 0)::NUMERIC(14,2) AS refund_amount
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
      COALESCE(SUM(al.courier_cod_amount), 0)::NUMERIC(14,2) AS courier_cod_amount,
      COALESCE(SUM(al.other_expense_amount), 0)::NUMERIC(14,2) AS other_expense_amount,
      COALESCE(SUM(al.courier_cod_amount + al.other_expense_amount), 0)::NUMERIC(14,2) AS total_fees,
      COALESCE(SUM(al.line_profit - al.courier_cod_amount - al.other_expense_amount), 0)::NUMERIC(14,2) AS net_after_fees
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
      'courier_cod_amount', a.courier_cod_amount,
      'other_expense_amount', a.other_expense_amount,
      'total_fees', a.total_fees,
      'net_after_fees', a.net_after_fees,
      'refund_count', r.refund_count,
      'refund_amount', r.refund_amount
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
            'courier_cod_amount', c.courier_cod_amount,
            'other_expense_amount', c.other_expense_amount,
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

  RETURN jsonb_build_object(
    'date_from', p_date_from,
    'date_to', p_date_to,
    'sale_channel', v_channel,
    'summary', COALESCE(v_summary, '{}'::jsonb),
    'by_channel', COALESCE(v_by_channel, '[]'::jsonb)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_thrift_sales_report(BIGINT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_thrift_sales_report(BIGINT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT)
  TO service_role;

COMMIT;
