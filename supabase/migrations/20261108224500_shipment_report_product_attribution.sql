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
  SET search_path TO 'public'
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
        coalesce(sum(gii.quantity), 0) AS sold_qty,
        coalesce(sum(gii.return_quantity), 0) AS returned_qty,
        coalesce(sum(gii.quantity - gii.return_quantity), 0) AS net_sold_qty,
        coalesce(sum(
          gii.sell_price_amount * (gii.quantity - coalesce(gii.return_quantity, 0))
          - coalesce(gii.line_discount_amount, 0) * (greatest(gii.quantity - gii.return_quantity, 0) / nullif(gii.quantity, 0))
          - CASE
            WHEN si.invoice_type = 'dropship'::public.global_invoice_type THEN 0.00
            ELSE (coalesce(si.discount_amount, 0.00) + coalesce(si.written_off_amount, 0.00))
              * (gii.line_total_amount / nullif(invagg.inv_line_subtotal, 0.00))
          END
        ), 0) AS sold_revenue,
        coalesce(sum((gii.quantity - gii.return_quantity) * coalesce(gsi.landed_cost_bdt, 0)), 0) AS cogs
      FROM public.global_invoice_items gii
      JOIN public.bills si ON si.id = gii.invoice_id
      LEFT JOIN public.global_stocks gs ON gs.id = gii.global_stock_id
      LEFT JOIN LATERAL (
        SELECT coalesce(sum(x.line_total_amount), 0.00) AS inv_line_subtotal
        FROM public.global_invoice_items x
        WHERE x.invoice_id = gii.invoice_id
      ) invagg ON true
      WHERE gsi.id = coalesce(
          gii.shipment_item_id,
          gs.shipment_item_id,
          (
            SELECT gsi_fb.id
            FROM public.global_shipment_items gsi_fb
            WHERE gsi_fb.shipment_id = gsi.shipment_id
              AND gsi_fb.product_id IS NOT NULL
              AND gsi_fb.product_id = gii.product_id
            ORDER BY gsi_fb.id
            LIMIT 1
          )
        )
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
  SET search_path TO 'public'
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
          nullif(btrim(b.ap_kind), ''),
          nullif(btrim(b.channel_meta->>'ap_kind'), ''),
          nullif(split_part(coalesce(b.source_key, ''), ':', 1), '')
        ),
        'invoice_status', b.invoice_status,
        'payment_status', b.payment_status,
        'currency_code', b.currency_code,
        'txn_currency_code', coalesce(nullif(btrim(b.txn_currency_code), ''), b.currency_code),
        'txn_total_amount', coalesce(b.txn_total_amount, b.total_amount),
        'books_exchange_rate', b.books_exchange_rate,
        'total_amount', b.total_amount,
        'due_amount', b.due_amount,
        'open_books', coalesce((public.get_bill_net_balances(b.id)->>'open_books')::numeric, b.due_amount)
      )
      ORDER BY b.id
    ),
    '[]'::jsonb
  )
  INTO v_ap_bills
  FROM public.bills b
  WHERE b.tenant_id = v_books_id
    AND b.invoice_status <> 'voided'::public.global_invoice_status
    AND b.invoice_type = 'ap'::public.global_invoice_type
    AND b.document_kind = 'standard'::public.bill_document_kind
    AND (
      (b.source_type = 'shipment_cost' AND b.source_id = p_shipment_id::text)
      OR b.ap_shipment_id = p_shipment_id
    )
    AND (
      b.ap_shipment_id = p_shipment_id
      OR coalesce(
        nullif(btrim(b.ap_kind), ''),
        nullif(btrim(b.channel_meta->>'ap_kind'), ''),
        nullif(btrim(b.source_key), ''),
        split_part(coalesce(b.source_key, ''), ':', 1)
      ) IN (
        'material', 'freight', 'customs', 'handling', 'finance', 'other',
        'vendor', 'cargo', 'local'
      )
      OR coalesce(b.source_key, '') ~ '^(material|freight|customs|handling|finance|other|vendor|cargo|local):'
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
      coalesce(nullif(btrim(b.txn_currency_code), ''), nullif(btrim(b.currency_code), ''), 'BDT') AS currency_code,
      count(*)::int AS bill_count,
      coalesce(sum(coalesce(b.txn_total_amount, b.total_amount)), 0)::numeric(18,4) AS txn_total_amount,
      coalesce(sum(b.total_amount), 0)::numeric(18,4) AS books_total_amount
    FROM public.bills b
    WHERE b.tenant_id = v_books_id
      AND b.invoice_status <> 'voided'::public.global_invoice_status
      AND b.invoice_type = 'ap'::public.global_invoice_type
      AND b.document_kind = 'standard'::public.bill_document_kind
      AND (
        (b.source_type = 'shipment_cost' AND b.source_id = p_shipment_id::text)
        OR b.ap_shipment_id = p_shipment_id
      )
      AND (
        b.ap_shipment_id = p_shipment_id
        OR coalesce(
          nullif(btrim(b.ap_kind), ''),
          nullif(btrim(b.channel_meta->>'ap_kind'), ''),
          nullif(btrim(b.source_key), ''),
          split_part(coalesce(b.source_key, ''), ':', 1)
        ) IN (
          'material', 'freight', 'customs', 'handling', 'finance', 'other',
          'vendor', 'cargo', 'local'
        )
        OR coalesce(b.source_key, '') ~ '^(material|freight|customs|handling|finance|other|vendor|cargo|local):'
      )
    GROUP BY 1
  ) g;

  WITH bill_attr AS (
    SELECT
      b.id AS bill_id,
      b.invoice_no,
      b.invoice_date,
      b.invoice_type,
      b.currency_code,
      b.profile_id,
      coalesce(p.name, b.recipient_name, 'Customer') AS customer_name,
      coalesce(sum(
        gii.sell_price_amount * (gii.quantity - coalesce(gii.return_quantity, 0))
        - coalesce(gii.line_discount_amount, 0) * (
          greatest(gii.quantity - coalesce(gii.return_quantity, 0), 0)::numeric
          / nullif(gii.quantity, 0)
        )
        - CASE
          WHEN b.invoice_type = 'dropship'::public.global_invoice_type THEN 0.00
          ELSE (coalesce(b.discount_amount, 0.00) + coalesce(b.written_off_amount, 0.00))
            * (gii.line_total_amount / nullif(invagg.inv_line_subtotal, 0.00))
        END
      ), 0)::numeric(18,4) AS attributed_revenue_bdt,
      coalesce(sum(gii.quantity - coalesce(gii.return_quantity, 0)), 0)::int AS attributed_qty
    FROM public.global_invoice_items gii
    JOIN public.bills b ON b.id = gii.invoice_id
    LEFT JOIN public.global_stocks gs ON gs.id = gii.global_stock_id
    JOIN public.global_shipment_items gsi
      ON gsi.shipment_id = p_shipment_id
     AND gsi.id = coalesce(
       gii.shipment_item_id,
       gs.shipment_item_id,
       (
         SELECT gsi_fb.id
         FROM public.global_shipment_items gsi_fb
         WHERE gsi_fb.shipment_id = p_shipment_id
           AND gsi_fb.product_id IS NOT NULL
           AND gsi_fb.product_id = gii.product_id
         ORDER BY gsi_fb.id
         LIMIT 1
       )
     )
    LEFT JOIN public.profiles p ON p.id = b.profile_id
    LEFT JOIN LATERAL (
      SELECT coalesce(sum(x.line_total_amount), 0.00) AS inv_line_subtotal
      FROM public.global_invoice_items x
      WHERE x.invoice_id = b.id
    ) invagg ON true
    WHERE gsi.shipment_id = p_shipment_id
      AND b.tenant_id = v_books_id
      AND b.invoice_status = 'issued'::public.global_invoice_status
      AND b.invoice_type <> 'ap'::public.global_invoice_type
    GROUP BY
      b.id, b.invoice_no, b.invoice_date, b.invoice_type, b.currency_code, b.profile_id, p.name, b.recipient_name
    HAVING coalesce(sum(gii.quantity - coalesce(gii.return_quantity, 0)), 0) > 0
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
      coalesce(b.txn_total_amount, b.total_amount) AS txn_total,
      coalesce(nullif(btrim(b.txn_currency_code), ''), nullif(btrim(b.currency_code), ''), 'BDT') AS txn_ccy,
      coalesce(
        nullif(btrim(b.ap_kind), ''),
        nullif(btrim(b.channel_meta->>'ap_kind'), ''),
        nullif(split_part(coalesce(b.source_key, ''), ':', 1), ''),
        'other'
      ) AS ap_kind
    FROM public.bills b
    WHERE b.tenant_id = v_books_id
      AND b.invoice_status <> 'voided'::public.global_invoice_status
      AND b.invoice_type = 'ap'::public.global_invoice_type
      AND b.document_kind = 'standard'::public.bill_document_kind
      AND (
        (b.source_type = 'shipment_cost' AND b.source_id = p_shipment_id::text)
        OR b.ap_shipment_id = p_shipment_id
      )
      AND (
        b.ap_shipment_id = p_shipment_id
        OR coalesce(
          nullif(btrim(b.ap_kind), ''),
          nullif(btrim(b.channel_meta->>'ap_kind'), ''),
          nullif(btrim(b.source_key), ''),
          split_part(coalesce(b.source_key, ''), ':', 1)
        ) IN (
          'material', 'freight', 'customs', 'handling', 'finance', 'other',
          'vendor', 'cargo', 'local'
        )
        OR coalesce(b.source_key, '') ~ '^(material|freight|customs|handling|finance|other|vendor|cargo|local):'
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
      gii.id AS invoice_item_id,
      coalesce(nullif(btrim(gsi.name), ''), nullif(btrim(gii.name_snapshot), ''), 'Item') AS product_name,
      greatest(gii.quantity - coalesce(gii.return_quantity, 0), 0)::int AS qty,
      (
        gii.sell_price_amount * (gii.quantity - coalesce(gii.return_quantity, 0))
        - coalesce(gii.line_discount_amount, 0) * (
          greatest(gii.quantity - coalesce(gii.return_quantity, 0), 0)::numeric
          / nullif(gii.quantity, 0)
        )
        - CASE
          WHEN b.invoice_type = 'dropship'::public.global_invoice_type THEN 0.00
          ELSE (coalesce(b.discount_amount, 0.00) + coalesce(b.written_off_amount, 0.00))
            * (gii.line_total_amount / nullif(invagg.inv_line_subtotal, 0.00))
        END
      )::numeric(18,4) AS amount_bdt
    FROM public.global_invoice_items gii
    JOIN public.bills b ON b.id = gii.invoice_id
    LEFT JOIN public.global_stocks gs ON gs.id = gii.global_stock_id
    JOIN public.global_shipment_items gsi
      ON gsi.shipment_id = p_shipment_id
     AND gsi.id = coalesce(
       gii.shipment_item_id,
       gs.shipment_item_id,
       (
         SELECT gsi_fb.id
         FROM public.global_shipment_items gsi_fb
         WHERE gsi_fb.shipment_id = p_shipment_id
           AND gsi_fb.product_id IS NOT NULL
           AND gsi_fb.product_id = gii.product_id
         ORDER BY gsi_fb.id
         LIMIT 1
       )
     )
    LEFT JOIN LATERAL (
      SELECT coalesce(sum(x.line_total_amount), 0.00) AS inv_line_subtotal
      FROM public.global_invoice_items x
      WHERE x.invoice_id = b.id
    ) invagg ON true
    WHERE gsi.shipment_id = p_shipment_id
      AND b.tenant_id = v_books_id
      AND b.invoice_status = 'issued'::public.global_invoice_status
      AND b.invoice_type <> 'ap'::public.global_invoice_type
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
      coalesce(p.name, b.recipient_name, 'Customer') AS customer_name,
      b.payment_status,
      coalesce(
        (public.get_bill_net_balances(b.id) ->> 'open_books')::numeric(18,4),
        b.due_amount,
        0
      ) AS open_bdt
    FROM public.global_invoice_items gii
    JOIN public.bills b ON b.id = gii.invoice_id
    LEFT JOIN public.global_stocks gs ON gs.id = gii.global_stock_id
    JOIN public.global_shipment_items gsi
      ON gsi.shipment_id = p_shipment_id
     AND gsi.id = coalesce(
       gii.shipment_item_id,
       gs.shipment_item_id,
       (
         SELECT gsi_fb.id
         FROM public.global_shipment_items gsi_fb
         WHERE gsi_fb.shipment_id = p_shipment_id
           AND gsi_fb.product_id IS NOT NULL
           AND gsi_fb.product_id = gii.product_id
         ORDER BY gsi_fb.id
         LIMIT 1
       )
     )
    LEFT JOIN public.profiles p ON p.id = b.profile_id
    WHERE gsi.shipment_id = p_shipment_id
      AND b.tenant_id = v_books_id
      AND b.invoice_status = 'issued'::public.global_invoice_status
      AND b.invoice_type <> 'ap'::public.global_invoice_type
      AND greatest(gii.quantity - coalesce(gii.return_quantity, 0), 0) > 0
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
      coalesce(nullif(btrim(b.txn_currency_code), ''), nullif(btrim(b.currency_code), ''), 'BDT') AS txn_ccy,
      coalesce(b.txn_total_amount, b.total_amount) AS txn_total
    FROM public.bills b
    WHERE b.tenant_id = v_books_id
      AND b.invoice_status <> 'voided'::public.global_invoice_status
      AND b.invoice_type = 'ap'::public.global_invoice_type
      AND b.document_kind = 'standard'::public.bill_document_kind
      AND (
        (b.source_type = 'shipment_cost' AND b.source_id = p_shipment_id::text)
        OR b.ap_shipment_id = p_shipment_id
      )
      AND (
        b.ap_shipment_id = p_shipment_id
        OR coalesce(
          nullif(btrim(b.ap_kind), ''),
          nullif(btrim(b.channel_meta->>'ap_kind'), ''),
          nullif(btrim(b.source_key), ''),
          split_part(coalesce(b.source_key, ''), ':', 1)
        ) IN (
          'material', 'freight', 'customs', 'handling', 'finance', 'other',
          'vendor', 'cargo', 'local'
        )
        OR coalesce(b.source_key, '') ~ '^(material|freight|customs|handling|finance|other|vendor|cargo|local):'
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
