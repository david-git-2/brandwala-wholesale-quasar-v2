-- Shipment sales report from thrift_sales_pnl_lines (DELIVERED + RTO + CUSTOMER_RETURN).

BEGIN;

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
      p.event_at,
      p.event_date,
      ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2) AS landed_unit_cost,
      CASE
        WHEN p.sell_amount > 0 THEN
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
            WHEN p.sell_amount > 0 THEN
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
          WHEN p2.sell_amount > 0 THEN
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
              WHEN p2.sell_amount > 0 THEN
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
      p.event_at,
      p.event_date,
      ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2) AS landed_unit_cost,
      CASE
        WHEN p.sell_amount > 0 THEN
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
            WHEN p.sell_amount > 0 THEN
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
  'Inbound shipment P&L from thrift_sales_pnl_lines (DELIVERED/RTO/CUSTOMER_RETURN) + live COGS.';

GRANT EXECUTE ON FUNCTION public.get_thrift_shipment_sales_report(BIGINT, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_thrift_shipment_sales_report(BIGINT, BIGINT) TO service_role;

COMMIT;
