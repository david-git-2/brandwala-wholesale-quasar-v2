-- RT13: invoice profit detail lines — scoped line_metrics CTE on detail SELECT

CREATE OR REPLACE FUNCTION "public"."get_tenant_invoice_profit_report"("p_tenant_id" bigint, "p_start_date" "date" DEFAULT NULL::"date", "p_end_date" "date" DEFAULT NULL::"date", "p_search" "text" DEFAULT NULL::"text", "p_issued_by_tenant_id" bigint DEFAULT NULL::bigint, "p_invoice_id" bigint DEFAULT NULL::bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 50, "p_skip_count" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_totals jsonb;
  v_rows jsonb;
  v_lines jsonb := NULL;
  v_total_count bigint;
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_offset integer := (greatest(coalesce(p_page, 1), 1) - 1) * greatest(least(coalesce(p_page_size, 50), 200), 1);
BEGIN
  IF p_tenant_id IS NULL THEN RAISE EXCEPTION 'Tenant ID is required'; END IF;
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN RAISE EXCEPTION 'Not authorized'; END IF;

  WITH line_metrics AS (
    SELECT
      sii.invoice_id,
      sii.id AS item_id,
      sii.name_snapshot AS name,
      sii.barcode_snapshot AS barcode,
      sii.quantity,
      sii.return_quantity,
      greatest(sii.quantity - sii.return_quantity, 0) AS net_qty,
      round(
        greatest(sii.quantity - sii.return_quantity, 0) * sii.sell_price_amount
        - coalesce(sii.line_discount_amount, 0) * (greatest(sii.quantity - sii.return_quantity, 0) / nullif(sii.quantity, 0)),
        2
      ) AS net_revenue,
      round(greatest(sii.quantity - sii.return_quantity, 0) * coalesce(sii.unit_cost_price, 0), 2) AS cogs
    FROM public.sales_invoice_items sii
    JOIN public.sales_invoices si ON si.id = sii.invoice_id
    WHERE si.parent_tenant_id = v_books_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND (p_invoice_id IS NULL OR si.id = p_invoice_id)
      AND (p_start_date IS NULL OR si.invoice_date >= p_start_date)
      AND (p_end_date IS NULL OR si.invoice_date <= p_end_date)
      AND (p_issued_by_tenant_id IS NULL OR si.issued_by_tenant_id = p_issued_by_tenant_id)
  ),
  invoice_metrics AS (
    SELECT
      si.id,
      si.invoice_no,
      si.invoice_date,
      coalesce(nullif(trim(bp.name), ''), nullif(trim(si.recipient_name), ''), 'Unknown') AS customer_name,
      round(coalesce(sum(lm.net_qty), 0), 3) AS net_qty,
      round(coalesce(sum(lm.net_revenue), 0), 2) AS net_revenue,
      round(coalesce(sum(lm.cogs), 0), 2) AS cogs,
      round(coalesce(sum(lm.net_revenue - lm.cogs), 0), 2) AS realized_gp
    FROM public.sales_invoices si
    LEFT JOIN public.billing_profiles bp ON bp.id = si.billing_profile_id
    LEFT JOIN line_metrics lm ON lm.invoice_id = si.id
    WHERE si.parent_tenant_id = v_books_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND (p_invoice_id IS NULL OR si.id = p_invoice_id)
      AND (p_start_date IS NULL OR si.invoice_date >= p_start_date)
      AND (p_end_date IS NULL OR si.invoice_date <= p_end_date)
      AND (p_issued_by_tenant_id IS NULL OR si.issued_by_tenant_id = p_issued_by_tenant_id)
      AND (
        p_search IS NULL OR btrim(p_search) = ''
        OR si.invoice_no ILIKE ('%' || btrim(p_search) || '%')
        OR bp.name ILIKE ('%' || btrim(p_search) || '%')
        OR si.recipient_name ILIKE ('%' || btrim(p_search) || '%')
      )
    GROUP BY si.id, si.invoice_no, si.invoice_date, bp.name, si.recipient_name
  ),
  enriched AS (
    SELECT *,
      CASE WHEN net_revenue > 0 THEN round((realized_gp / net_revenue) * 100, 2) ELSE 0 END AS gp_margin_pct
    FROM invoice_metrics
  ),
  totals_calc AS (
    SELECT round(coalesce(sum(net_qty), 0), 3) AS net_sold_qty,
      round(coalesce(sum(net_revenue), 0), 2) AS net_revenue,
      round(coalesce(sum(cogs), 0), 2) AS cogs,
      round(coalesce(sum(realized_gp), 0), 2) AS realized_gp,
      CASE WHEN coalesce(sum(net_revenue), 0) > 0
        THEN round((coalesce(sum(realized_gp), 0) / coalesce(sum(net_revenue), 0)) * 100, 2) ELSE 0 END AS gp_margin_pct,
      count(*)::bigint AS invoice_count
    FROM enriched
  ),
  paged AS (
    SELECT * FROM enriched ORDER BY invoice_date DESC, id DESC OFFSET v_offset LIMIT v_page_size
  )
  SELECT (SELECT count(*) FROM enriched),
    (SELECT jsonb_build_object('net_sold_qty', net_sold_qty, 'net_revenue', net_revenue, 'cogs', cogs,
      'realized_gp', realized_gp, 'gp_margin_pct', gp_margin_pct, 'invoice_count', invoice_count) FROM totals_calc),
    coalesce((SELECT jsonb_agg(jsonb_build_object(
      'id', id, 'invoice_no', invoice_no, 'invoice_date', invoice_date, 'customer_name', customer_name,
      'net_qty', net_qty, 'net_revenue', net_revenue, 'cogs', cogs, 'realized_gp', realized_gp, 'gp_margin_pct', gp_margin_pct
    ) ORDER BY invoice_date DESC, id DESC) FROM paged), '[]'::jsonb)
  INTO v_total_count, v_totals, v_rows;

  IF p_invoice_id IS NOT NULL THEN
    WITH line_metrics AS (
      SELECT
        sii.invoice_id,
        sii.id AS item_id,
        sii.name_snapshot AS name,
        sii.barcode_snapshot AS barcode,
        sii.quantity,
        sii.return_quantity,
        greatest(sii.quantity - sii.return_quantity, 0) AS net_qty,
        round(
          greatest(sii.quantity - sii.return_quantity, 0) * sii.sell_price_amount
          - coalesce(sii.line_discount_amount, 0) * (greatest(sii.quantity - sii.return_quantity, 0) / nullif(sii.quantity, 0)),
          2
        ) AS net_revenue,
        round(greatest(sii.quantity - sii.return_quantity, 0) * coalesce(sii.unit_cost_price, 0), 2) AS cogs
      FROM public.sales_invoice_items sii
      WHERE sii.invoice_id = p_invoice_id
    )
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      'item_id', lm.item_id, 'name', lm.name, 'barcode', lm.barcode,
      'quantity', lm.quantity, 'return_quantity', lm.return_quantity, 'net_qty', lm.net_qty,
      'sell_price_amount', round(lm.net_revenue / nullif(lm.net_qty, 0), 2),
      'unit_cost_price', round(lm.cogs / nullif(lm.net_qty, 0), 2),
      'net_revenue', lm.net_revenue, 'cogs', lm.cogs, 'line_gp', round(lm.net_revenue - lm.cogs, 2)
    ) ORDER BY lm.item_id), '[]'::jsonb)
    INTO v_lines
    FROM line_metrics lm;
  END IF;

  RETURN jsonb_build_object(
    'totals', coalesce(v_totals, '{}'::jsonb),
    'rows', coalesce(v_rows, '[]'::jsonb),
    'lines', v_lines,
    'page', v_page,
    'page_size', v_page_size,
    'total_count', CASE WHEN coalesce(p_skip_count, true) THEN NULL ELSE v_total_count END
  );
END;
$$;
