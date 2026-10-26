-- Period sales report from thrift_sales_pnl_lines + live COGS (incl. cogs_is_loss).
-- Also fix shipment report COGS for damaged customer returns.

BEGIN;

DROP FUNCTION IF EXISTS public.get_thrift_sales_report(BIGINT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT);

CREATE OR REPLACE FUNCTION public.get_thrift_sales_report(
  p_tenant_id BIGINT,
  p_date_from TIMESTAMPTZ,
  p_date_to TIMESTAMPTZ,
  p_sale_channel TEXT DEFAULT NULL,
  p_outcome TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
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
$$;

COMMENT ON FUNCTION public.get_thrift_sales_report(BIGINT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, TEXT) IS
  'Period P&L from thrift_sales_pnl_lines + live COGS (cogs_is_loss). Includes RTO and customer-return cards.';

REVOKE ALL ON FUNCTION public.get_thrift_sales_report(BIGINT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_thrift_sales_report(BIGINT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_thrift_sales_report(BIGINT, TIMESTAMPTZ, TIMESTAMPTZ, TEXT, TEXT) TO service_role;

-- Shipment report: count damaged CUSTOMER_RETURN landed cost as COGS loss
CREATE OR REPLACE FUNCTION public.get_thrift_shipment_sales_report(
  p_tenant_id BIGINT,
  p_shipment_id BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_shipment JSONB;
  v_summary JSONB;
  v_lines JSONB;
  v_by_outcome JSONB;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_reports', 'view') THEN
    RAISE EXCEPTION 'Thrift shipment report requires thrift_reports view permission';
  END IF;

  SELECT jsonb_build_object(
    'id', s.id,
    'name', s.name,
    'created_at', s.created_at,
    'updated_at', s.updated_at
  )
  INTO v_shipment
  FROM public.thrift_shipments s
  WHERE s.id = p_shipment_id
    AND s.tenant_id = p_tenant_id;

  IF v_shipment IS NULL THEN
    RAISE EXCEPTION 'Shipment % not found for tenant %', p_shipment_id, p_tenant_id;
  END IF;

  WITH pnl AS (
    SELECT
      p.id,
      p.invoice_id,
      p.invoice_item_id,
      p.stock_id,
      p.outcome,
      p.quantity,
      p.sell_amount,
      p.allocated_shop_delivery,
      p.allocated_shop_cod_fee,
      p.allocated_shop_packing,
      p.allocated_return_courier,
      p.allocated_fees_total,
      p.cogs_is_loss,
      p.event_at,
      p.event_date,
      ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2) AS landed_unit_cost,
      CASE
        WHEN p.sell_amount > 0 OR p.cogs_is_loss THEN
          ROUND(
            ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2)
            * p.quantity,
            2
          )
        ELSE 0.00
      END AS cogs,
      ROUND(
        p.sell_amount
        - CASE
            WHEN p.sell_amount > 0 OR p.cogs_is_loss THEN
              ROUND(
                ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2)
                * p.quantity,
                2
              )
            ELSE 0.00
          END
        - p.allocated_fees_total,
        2
      ) AS net_profit,
      inv.invoice_number,
      inv.date AS invoice_date,
      i.sell_price,
      i.discount_amount,
      i.final_price,
      st.name AS stock_name,
      st.barcode
    FROM public.thrift_sales_pnl_lines p
    JOIN public.thrift_sales_invoices inv
      ON inv.id = p.invoice_id
     AND inv.tenant_id = p.tenant_id
    LEFT JOIN public.thrift_sales_invoice_items i
      ON i.id = p.invoice_item_id
     AND i.tenant_id = p.tenant_id
    LEFT JOIN public.thrift_stocks st
      ON st.id = p.stock_id
     AND st.tenant_id = p.tenant_id
    WHERE p.tenant_id = p_tenant_id
      AND p.inbound_shipment_id = p_shipment_id
  ),
  summary AS (
    SELECT
      COALESCE(SUM(quantity) FILTER (WHERE outcome = 'DELIVERED'), 0)::BIGINT AS units_sold,
      COALESCE(SUM(quantity) FILTER (WHERE outcome = 'RTO'), 0)::BIGINT AS units_rto,
      COALESCE(SUM(quantity) FILTER (WHERE outcome = 'CUSTOMER_RETURN'), 0)::BIGINT AS units_returned,
      COALESCE(SUM(sell_amount), 0)::NUMERIC(14,2) AS net_revenue,
      COALESCE(SUM(sell_amount) FILTER (WHERE outcome = 'DELIVERED'), 0)::NUMERIC(14,2)
        AS delivered_revenue,
      COALESCE(SUM(cogs), 0)::NUMERIC(14,2) AS cogs,
      COALESCE(SUM(allocated_fees_total), 0)::NUMERIC(14,2) AS allocated_fees_total,
      COALESCE(SUM(net_profit), 0)::NUMERIC(14,2) AS net_profit,
      COALESCE(SUM(net_profit) FILTER (WHERE outcome = 'DELIVERED'), 0)::NUMERIC(14,2)
        AS delivered_net,
      COALESCE(
        SUM(allocated_fees_total) FILTER (WHERE outcome = 'RTO'),
        0
      )::NUMERIC(14,2) AS rto_fee_loss,
      COALESCE(
        SUM(allocated_fees_total) FILTER (WHERE outcome = 'CUSTOMER_RETURN'),
        0
      )::NUMERIC(14,2) AS return_fee_loss,
      COUNT(*) FILTER (WHERE outcome = 'DELIVERED')::BIGINT AS delivered_line_count,
      COUNT(*) FILTER (WHERE outcome = 'RTO')::BIGINT AS rto_line_count,
      COUNT(*) FILTER (WHERE outcome = 'CUSTOMER_RETURN')::BIGINT AS return_line_count,
      COALESCE(SUM(sell_price * quantity) FILTER (WHERE outcome = 'DELIVERED'), 0)::NUMERIC(14,2)
        AS gross_sales,
      COALESCE(SUM(discount_amount * quantity) FILTER (WHERE outcome = 'DELIVERED'), 0)::NUMERIC(14,2)
        AS discounts
    FROM pnl
  )
  SELECT jsonb_build_object(
    'units_sold', s.units_sold,
    'units_rto', s.units_rto,
    'units_returned', s.units_returned,
    'gross_sales', s.gross_sales,
    'discounts', s.discounts,
    'net_revenue', s.net_revenue,
    'delivered_revenue', s.delivered_revenue,
    'cogs', s.cogs,
    'allocated_fees_total', s.allocated_fees_total,
    'net_profit', s.net_profit,
    'delivered_net', s.delivered_net,
    'rto_fee_loss', s.rto_fee_loss,
    'return_fee_loss', s.return_fee_loss,
    'delivered_line_count', s.delivered_line_count,
    'rto_line_count', s.rto_line_count,
    'return_line_count', s.return_line_count,
    'margin_pct', CASE
      WHEN s.net_revenue > 0 THEN ROUND((s.net_profit / s.net_revenue) * 100, 2)
      ELSE 0::NUMERIC(8,2)
    END
  )
  INTO v_summary
  FROM summary s;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'outcome', o.outcome,
        'line_count', o.line_count,
        'units', o.units,
        'net_revenue', o.net_revenue,
        'cogs', o.cogs,
        'allocated_fees_total', o.allocated_fees_total,
        'net_profit', o.net_profit
      )
      ORDER BY o.outcome
    ),
    '[]'::jsonb
  )
  INTO v_by_outcome
  FROM (
    SELECT
      p.outcome,
      COUNT(*)::BIGINT AS line_count,
      COALESCE(SUM(p.quantity), 0)::BIGINT AS units,
      COALESCE(SUM(p.sell_amount), 0)::NUMERIC(14,2) AS net_revenue,
      COALESCE(SUM(p.cogs), 0)::NUMERIC(14,2) AS cogs,
      COALESCE(SUM(p.allocated_fees_total), 0)::NUMERIC(14,2) AS allocated_fees_total,
      COALESCE(SUM(p.net_profit), 0)::NUMERIC(14,2) AS net_profit
    FROM (
      SELECT
        p2.outcome,
        p2.quantity,
        p2.sell_amount,
        p2.allocated_fees_total,
        CASE
          WHEN p2.sell_amount > 0 OR p2.cogs_is_loss THEN
            ROUND(
              ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p2.stock_id), 0.00), 2)
              * p2.quantity,
              2
            )
          ELSE 0.00
        END AS cogs,
        ROUND(
          p2.sell_amount
          - CASE
              WHEN p2.sell_amount > 0 OR p2.cogs_is_loss THEN
                ROUND(
                  ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p2.stock_id), 0.00), 2)
                  * p2.quantity,
                  2
                )
              ELSE 0.00
            END
          - p2.allocated_fees_total,
          2
        ) AS net_profit
      FROM public.thrift_sales_pnl_lines p2
      WHERE p2.tenant_id = p_tenant_id
        AND p2.inbound_shipment_id = p_shipment_id
    ) p
    GROUP BY p.outcome
  ) o;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', x.id,
        'invoice_id', x.invoice_id,
        'invoice_item_id', x.invoice_item_id,
        'invoice_number', x.invoice_number,
        'invoice_date', x.invoice_date,
        'event_date', x.event_date,
        'outcome', x.outcome,
        'stock_id', x.stock_id,
        'stock_name', x.stock_name,
        'barcode', x.barcode,
        'quantity', x.quantity,
        'sell_price', COALESCE(x.sell_price, 0),
        'discount_amount', COALESCE(x.discount_amount, 0),
        'final_price', COALESCE(x.final_price, x.sell_amount),
        'sell_amount', x.sell_amount,
        'landed_unit_cost_at_sale', x.landed_unit_cost,
        'cogs', x.cogs,
        'cogs_is_loss', x.cogs_is_loss,
        'allocated_shop_delivery', x.allocated_shop_delivery,
        'allocated_shop_cod_fee', x.allocated_shop_cod_fee,
        'allocated_shop_packing', x.allocated_shop_packing,
        'allocated_return_courier', x.allocated_return_courier,
        'allocated_fees_total', x.allocated_fees_total,
        'net_profit', x.net_profit
      )
      ORDER BY x.event_at DESC NULLS LAST, x.id DESC
    ),
    '[]'::jsonb
  )
  INTO v_lines
  FROM (
    SELECT
      p.id,
      p.invoice_id,
      p.invoice_item_id,
      p.stock_id,
      p.outcome,
      p.quantity,
      p.sell_amount,
      p.allocated_shop_delivery,
      p.allocated_shop_cod_fee,
      p.allocated_shop_packing,
      p.allocated_return_courier,
      p.allocated_fees_total,
      p.cogs_is_loss,
      p.event_at,
      p.event_date,
      ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2) AS landed_unit_cost,
      CASE
        WHEN p.sell_amount > 0 OR p.cogs_is_loss THEN
          ROUND(
            ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2)
            * p.quantity,
            2
          )
        ELSE 0.00
      END AS cogs,
      ROUND(
        p.sell_amount
        - CASE
            WHEN p.sell_amount > 0 OR p.cogs_is_loss THEN
              ROUND(
                ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2)
                * p.quantity,
                2
              )
            ELSE 0.00
          END
        - p.allocated_fees_total,
        2
      ) AS net_profit,
      inv.invoice_number,
      inv.date AS invoice_date,
      i.sell_price,
      i.discount_amount,
      i.final_price,
      st.name AS stock_name,
      st.barcode
    FROM public.thrift_sales_pnl_lines p
    JOIN public.thrift_sales_invoices inv
      ON inv.id = p.invoice_id
     AND inv.tenant_id = p.tenant_id
    LEFT JOIN public.thrift_sales_invoice_items i
      ON i.id = p.invoice_item_id
     AND i.tenant_id = p.tenant_id
    LEFT JOIN public.thrift_stocks st
      ON st.id = p.stock_id
     AND st.tenant_id = p.tenant_id
    WHERE p.tenant_id = p_tenant_id
      AND p.inbound_shipment_id = p_shipment_id
  ) x;

  RETURN jsonb_build_object(
    'shipment', v_shipment,
    'summary', COALESCE(v_summary, '{}'::jsonb),
    'by_outcome', COALESCE(v_by_outcome, '[]'::jsonb),
    'lines', COALESCE(v_lines, '[]'::jsonb)
  );
END;
$$;

COMMENT ON FUNCTION public.get_thrift_shipment_sales_report(BIGINT, BIGINT) IS
  'Inbound shipment P&L from thrift_sales_pnl_lines + live COGS (includes cogs_is_loss).';

COMMIT;
