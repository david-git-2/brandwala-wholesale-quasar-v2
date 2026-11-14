-- Kernel bills P&L + desk reads + DP outcome + backfill stock lines
CREATE OR REPLACE FUNCTION public._kernel_backfill_stock_bill_lines(p_bill_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO money_kernel, public, pg_temp
AS $$
DECLARE
  v_bill money_kernel.bills;
  v_line record;
  v_shipment_item_id bigint;
  v_shipment_id bigint;
  v_product_id bigint;
  v_ref jsonb;
BEGIN
  SELECT * INTO v_bill FROM money_kernel.bills WHERE id = p_bill_id;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  FOR v_line IN
    SELECT bl.*
    FROM money_kernel.bill_lines bl
    WHERE bl.bill_id = p_bill_id
      AND (
        bl.item_kind = 'stock'
        OR (
          bl.item_kind = 'charge'
          AND nullif(v_bill.meta->>'delivery_paper_id', '') IS NOT NULL
        )
      )
    FOR UPDATE OF bl
  LOOP
    v_shipment_item_id := v_line.shipment_item_id;
    v_shipment_id := v_line.shipment_id;
    v_product_id := v_line.product_id;

    IF v_line.global_stock_id IS NOT NULL THEN
      SELECT
        coalesce(v_shipment_item_id, gs.shipment_item_id),
        coalesce(v_shipment_id, gsi.shipment_id),
        coalesce(v_product_id, gsi.product_id)
      INTO v_shipment_item_id, v_shipment_id, v_product_id
      FROM public.global_stocks gs
      LEFT JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
      WHERE gs.id = v_line.global_stock_id;
    END IF;

    IF v_shipment_item_id IS NULL THEN
      v_ref := coalesce(v_line.meta->'shipment_ref', '{}'::jsonb);
      IF nullif(v_ref->>'shipment_item_id', '') IS NOT NULL THEN
        v_shipment_item_id := (v_ref->>'shipment_item_id')::bigint;
        v_shipment_id := coalesce(
          v_shipment_id,
          nullif(v_ref->>'shipment_id', '')::bigint
        );
      END IF;
    END IF;

    IF v_shipment_item_id IS NULL AND v_product_id IS NOT NULL THEN
      v_ref := public.resolve_shipment_item_for_shop_order_product(
        v_bill.tenant_id,
        NULL,
        v_product_id
      );
      IF nullif(v_ref->>'shipment_item_id', '') IS NOT NULL THEN
        v_shipment_item_id := (v_ref->>'shipment_item_id')::bigint;
        v_shipment_id := coalesce(
          v_shipment_id,
          nullif(v_ref->>'shipment_id', '')::bigint
        );
      END IF;
    END IF;

    IF v_shipment_item_id IS NOT NULL AND v_shipment_id IS NULL THEN
      SELECT gsi.shipment_id
      INTO v_shipment_id
      FROM public.global_shipment_items gsi
      WHERE gsi.id = v_shipment_item_id;
    END IF;

    IF v_shipment_item_id IS NULL
       AND nullif(v_bill.meta->>'delivery_paper_id', '') IS NOT NULL
       AND v_line.global_stock_id IS NULL THEN
      CONTINUE;
    END IF;

    UPDATE money_kernel.bill_lines
    SET
      item_kind = CASE
        WHEN v_line.global_stock_id IS NOT NULL AND v_shipment_item_id IS NOT NULL THEN 'stock'
        ELSE item_kind
      END,
      shipment_item_id = coalesce(v_shipment_item_id, shipment_item_id),
      shipment_id = coalesce(v_shipment_id, shipment_id),
      product_id = coalesce(product_id, v_product_id)
    WHERE id = v_line.id;
  END LOOP;
END;
$$;
CREATE OR REPLACE FUNCTION public.get_bill_detail_bundle(
  p_tenant_id bigint,
  p_bill_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
BEGIN
  IF p_tenant_id IS NULL OR p_bill_id IS NULL THEN
    RAISE EXCEPTION 'Tenant and bill are required.';
  END IF;

  RETURN public._get_bill_detail_bundle_from_kernel(p_tenant_id, p_bill_id);
END;
$$;
CREATE OR REPLACE FUNCTION public.get_tenant_shipment_profit_report (
  p_tenant_id   bigint,
  p_shipment_id bigint                   DEFAULT NULL::bigint,
  p_search      text                     DEFAULT NULL::text,
  p_start_date  timestamp with time zone DEFAULT NULL::timestamp WITH time zone,
  p_end_date    timestamp with time zone DEFAULT NULL::timestamp WITH time zone,
  p_page        integer                  DEFAULT 1,
  p_page_size   integer                  DEFAULT 20
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public', 'money_kernel'
  AS $function$
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
      
      -- Inbound Quantities & Landed Cost (ordered manifest, not sold-only received)
      coalesce(sum(gsi.ordered_quantity), 0)::int AS inbound_quantity,
      coalesce(sum(gsi.ordered_quantity * coalesce(gsi.landed_cost_bdt, 0)), 0)::numeric(18,4) AS total_landed_cost,
      
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
      coalesce(sum(
        greatest(gsi.ordered_quantity - coalesce(sales.net_sold_qty, 0), coalesce(inv.sellable_qty, 0))
        * coalesce(gsi.landed_cost_bdt, 0)
      ), 0)::numeric(18,4) AS unsold_stock_value,
      coalesce(sum(inv.unsellable_qty * coalesce(gsi.landed_cost_bdt, 0)), 0)::numeric(18,4) AS damage_loss_value,

      -- Item details array if single shipment requested
      CASE WHEN p_shipment_id IS NOT NULL THEN
        coalesce(
          jsonb_agg(
            jsonb_build_object(
              'item_id', gsi.id,
              'product_name', coalesce(gsi.name, 'Item #' || gsi.id),
              'barcode', gsi.barcode,
              'inbound_qty', gsi.ordered_quantity,
              'unit_cost_bdt', gsi.landed_cost_bdt,
              'total_cost_bdt', (gsi.ordered_quantity * coalesce(gsi.landed_cost_bdt, 0)),
              'sold_qty', coalesce(sales.net_sold_qty, 0),
              'sold_revenue', coalesce(sales.sold_revenue, 0),
              'cogs', coalesce(sales.cogs, 0),
              'gross_profit', coalesce(sales.sold_revenue - sales.cogs, 0),
              'sellable_qty', coalesce(inv.sellable_qty, 0),
              'unsold_stock_value', coalesce(
                greatest(gsi.ordered_quantity - coalesce(sales.net_sold_qty, 0), coalesce(inv.sellable_qty, 0))
                * coalesce(gsi.landed_cost_bdt, 0),
                0
              ),
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
        coalesce(sum(bl.quantity), 0) AS sold_qty,
        0::numeric AS returned_qty,
        coalesce(sum(bl.quantity), 0) AS net_sold_qty,
        coalesce(sum(
          bl.line_total
          - CASE
            WHEN si.kind = 'sales_invoice_dropship' THEN 0.00
            ELSE coalesce(si.written_off_amount, 0.00)
              * (bl.line_total / nullif(si.total_amount, 0.00))
          END
        ), 0) AS sold_revenue,
        coalesce(sum(bl.quantity * coalesce(gsi.landed_cost_bdt, 0)), 0) AS cogs
      FROM money_kernel.bill_lines bl
      JOIN money_kernel.bills si ON si.id = bl.bill_id
      LEFT JOIN public.global_stocks gs ON gs.id = bl.global_stock_id
      WHERE si.tenant_id = v_books_id
        AND si.status IN ('issued', 'partial', 'paid')
        AND si.kind IN (
          'sales_invoice_wholesale',
          'sales_invoice_retail',
          'sales_invoice_dropship'
        )
        AND gsi.id = coalesce(
          bl.shipment_item_id,
          nullif(bl.meta->'shipment_ref'->>'shipment_item_id', '')::bigint,
          gs.shipment_item_id,
          (
            SELECT gsi_fb.id
            FROM public.global_shipment_items gsi_fb
            WHERE gsi_fb.shipment_id = gsi.shipment_id
              AND gsi_fb.product_id IS NOT NULL
              AND gsi_fb.product_id = bl.product_id
            ORDER BY gsi_fb.id
            LIMIT 1
          )
        )
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

    WHERE s.tenant_id = v_books_id
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
$function$;

COMMENT ON FUNCTION public.get_tenant_shipment_profit_report(bigint,bigint,text,timestamp with time zone,timestamp with time zone,integer,integer) IS 'Consolidated batch shipment profit, landed cost, COGS, realized gross profit, remaining stock valuation and damage reporting.';

GRANT ALL ON FUNCTION public.get_tenant_shipment_profit_report(bigint, bigint, text, timestamp WITH time zone, timestamp WITH time zone, integer, integer) TO anon;

GRANT ALL ON FUNCTION public.get_tenant_shipment_profit_report(bigint, bigint, text, timestamp WITH time zone, timestamp WITH time zone, integer, integer) TO authenticated;

GRANT ALL ON FUNCTION public.get_tenant_shipment_profit_report(bigint, bigint, text, timestamp WITH time zone, timestamp WITH time zone, integer, integer) TO service_role;CREATE OR REPLACE FUNCTION public.get_tenant_shipment_report_detail (
  p_tenant_id   bigint,
  p_shipment_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public', 'money_kernel'
  AS $function$
DECLARE
  v_books_id bigint;
  v_profit jsonb;
  v_pnl jsonb;
  v_header jsonb;
  v_ap_bills jsonb;
  v_ap_totals jsonb;
  v_customer_bills jsonb;
  v_customer_revenue numeric(18,4) := 0;
  v_fx jsonb;
  v_exchange_rates jsonb;
  v_qty_summary jsonb;
  v_cost_buckets jsonb;
  v_sell_lines jsonb;
  v_profit_matrix jsonb;
  v_unpaid_customers jsonb;
  v_total_sell numeric(18,4) := 0;
  v_total_cost_bdt numeric(18,4) := 0;
  v_receive_loss_bdt numeric(18,4) := 0;
  v_unpaid_total_bdt numeric(18,4) := 0;
BEGIN
  IF p_tenant_id IS NULL OR p_shipment_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id and shipment_id are required';
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

  IF NOT EXISTS (
    SELECT 1
    FROM public.global_shipments s
    WHERE s.id = p_shipment_id
      AND s.tenant_id = v_books_id
  ) THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  SELECT jsonb_build_object(
    'shipment_id', s.id,
    'shipment_name', s.name,
    'shipment_no', CASE
      WHEN s.tenant_shipment_id IS NOT NULL THEN
        public.format_assigned_document_number(v_books_id, 'shipment', s.tenant_shipment_id::bigint, s.created_at)
      ELSE NULL
    END,
    'tenant_shipment_id', s.tenant_shipment_id,
    'shipment_status', s.status,
    'shipment_type', s.type,
    'vendor_id', s.vendor_id,
    'vendor_name', v.name,
    'created_at', s.created_at,
    'received_date', s.received_date
  )
  INTO v_header
  FROM public.global_shipments s
  LEFT JOIN public.vendors v ON v.id = s.vendor_id
  WHERE s.id = p_shipment_id;

  v_profit := public.get_tenant_shipment_profit_report(
    p_tenant_id,
    p_shipment_id,
    null,
    null,
    null,
    1,
    1
  );
  v_pnl := coalesce(v_profit->'shipments'->0, 'null'::jsonb);

  v_fx := public._global_shipment_landed_fx_inputs(p_shipment_id);
  v_exchange_rates := jsonb_build_object(
    'product_rate', coalesce((v_fx ->> 'product_conversion_rate')::numeric, 1),
    'freight_rate', coalesce((v_fx ->> 'cargo_conversion_rate')::numeric, 1),
    'blended_rate', coalesce((v_fx ->> 'transaction_rate')::numeric, 1),
    'cargo_foreign_per_kg', nullif((v_fx ->> 'cargo_rate')::numeric, 0),
    'material_payment_count', coalesce((v_fx -> 'material' ->> 'payment_count')::integer, 0),
    'freight_payment_count', coalesce((v_fx -> 'freight' ->> 'payment_count')::integer, 0)
  );

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', b.id,
        'invoice_no', b.invoice_no,
        'ap_kind', coalesce(
          nullif(btrim(b.meta->>'ap_kind'), ''),
          nullif(split_part(coalesce(b.source_key, ''), ':', 1), '')
        ),
        'invoice_status', b.status,
        'payment_status', public._desk_kernel_status_payment(b.status, b.due_amount),
        'currency_code', b.currency_code,
        'txn_currency_code', coalesce(nullif(btrim(b.meta->>'txn_currency_code'), ''), b.currency_code),
        'txn_total_amount', coalesce((b.meta->>'txn_total_amount')::numeric(18, 4), b.total_amount),
        'books_exchange_rate', (b.meta->>'books_exchange_rate')::numeric(18, 4),
        'total_amount', b.total_amount,
        'due_amount', b.due_amount,
        'open_books', coalesce((public._desk_kernel_net_balances_json(b.id)->>'open_books')::numeric, b.due_amount)
      )
      ORDER BY b.id
    ),
    '[]'::jsonb
  )
  INTO v_ap_bills
  FROM money_kernel.bills b
  WHERE b.tenant_id = v_books_id
    AND b.status <> 'voided'
    AND b.kind = 'shipment_cost_ap'
    AND (
      (b.source_type = 'shipment_cost' AND b.source_id = p_shipment_id::text)
      OR (b.meta->>'shipment_id')::bigint = p_shipment_id
    );

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'currency_code', g.currency_code,
        'bill_count', g.bill_count,
        'txn_total_amount', g.txn_total_amount,
        'books_total_amount', g.books_total_amount
      )
      ORDER BY g.currency_code
    ),
    '[]'::jsonb
  )
  INTO v_ap_totals
  FROM (
    SELECT
      coalesce(
        nullif(btrim(b.meta->>'txn_currency_code'), ''),
        nullif(btrim(b.currency_code), ''),
        'BDT'
      ) AS currency_code,
      count(*)::int AS bill_count,
      coalesce(sum(coalesce((b.meta->>'txn_total_amount')::numeric(18, 4), b.total_amount)), 0)::numeric(18,4) AS txn_total_amount,
      coalesce(sum(b.total_amount), 0)::numeric(18,4) AS books_total_amount
    FROM money_kernel.bills b
    WHERE b.tenant_id = v_books_id
      AND b.status <> 'voided'
      AND b.kind = 'shipment_cost_ap'
      AND (
        (b.source_type = 'shipment_cost' AND b.source_id = p_shipment_id::text)
        OR (b.meta->>'shipment_id')::bigint = p_shipment_id
      )
    GROUP BY 1
  ) g;

  WITH bill_attr AS (
    SELECT
      b.id AS bill_id,
      b.invoice_no,
      b.invoice_date,
      public._desk_kernel_kind_invoice_type(b.kind) AS invoice_type,
      b.currency_code,
      b.from_profile_id AS profile_id,
      coalesce(p.name, 'Customer') AS customer_name,
      coalesce(sum(
        bl.line_total
        - CASE
          WHEN b.kind = 'sales_invoice_dropship' THEN 0.00
          ELSE coalesce(b.written_off_amount, 0.00)
            * (bl.line_total / nullif(b.total_amount, 0.00))
        END
      ), 0)::numeric(18,4) AS attributed_revenue_bdt,
      coalesce(sum(bl.quantity), 0)::int AS attributed_qty
    FROM money_kernel.bill_lines bl
    JOIN money_kernel.bills b ON b.id = bl.bill_id
    LEFT JOIN public.global_stocks gs ON gs.id = bl.global_stock_id
    JOIN public.global_shipment_items gsi
      ON gsi.shipment_id = p_shipment_id
     AND gsi.id = coalesce(
       bl.shipment_item_id,
       nullif(bl.meta->'shipment_ref'->>'shipment_item_id', '')::bigint,
       gs.shipment_item_id,
       (
         SELECT gsi_fb.id
         FROM public.global_shipment_items gsi_fb
         WHERE gsi_fb.shipment_id = p_shipment_id
           AND gsi_fb.product_id IS NOT NULL
           AND gsi_fb.product_id = bl.product_id
         ORDER BY gsi_fb.id
         LIMIT 1
       )
     )
    LEFT JOIN public.profiles p ON p.id = b.from_profile_id
    WHERE gsi.shipment_id = p_shipment_id
      AND b.tenant_id = v_books_id
      AND b.status IN ('issued', 'partial', 'paid')
      AND b.kind IN (
        'sales_invoice_wholesale',
        'sales_invoice_retail',
        'sales_invoice_dropship'
      )
    GROUP BY
      b.id, b.invoice_no, b.invoice_date, b.kind, b.currency_code, b.from_profile_id, p.name
    HAVING coalesce(sum(bl.quantity), 0) > 0
  )
  SELECT
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', bill_attr.bill_id,
          'invoice_no', bill_attr.invoice_no,
          'invoice_date', bill_attr.invoice_date,
          'invoice_type', bill_attr.invoice_type,
          'currency_code', bill_attr.currency_code,
          'profile_id', bill_attr.profile_id,
          'customer_name', bill_attr.customer_name,
          'attributed_revenue_bdt', bill_attr.attributed_revenue_bdt,
          'attributed_qty', bill_attr.attributed_qty
        )
        ORDER BY bill_attr.invoice_date DESC, bill_attr.bill_id DESC
      ),
      '[]'::jsonb
    ),
    coalesce(sum(bill_attr.attributed_revenue_bdt), 0)
  INTO v_customer_bills, v_customer_revenue
  FROM bill_attr;

  SELECT
    coalesce(sum(coalesce(oc.lost_qty, 0) * coalesce(gsi.landed_cost_bdt, 0)), 0)::numeric(18,4)
  INTO v_receive_loss_bdt
  FROM public.global_shipment_items gsi
  LEFT JOIN LATERAL (
    SELECT
      coalesce(sum(o.quantity) FILTER (
        WHERE o.reason IN (
          'missing'::public.global_shipment_outcome_reason,
          'damaged'::public.global_shipment_outcome_reason
        )
      ), 0)::int AS lost_qty
    FROM public.global_shipment_item_outcomes o
    WHERE o.shipment_item_id = gsi.id
  ) oc ON true
  WHERE gsi.shipment_id = p_shipment_id;

  SELECT jsonb_build_object(
    'should_arrive', coalesce(sum(gsi.ordered_quantity), 0)::int,
    'arrived', coalesce(
      sum(
        coalesce(
          oc.go_to_stock,
          greatest(gsi.ordered_quantity - coalesce(oc.lost_qty, 0), 0)
        )
      ),
      0
    )::int,
    'loss_at_shipment', coalesce(sum(coalesce(oc.lost_qty, 0)), 0)::int,
    'warehouse_stalled', coalesce((v_pnl ->> 'held_stock_qty')::int, 0),
    'warehouse_remaining', coalesce((v_pnl ->> 'sellable_stock_qty')::int, 0),
    'sold', coalesce((v_pnl ->> 'net_sold_quantity')::int, 0),
    'warehouse_value_bdt', coalesce((v_pnl ->> 'unsold_stock_value')::numeric(18,4), 0)
  )
  INTO v_qty_summary
  FROM public.global_shipment_items gsi
  LEFT JOIN LATERAL (
    SELECT
      coalesce(sum(o.quantity) FILTER (
        WHERE o.kind = 'sellable'::public.global_shipment_outcome_kind
          AND o.reason NOT IN (
            'ordered'::public.global_shipment_outcome_reason,
            'vendor_discount'::public.global_shipment_outcome_reason
          )
      ), 0)::int AS go_to_stock,
      coalesce(sum(o.quantity) FILTER (
        WHERE o.reason IN (
          'missing'::public.global_shipment_outcome_reason,
          'damaged'::public.global_shipment_outcome_reason
        )
      ), 0)::int AS lost_qty
    FROM public.global_shipment_item_outcomes o
    WHERE o.shipment_item_id = gsi.id
  ) oc ON true
  WHERE gsi.shipment_id = p_shipment_id;

  WITH shipment_ap AS (
    SELECT
      b.total_amount,
      coalesce((b.meta->>'txn_total_amount')::numeric(18, 4), b.total_amount) AS txn_total,
      coalesce(
        nullif(btrim(b.meta->>'txn_currency_code'), ''),
        nullif(btrim(b.currency_code), ''),
        'BDT'
      ) AS txn_ccy,
      coalesce(
        nullif(btrim(b.meta->>'ap_kind'), ''),
        nullif(split_part(coalesce(b.source_key, ''), ':', 1), ''),
        'other'
      ) AS ap_kind
    FROM money_kernel.bills b
    WHERE b.tenant_id = v_books_id
      AND b.status <> 'voided'
      AND b.kind = 'shipment_cost_ap'
      AND (
        (b.source_type = 'shipment_cost' AND b.source_id = p_shipment_id::text)
        OR (b.meta->>'shipment_id')::bigint = p_shipment_id
      )
  ),
  kind_bdt AS (
    SELECT ap_kind, coalesce(sum(total_amount), 0)::numeric(18,4) AS bdt_amount
    FROM shipment_ap
    GROUP BY ap_kind
  ),
  kind_foreign AS (
    SELECT
      ap_kind,
      txn_ccy AS currency_code,
      coalesce(sum(txn_total), 0)::numeric(18,4) AS amount
    FROM shipment_ap
    WHERE upper(txn_ccy) <> 'BDT'
    GROUP BY ap_kind, txn_ccy
  ),
  legs AS (
    SELECT
      ap_kind,
      coalesce(
        jsonb_agg(
          jsonb_build_object('currency_code', currency_code, 'amount', amount)
          ORDER BY currency_code
        ),
        '[]'::jsonb
      ) AS foreign_legs
    FROM kind_foreign
    GROUP BY ap_kind
  ),
  dominant_foreign AS (
    SELECT DISTINCT ON (ap_kind)
      ap_kind,
      currency_code AS foreign_currency,
      amount AS foreign_amount
    FROM kind_foreign
    ORDER BY ap_kind, amount DESC, currency_code
  )
  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'ap_kind', k.ap_kind,
        'label', CASE k.ap_kind
          WHEN 'material' THEN 'Goods'
          WHEN 'freight' THEN 'Flight'
          WHEN 'customs' THEN 'Customs'
          WHEN 'handling' THEN 'Handling'
          WHEN 'finance' THEN 'Finance'
          WHEN 'vendor' THEN 'Vendor'
          WHEN 'cargo' THEN 'Cargo'
          WHEN 'local' THEN 'Local'
          WHEN 'other' THEN 'Other'
          ELSE initcap(replace(k.ap_kind, '_', ' '))
        END,
        'bdt_amount', CASE
          WHEN k.ap_kind = 'material'
            AND coalesce((v_fx -> 'material' ->> 'payment_count')::int, 0) > 0
            THEN coalesce((v_fx -> 'material' ->> 'bdt_paid')::numeric(18,4), k.bdt_amount)
          WHEN k.ap_kind = 'freight'
            AND coalesce((v_fx -> 'freight' ->> 'payment_count')::int, 0) > 0
            THEN coalesce((v_fx -> 'freight' ->> 'bdt_paid')::numeric(18,4), k.bdt_amount)
          ELSE k.bdt_amount
        END,
        'foreign_legs', CASE
          WHEN k.ap_kind = 'material'
            AND coalesce((v_fx -> 'material' ->> 'payment_count')::int, 0) > 0
            AND coalesce((v_fx -> 'material' ->> 'foreign_paid')::numeric, 0) > 0
            THEN jsonb_build_array(
              jsonb_build_object(
                'currency_code', coalesce(df.foreign_currency, 'GBP'),
                'amount', (v_fx -> 'material' ->> 'foreign_paid')::numeric(18,4)
              )
            )
          WHEN k.ap_kind = 'freight'
            AND coalesce((v_fx -> 'freight' ->> 'payment_count')::int, 0) > 0
            AND coalesce((v_fx -> 'freight' ->> 'foreign_paid')::numeric, 0) > 0
            THEN jsonb_build_array(
              jsonb_build_object(
                'currency_code', coalesce(df.foreign_currency, 'GBP'),
                'amount', (v_fx -> 'freight' ->> 'foreign_paid')::numeric(18,4)
              )
            )
          ELSE coalesce(l.foreign_legs, '[]'::jsonb)
        END,
        'foreign_amount', CASE
          WHEN k.ap_kind = 'material'
            AND coalesce((v_fx -> 'material' ->> 'payment_count')::int, 0) > 0
            AND coalesce((v_fx -> 'material' ->> 'foreign_paid')::numeric, 0) > 0
            THEN (v_fx -> 'material' ->> 'foreign_paid')::numeric(18,4)
          WHEN k.ap_kind = 'freight'
            AND coalesce((v_fx -> 'freight' ->> 'payment_count')::int, 0) > 0
            AND coalesce((v_fx -> 'freight' ->> 'foreign_paid')::numeric, 0) > 0
            THEN (v_fx -> 'freight' ->> 'foreign_paid')::numeric(18,4)
          ELSE df.foreign_amount
        END,
        'foreign_currency', CASE
          WHEN k.ap_kind = 'material'
            AND coalesce((v_fx -> 'material' ->> 'payment_count')::int, 0) > 0
            AND coalesce((v_fx -> 'material' ->> 'foreign_paid')::numeric, 0) > 0
            THEN coalesce(df.foreign_currency, 'GBP')
          WHEN k.ap_kind = 'freight'
            AND coalesce((v_fx -> 'freight' ->> 'payment_count')::int, 0) > 0
            AND coalesce((v_fx -> 'freight' ->> 'foreign_paid')::numeric, 0) > 0
            THEN coalesce(df.foreign_currency, 'GBP')
          ELSE df.foreign_currency
        END
      )
      ORDER BY
        CASE k.ap_kind
          WHEN 'material' THEN 1
          WHEN 'freight' THEN 2
          WHEN 'customs' THEN 3
          WHEN 'handling' THEN 4
          WHEN 'finance' THEN 5
          ELSE 10
        END,
        k.ap_kind
    ),
    '[]'::jsonb
  )
  INTO v_cost_buckets
  FROM kind_bdt k
  LEFT JOIN legs l ON l.ap_kind = k.ap_kind
  LEFT JOIN dominant_foreign df ON df.ap_kind = k.ap_kind;

  WITH line_attr AS (
    SELECT
      b.id AS bill_id,
      b.invoice_no,
      bl.id AS invoice_item_id,
      coalesce(nullif(btrim(gsi.name), ''), nullif(btrim(bl.description), ''), 'Item') AS product_name,
      greatest(bl.quantity, 0)::int AS qty,
      (
        bl.line_total
        - CASE
          WHEN b.kind = 'sales_invoice_dropship' THEN 0.00
          ELSE coalesce(b.written_off_amount, 0.00)
            * (bl.line_total / nullif(b.total_amount, 0.00))
        END
      )::numeric(18,4) AS amount_bdt
    FROM money_kernel.bill_lines bl
    JOIN money_kernel.bills b ON b.id = bl.bill_id
    LEFT JOIN public.global_stocks gs ON gs.id = bl.global_stock_id
    JOIN public.global_shipment_items gsi
      ON gsi.shipment_id = p_shipment_id
     AND gsi.id = coalesce(
       bl.shipment_item_id,
       nullif(bl.meta->'shipment_ref'->>'shipment_item_id', '')::bigint,
       gs.shipment_item_id,
       (
         SELECT gsi_fb.id
         FROM public.global_shipment_items gsi_fb
         WHERE gsi_fb.shipment_id = p_shipment_id
           AND gsi_fb.product_id IS NOT NULL
           AND gsi_fb.product_id = bl.product_id
         ORDER BY gsi_fb.id
         LIMIT 1
       )
     )
    WHERE gsi.shipment_id = p_shipment_id
      AND b.tenant_id = v_books_id
      AND b.status IN ('issued', 'partial', 'paid')
      AND b.kind IN (
        'sales_invoice_wholesale',
        'sales_invoice_retail',
        'sales_invoice_dropship'
      )
  )
  SELECT
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'bill_id', line_attr.bill_id,
          'invoice_no', line_attr.invoice_no,
          'invoice_item_id', line_attr.invoice_item_id,
          'product_name', line_attr.product_name,
          'qty', line_attr.qty,
          'amount_bdt', line_attr.amount_bdt
        )
        ORDER BY line_attr.invoice_no, line_attr.invoice_item_id
      ),
      '[]'::jsonb
    ),
    coalesce(sum(line_attr.amount_bdt), 0)
  INTO v_sell_lines, v_total_sell
  FROM line_attr
  WHERE line_attr.qty > 0;

  WITH shipment_sale_bills AS (
    SELECT DISTINCT ON (b.id)
      b.id AS bill_id,
      b.invoice_no,
      coalesce(p.name, 'Customer') AS customer_name,
      public._desk_kernel_status_payment(b.status, b.due_amount) AS payment_status,
      coalesce(
        (public._desk_kernel_net_balances_json(b.id) ->> 'open_books')::numeric(18,4),
        b.due_amount,
        0
      ) AS open_bdt
    FROM money_kernel.bill_lines bl
    JOIN money_kernel.bills b ON b.id = bl.bill_id
    LEFT JOIN public.global_stocks gs ON gs.id = bl.global_stock_id
    JOIN public.global_shipment_items gsi
      ON gsi.shipment_id = p_shipment_id
     AND gsi.id = coalesce(
       bl.shipment_item_id,
       nullif(bl.meta->'shipment_ref'->>'shipment_item_id', '')::bigint,
       gs.shipment_item_id,
       (
         SELECT gsi_fb.id
         FROM public.global_shipment_items gsi_fb
         WHERE gsi_fb.shipment_id = p_shipment_id
           AND gsi_fb.product_id IS NOT NULL
           AND gsi_fb.product_id = bl.product_id
         ORDER BY gsi_fb.id
         LIMIT 1
       )
     )
    LEFT JOIN public.profiles p ON p.id = b.from_profile_id
    WHERE gsi.shipment_id = p_shipment_id
      AND b.tenant_id = v_books_id
      AND b.status IN ('issued', 'partial', 'paid')
      AND b.kind IN (
        'sales_invoice_wholesale',
        'sales_invoice_retail',
        'sales_invoice_dropship'
      )
      AND bl.quantity > 0
    ORDER BY b.id, b.invoice_no
  )
  SELECT
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'bill_id', shipment_sale_bills.bill_id,
          'invoice_no', shipment_sale_bills.invoice_no,
          'customer_name', shipment_sale_bills.customer_name,
          'payment_status', shipment_sale_bills.payment_status,
          'open_bdt', shipment_sale_bills.open_bdt
        )
        ORDER BY shipment_sale_bills.invoice_no
      ),
      '[]'::jsonb
    ),
    coalesce(sum(shipment_sale_bills.open_bdt) FILTER (WHERE shipment_sale_bills.open_bdt > 0.009), 0)
  INTO v_unpaid_customers, v_unpaid_total_bdt
  FROM shipment_sale_bills
  WHERE shipment_sale_bills.open_bdt > 0.009;

  SELECT coalesce(sum((elem ->> 'bdt_amount')::numeric(18,4)), 0)
  INTO v_total_cost_bdt
  FROM jsonb_array_elements(coalesce(v_cost_buckets, '[]'::jsonb)) AS elem;

  WITH shipment_ap AS (
    SELECT
      coalesce(
        nullif(btrim(b.meta->>'txn_currency_code'), ''),
        nullif(btrim(b.currency_code), ''),
        'BDT'
      ) AS txn_ccy,
      coalesce((b.meta->>'txn_total_amount')::numeric(18, 4), b.total_amount) AS txn_total
    FROM money_kernel.bills b
    WHERE b.tenant_id = v_books_id
      AND b.status <> 'voided'
      AND b.kind = 'shipment_cost_ap'
      AND (
        (b.source_type = 'shipment_cost' AND b.source_id = p_shipment_id::text)
        OR (b.meta->>'shipment_id')::bigint = p_shipment_id
      )
  ),
  by_ccy AS (
    SELECT
      txn_ccy AS currency_code,
      coalesce(sum(txn_total), 0)::numeric(18,4) AS amount
    FROM shipment_ap
    WHERE upper(txn_ccy) <> 'BDT'
    GROUP BY txn_ccy
  )
  SELECT jsonb_build_object(
    'total_cost_bdt', coalesce(v_total_cost_bdt, 0),
    'total_cost_by_currency', coalesce(
      (SELECT jsonb_agg(
        jsonb_build_object('currency_code', currency_code, 'amount', amount)
        ORDER BY currency_code
      ) FROM by_ccy),
      '[]'::jsonb
    ),
    'total_sell_bdt', coalesce(v_total_sell, 0),
    'receive_loss_bdt', coalesce(v_receive_loss_bdt, 0),
    'unpaid_total_bdt', coalesce(v_unpaid_total_bdt, 0),
    'profit_loss_bdt', coalesce(v_total_sell, 0) - coalesce(v_total_cost_bdt, 0),
    'profit_loss_pct', CASE
      WHEN coalesce(v_total_sell, 0) > 0
      THEN round(
        ((coalesce(v_total_sell, 0) - coalesce(v_total_cost_bdt, 0)) / v_total_sell * 100)::numeric,
        2
      )
      ELSE 0::numeric
    END
  )
  INTO v_profit_matrix;

  RETURN jsonb_build_object(
    'header', coalesce(v_header, '{}'::jsonb),
    'pnl', v_pnl,
    'ap_bills', coalesce(v_ap_bills, '[]'::jsonb),
    'ap_totals_by_currency', coalesce(v_ap_totals, '[]'::jsonb),
    'customer_bills', coalesce(v_customer_bills, '[]'::jsonb),
    'customer_attributed_revenue_bdt', coalesce(v_customer_revenue, 0),
    'exchange_rates', coalesce(v_exchange_rates, '{}'::jsonb),
    'qty_summary', coalesce(v_qty_summary, '{}'::jsonb),
    'cost_buckets', coalesce(v_cost_buckets, '[]'::jsonb),
    'sell_lines', coalesce(v_sell_lines, '[]'::jsonb),
    'profit_matrix', coalesce(v_profit_matrix, '{}'::jsonb),
    'unpaid_customers', coalesce(v_unpaid_customers, '[]'::jsonb)
  );
