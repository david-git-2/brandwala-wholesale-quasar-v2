-- Migration: Fix sales_invoices status column name to invoice_status in get_tenant_shipment_profit_report RPC
-- Description: Updates si.status to si.invoice_status in get_tenant_shipment_profit_report.

CREATE OR REPLACE FUNCTION "public"."get_tenant_shipment_profit_report"(
  "p_tenant_id" bigint,
  "p_shipment_id" bigint DEFAULT NULL::bigint,
  "p_search" text DEFAULT NULL::text,
  "p_start_date" timestamp with time zone DEFAULT NULL::timestamp with time zone,
  "p_end_date" timestamp with time zone DEFAULT NULL::timestamp with time zone,
  "p_page" integer DEFAULT 1,
  "p_page_size" integer DEFAULT 20
) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_summary jsonb;
  v_rows jsonb;
  v_total_count integer := 0;
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(coalesce(p_page_size, 20), 1);
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'Tenant ID is required';
  END IF;

  SELECT coalesce(t.parent_id, t.id)
  INTO v_books_id
  FROM public.tenants t
  WHERE t.id = p_tenant_id;

  IF v_books_id IS NULL THEN
    RAISE EXCEPTION 'Tenant not found';
  END IF;

  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'global_shipment', 'view')
    OR public.membership_has_module_action(v_books_id, 'global_shipment', 'view')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  WITH shipment_metrics AS (
    SELECT
      s.id AS shipment_id,
      s.name AS shipment_name,
      s.tenant_shipment_id::text AS shipment_code,
      s.status AS shipment_status,
      s.created_at,
      s.shipment_cost_currency_id AS currency_id,
      
      -- Inbound Quantities & Landed Cost
      coalesce(sum(coalesce(gsi.received_quantity, gsi.ordered_quantity, 0)), 0)::int AS inbound_quantity,
      coalesce(sum(coalesce(gsi.received_quantity, gsi.ordered_quantity, 0) * coalesce(gsi.landed_cost_bdt, 0)), 0)::numeric(18,4) AS total_landed_cost,
      
      -- Sales & Returns from Issued Sales Invoices (invoice_status = 'issued')
      coalesce(sum(sales.sold_qty), 0)::int AS sold_quantity,
      coalesce(sum(sales.returned_qty), 0)::int AS returned_quantity,
      coalesce(sum(sales.net_sold_qty), 0)::int AS net_sold_quantity,
      coalesce(sum(sales.sold_revenue), 0)::numeric(18,4) AS gross_sold_revenue,
      coalesce(sum(sales.cogs), 0)::numeric(18,4) AS cogs_amount,
      coalesce(sum(sales.sold_revenue - sales.cogs), 0)::numeric(18,4) AS realized_gross_profit,
      
      -- Inventory Valuation & Damage
      coalesce(sum(inv.sellable_qty), 0)::int AS sellable_stock_qty,
      coalesce(sum(inv.held_qty), 0)::int AS held_stock_qty,
      coalesce(sum(inv.unsellable_qty), 0)::int AS damaged_stock_qty,
      coalesce(sum(inv.sellable_qty * coalesce(gsi.landed_cost_bdt, 0)), 0)::numeric(18,4) AS unsold_stock_value,
      coalesce(sum(inv.unsellable_qty * coalesce(gsi.landed_cost_bdt, 0)), 0)::numeric(18,4) AS damage_loss_value,

      -- Item details array if single shipment requested
      CASE WHEN p_shipment_id IS NOT NULL THEN
        coalesce(
          jsonb_agg(
            jsonb_build_object(
              'item_id', gsi.id,
              'product_name', coalesce(gsi.name, 'Item #' || gsi.id),
              'barcode', gsi.barcode,
              'inbound_qty', coalesce(gsi.received_quantity, gsi.ordered_quantity, 0),
              'unit_cost_bdt', gsi.landed_cost_bdt,
              'total_cost_bdt', (coalesce(gsi.received_quantity, gsi.ordered_quantity, 0) * coalesce(gsi.landed_cost_bdt, 0)),
              'sold_qty', coalesce(sales.net_sold_qty, 0),
              'sold_revenue', coalesce(sales.sold_revenue, 0),
              'cogs', coalesce(sales.cogs, 0),
              'gross_profit', coalesce(sales.sold_revenue - sales.cogs, 0),
              'sellable_qty', coalesce(inv.sellable_qty, 0),
              'unsold_stock_value', coalesce(inv.sellable_qty * coalesce(gsi.landed_cost_bdt, 0), 0),
              'damaged_qty', coalesce(inv.unsellable_qty, 0),
              'damage_loss_value', coalesce(inv.unsellable_qty * coalesce(gsi.landed_cost_bdt, 0), 0)
            )
          ) FILTER (WHERE gsi.id IS NOT NULL),
          '[]'::jsonb
        )
      ELSE NULL END AS items

    FROM public.global_shipments s
    LEFT JOIN public.global_shipment_items gsi ON gsi.shipment_id = s.id
    
    -- Subquery for aggregated sales per shipment item
    LEFT JOIN LATERAL (
      SELECT
        coalesce(sum(gii.quantity), 0) AS sold_qty,
        coalesce(sum(gii.return_quantity), 0) AS returned_qty,
        coalesce(sum(gii.quantity - gii.return_quantity), 0) AS net_sold_qty,
        coalesce(sum((gii.quantity - gii.return_quantity) * gii.sell_price_amount - coalesce(gii.line_discount_amount, 0)), 0) AS sold_revenue,
        coalesce(sum((gii.quantity - gii.return_quantity) * coalesce(gii.unit_cost_price, gsi.landed_cost_bdt, 0)), 0) AS cogs
      FROM public.global_invoice_items gii
      JOIN public.sales_invoices si ON si.id = gii.invoice_id
      WHERE gii.shipment_item_id = gsi.id
        AND si.invoice_status = 'issued'
    ) sales ON true

    -- Subquery for inventory breakdown per shipment item
    LEFT JOIN LATERAL (
      SELECT
        coalesce(sum(CASE WHEN gs.availability = 'sellable' THEN gs.quantity ELSE 0 END), 0) AS sellable_qty,
        coalesce(sum(CASE WHEN gs.availability = 'held' THEN gs.quantity ELSE 0 END), 0) AS held_qty,
        coalesce(sum(CASE WHEN gs.availability = 'unsellable' THEN gs.quantity ELSE 0 END), 0) AS unsellable_qty
      FROM public.global_stocks gs
      WHERE gs.shipment_item_id = gsi.id
    ) inv ON true

    WHERE s.parent_tenant_id = v_books_id
      AND (p_shipment_id IS NULL OR s.id = p_shipment_id)
      AND (p_start_date IS NULL OR s.created_at >= p_start_date)
      AND (p_end_date IS NULL OR s.created_at <= p_end_date)
      AND (
        p_search IS NULL 
        OR btrim(p_search) = ''
        OR s.name ILIKE ('%' || btrim(p_search) || '%')
        OR (s.tenant_shipment_id IS NOT NULL AND s.tenant_shipment_id::text ILIKE ('%' || btrim(p_search) || '%'))
      )
    GROUP BY s.id, s.name, s.tenant_shipment_id, s.status, s.created_at, s.shipment_cost_currency_id
  ),
  counted AS (
    SELECT count(*) AS total_count FROM shipment_metrics
  ),
  summary_calc AS (
    SELECT
      coalesce(sum(inbound_quantity), 0)::int AS total_inbound_units,
      coalesce(sum(total_landed_cost), 0)::numeric(18,4) AS total_landed_cost,
      coalesce(sum(net_sold_quantity), 0)::int AS total_net_sold_units,
      coalesce(sum(gross_sold_revenue), 0)::numeric(18,4) AS total_gross_sold_revenue,
      coalesce(sum(cogs_amount), 0)::numeric(18,4) AS total_cogs,
      coalesce(sum(realized_gross_profit), 0)::numeric(18,4) AS total_realized_gross_profit,
      CASE
        WHEN coalesce(sum(gross_sold_revenue), 0) > 0
        THEN round((coalesce(sum(realized_gross_profit), 0) / sum(gross_sold_revenue) * 100)::numeric, 2)
        ELSE 0.00
      END AS overall_realized_gp_margin_pct,
      coalesce(sum(unsold_stock_value), 0)::numeric(18,4) AS total_unsold_stock_value,
      coalesce(sum(damage_loss_value), 0)::numeric(18,4) AS total_damage_loss_value,
      count(*)::int AS total_shipments_count
    FROM shipment_metrics
  ),
  paginated_rows AS (
    SELECT
      sm.*,
      CASE
        WHEN sm.gross_sold_revenue > 0
        THEN round((sm.realized_gross_profit / sm.gross_sold_revenue * 100)::numeric, 2)
        ELSE 0.00
      END AS realized_gp_margin_pct,
      CASE
        WHEN sm.inbound_quantity > 0
        THEN round((sm.net_sold_quantity::numeric / sm.inbound_quantity::numeric * 100)::numeric, 1)
        ELSE 0.0
      END AS batch_sold_pct
    FROM shipment_metrics sm
    ORDER BY sm.created_at DESC, sm.shipment_id DESC
    OFFSET (v_page - 1) * v_page_size
    LIMIT v_page_size
  )
  SELECT
    to_jsonb(s),
    coalesce((SELECT total_count FROM counted), 0),
    coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  INTO v_summary, v_total_count, v_rows
  FROM summary_calc s
  CROSS JOIN paginated_rows r
  GROUP BY to_jsonb(s);

  RETURN jsonb_build_object(
    'summary', coalesce(v_summary, jsonb_build_object(
      'total_inbound_units', 0,
      'total_landed_cost', 0,
      'total_net_sold_units', 0,
      'total_gross_sold_revenue', 0,
      'total_cogs', 0,
      'total_realized_gross_profit', 0,
      'overall_realized_gp_margin_pct', 0,
      'total_unsold_stock_value', 0,
      'total_damage_loss_value', 0,
      'total_shipments_count', 0
    )),
    'shipments', coalesce(v_rows, '[]'::jsonb),
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', v_page,
      'page_size', v_page_size,
      'total_pages', CASE WHEN v_total_count = 0 THEN 1 ELSE ceil(v_total_count::numeric / v_page_size::numeric)::int END
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION "public"."get_tenant_shipment_profit_report"(BIGINT, BIGINT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, INTEGER, INTEGER) TO "authenticated";

COMMENT ON FUNCTION "public"."get_tenant_shipment_profit_report" IS 'Consolidated batch shipment profit, landed cost, COGS, realized gross profit, remaining stock valuation and damage reporting.';