END;
$function$;

COMMENT ON FUNCTION public.get_tenant_shipment_report_detail(bigint, bigint) IS 'Read-only shipment admin report: qty totals, cost buckets, sell lines, profit matrix, unpaid customers, AP bills, FX.';

GRANT ALL ON FUNCTION public.get_tenant_shipment_report_detail(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.get_tenant_shipment_report_detail(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_tenant_shipment_report_detail(bigint, bigint) TO service_role;
CREATE OR REPLACE FUNCTION public.get_shipment_pnl (
  p_tenant_id   bigint,
  p_shipment_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public', 'money_kernel'
  AS $function$
declare
  v_shipment jsonb;
  v_items jsonb;
  v_total_landed_cost numeric(12,2) := 0;
  v_total_sold_cost numeric(12,2) := 0;
  v_total_revenue numeric(12,2) := 0;
  v_total_gross_profit numeric(12,2) := 0;
  v_total_sellable_on_hand_value numeric(12,2) := 0;
  v_total_shrinkage_value numeric(12,2) := 0;
  v_total_stolen_value numeric(12,2) := 0;
  v_total_box_damage_value numeric(12,2) := 0;
  v_total_expired_value numeric(12,2) := 0;
  v_total_reconciliation_gap bigint := 0;
  v_disposition_available boolean := false;
begin
  -- Resolve parent tenant to enforce access
  if public.resolve_parent_tenant_id(p_tenant_id) <> (select tenant_id from public.global_shipments where id = p_shipment_id) then
    raise exception 'unauthorized tenant access to shipment';
  end if;

  -- 1. Get shipment header
  select row_to_json(s)::jsonb
  into v_shipment
  from public.global_shipments s
  where s.id = p_shipment_id;

  -- Check if disposition is available (i.e. global_stocks rows exist for shipment items)
  select exists (
    select 1
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gs.shipment_item_id = gsi.id
    where gsi.shipment_id = p_shipment_id
  ) into v_disposition_available;

  -- 2. Get shipment items details with on-the-fly margins and stock disposition
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_items
  from (
    select
      si.*,
      public.calculate_landed_unit_cost(si.id) as landed_unit_cost,
      coalesce(sum(bl.quantity), 0) as sold_qty,
      coalesce(public.calculate_landed_unit_cost(si.id), 0) * coalesce(sum(bl.quantity), 0) as sold_cost,
      coalesce(sum(
        bl.line_total
        - case
          when inv.kind = 'sales_invoice_dropship' then 0.00
          else coalesce(inv.written_off_amount, 0.00)
            * (bl.line_total / nullif(inv.total_amount, 0.00))
        end
      ), 0) as revenue,
      coalesce(disp.sellable_qty, 0) as sellable_qty,
      coalesce(disp.stolen_qty, 0) as stolen_qty,
      coalesce(disp.box_damage_qty, 0) as box_damage_qty,
      coalesce(disp.expired_qty, 0) as expired_qty,
      coalesce(disp.reserved_qty, 0) as reserved_qty,
      (coalesce(disp.sellable_qty, 0) * public.calculate_landed_unit_cost(si.id))::numeric(12,2) as sellable_value,
      ((coalesce(disp.stolen_qty, 0) + coalesce(disp.box_damage_qty, 0) + coalesce(disp.expired_qty, 0)) * public.calculate_landed_unit_cost(si.id))::numeric(12,2) as shrinkage_value,
      (coalesce(disp.stolen_qty, 0) * public.calculate_landed_unit_cost(si.id))::numeric(12,2) as stolen_value,
      (coalesce(disp.box_damage_qty, 0) * public.calculate_landed_unit_cost(si.id))::numeric(12,2) as box_damage_value,
      (coalesce(disp.expired_qty, 0) * public.calculate_landed_unit_cost(si.id))::numeric(12,2) as expired_value,
      (si.ordered_quantity - coalesce(sum(bl.quantity), 0) - coalesce(disp.sellable_qty, 0) - coalesce(disp.stolen_qty, 0) - coalesce(disp.box_damage_qty, 0) - coalesce(disp.expired_qty, 0) - coalesce(disp.reserved_qty, 0)) as reconciliation_gap
    from public.global_shipment_items si
    left join money_kernel.bill_lines bl
      on coalesce(
        bl.shipment_item_id,
        nullif(bl.meta->'shipment_ref'->>'shipment_item_id', '')::bigint
      ) = si.id
    left join money_kernel.bills inv
      on inv.id = bl.bill_id
     and inv.status in ('issued', 'partial', 'paid')
     and inv.kind in (
       'sales_invoice_wholesale',
       'sales_invoice_retail',
       'sales_invoice_dropship'
     )
    left join lateral (
      select
        coalesce(sum(gs.quantity) filter (where gst.is_sellable = true), 0) as sellable_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'stolen'), 0) as stolen_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'box damage'), 0) as box_damage_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'expired'), 0) as expired_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'reserved'), 0) as reserved_qty
      from public.global_stocks gs
      inner join public.global_stock_types gst on gst.id = gs.stock_type_id
      where gs.shipment_item_id = si.id
    ) disp on true
    where si.shipment_id = p_shipment_id
    group by si.id, disp.sellable_qty, disp.stolen_qty, disp.box_damage_qty, disp.expired_qty, disp.reserved_qty
  ) r;

  -- 3. Sum total metrics
  select
    coalesce(sum(landed_unit_cost * received_qty), 0),
    coalesce(sum(sold_cost), 0),
    coalesce(sum(revenue), 0),
    coalesce(sum(sellable_qty * landed_unit_cost), 0),
    coalesce(sum((stolen_qty + box_damage_qty + expired_qty) * landed_unit_cost), 0),
    coalesce(sum(stolen_qty * landed_unit_cost), 0),
    coalesce(sum(box_damage_qty * landed_unit_cost), 0),
    coalesce(sum(expired_qty * landed_unit_cost), 0),
    coalesce(sum(reconciliation_gap), 0)
  into
    v_total_landed_cost,
    v_total_sold_cost,
    v_total_revenue,
    v_total_sellable_on_hand_value,
    v_total_shrinkage_value,
    v_total_stolen_value,
    v_total_box_damage_value,
    v_total_expired_value,
    v_total_reconciliation_gap
  from (
    select
      public.calculate_landed_unit_cost(si.id) as landed_unit_cost,
      si.ordered_quantity as received_qty,
      coalesce(sum(bl.quantity), 0) as sold_qty,
      coalesce(public.calculate_landed_unit_cost(si.id), 0) * coalesce(sum(bl.quantity), 0) as sold_cost,
      coalesce(sum(
        bl.line_total
        - case
          when inv.kind = 'sales_invoice_dropship' then 0.00
          else coalesce(inv.written_off_amount, 0.00)
            * (bl.line_total / nullif(inv.total_amount, 0.00))
        end
      ), 0) as revenue,
      coalesce(disp.sellable_qty, 0) as sellable_qty,
      coalesce(disp.stolen_qty, 0) as stolen_qty,
      coalesce(disp.box_damage_qty, 0) as box_damage_qty,
      coalesce(disp.expired_qty, 0) as expired_qty,
      (si.ordered_quantity - coalesce(sum(bl.quantity), 0) - coalesce(disp.sellable_qty, 0) - coalesce(disp.stolen_qty, 0) - coalesce(disp.box_damage_qty, 0) - coalesce(disp.expired_qty, 0) - coalesce(disp.reserved_qty, 0)) as reconciliation_gap
    from public.global_shipment_items si
    left join money_kernel.bill_lines bl
      on coalesce(
        bl.shipment_item_id,
        nullif(bl.meta->'shipment_ref'->>'shipment_item_id', '')::bigint
      ) = si.id
    left join money_kernel.bills inv
      on inv.id = bl.bill_id
     and inv.status in ('issued', 'partial', 'paid')
     and inv.kind in (
       'sales_invoice_wholesale',
       'sales_invoice_retail',
       'sales_invoice_dropship'
     )
    left join lateral (
      select
        coalesce(sum(gs.quantity) filter (where gst.is_sellable = true), 0) as sellable_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'stolen'), 0) as stolen_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'box damage'), 0) as box_damage_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'expired'), 0) as expired_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'reserved'), 0) as reserved_qty
      from public.global_stocks gs
      inner join public.global_stock_types gst on gst.id = gs.stock_type_id
      where gs.shipment_item_id = si.id
    ) disp on true
    where si.shipment_id = p_shipment_id
    group by si.id, disp.sellable_qty, disp.stolen_qty, disp.box_damage_qty, disp.expired_qty, disp.reserved_qty
  ) rollup;

  v_total_gross_profit := v_total_revenue - v_total_sold_cost;

  return jsonb_build_object(
    'shipment', v_shipment,
    'items', v_items,
    'totals', jsonb_build_object(
      'landed_cost', v_total_landed_cost,
      'sold_cost', v_total_sold_cost,
      'revenue', v_total_revenue,
      'gross_profit', v_total_gross_profit,
      'sellable_on_hand_value', v_total_sellable_on_hand_value,
      'shrinkage_value', v_total_shrinkage_value,
      'stolen_value', v_total_stolen_value,
      'box_damage_value', v_total_box_damage_value,
      'expired_value', v_total_expired_value,
      'unsold_value', v_total_sellable_on_hand_value, -- alias for backward compat
      'disposition_available', v_disposition_available,
      'reconciliation_gap', v_total_reconciliation_gap
    )
  );
end;
$function$;

GRANT ALL ON FUNCTION public.get_shipment_pnl(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.get_shipment_pnl(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_shipment_pnl(bigint, bigint) TO service_role;CREATE OR REPLACE FUNCTION public.list_global_invoice_items(p_invoice_id bigint)
RETURNS TABLE(
  id bigint,
  invoice_id bigint,
  global_stock_id bigint,
  name_snapshot text,
  quantity numeric,
  sell_price_amount numeric,
  recipient_price_amount numeric,
  line_face_total_amount numeric,
  line_discount_amount numeric,
  line_total_amount numeric,
  return_quantity numeric,
  image_url text,
  shipment_id bigint,
  shipment_item_id bigint,
  purchase_price numeric,
  product_weight numeric,
  package_weight numeric,
  ordered_quantity integer,
  shipment_type text,
  product_conversion_rate numeric,
  cargo_conversion_rate numeric,
  cargo_rate numeric,
  received_weight numeric,
  transaction_rate numeric,
  available_atp numeric,
  unit_cost_price numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public, money_kernel
AS $$
DECLARE
  v_books_tenant_id bigint;
  v_status text;
BEGIN
  SELECT kb.tenant_id, kb.status
  INTO v_books_tenant_id, v_status
  FROM money_kernel.bills kb
  WHERE kb.id = p_invoice_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invoice with ID % not found', p_invoice_id;
  END IF;

  IF NOT (
    public.user_can_manage_books_tenant(v_books_tenant_id)
    OR public.membership_has_module_action(v_books_tenant_id, 'global_invoice', 'view')
  ) THEN
    RAISE EXCEPTION 'Access denied for invoice with ID %', p_invoice_id;
  END IF;

  RETURN QUERY
  SELECT
    bl.id,
    bl.bill_id AS invoice_id,
    bl.global_stock_id,
    bl.description AS name_snapshot,
    bl.quantity,
    bl.unit_price AS sell_price_amount,
    nullif(bl.meta->>'resell_price_amount', '')::numeric AS recipient_price_amount,
    (bl.quantity * nullif(bl.meta->>'resell_price_amount', '')::numeric) AS line_face_total_amount,
    0::numeric AS line_discount_amount,
    bl.line_total AS line_total_amount,
    0::numeric AS return_quantity,
    CASE
      WHEN bl.item_kind = 'stock' THEN coalesce(gsi.image_url, p.image_url)
      ELSE NULL::text
    END AS image_url,
    coalesce(bl.shipment_id, gsi.shipment_id) AS shipment_id,
    coalesce(bl.shipment_item_id, gsi.id) AS shipment_item_id,
    gsi.purchase_price,
    gsi.product_weight,
    gsi.package_weight,
    gsi.ordered_quantity,
    gship.type::text AS shipment_type,
    NULL::numeric AS product_conversion_rate,
    NULL::numeric AS cargo_conversion_rate,
    NULL::numeric AS cargo_rate,
    gship.received_weight,
    NULL::numeric AS transaction_rate,
    CASE
      WHEN bl.global_stock_id IS NULL THEN 0::numeric
      WHEN v_status = 'draft'
        THEN (
          coalesce(public.global_stock_atp_qty(bl.global_stock_id), gs.quantity, 0) + bl.quantity
        )::numeric
      ELSE (coalesce(public.global_stock_atp_qty(bl.global_stock_id), gs.quantity, 0))::numeric
    END AS available_atp,
    coalesce(gsi.landed_cost_bdt, gsi.purchase_price, 0)::numeric AS unit_cost_price
  FROM money_kernel.bill_lines bl
  LEFT JOIN public.global_stocks gs ON gs.id = bl.global_stock_id
  LEFT JOIN public.global_shipment_items gsi
    ON gsi.id = coalesce(
      bl.shipment_item_id,
      nullif(bl.meta->'shipment_ref'->>'shipment_item_id', '')::bigint,
      gs.shipment_item_id
    )
  LEFT JOIN public.global_shipments gship ON gship.id = coalesce(bl.shipment_id, gsi.shipment_id)
  LEFT JOIN public.products p ON p.id = bl.product_id
  WHERE bl.bill_id = p_invoice_id
    AND bl.item_kind IN ('stock', 'charge')
  ORDER BY bl.line_no, bl.id;
END;
$$;
