CREATE OR REPLACE FUNCTION public.get_tenant_shipment_report_detail (
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
  v_items jsonb;
  v_qty_summary jsonb;
  v_cost_buckets jsonb;
  v_sell_lines jsonb;
  v_profit_matrix jsonb;
  v_total_sell numeric(18,4) := 0;
  v_total_cost_bdt numeric(18,4) := 0;
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
    FROM public.global_shipment_items gsi
    JOIN public.global_invoice_items gii ON gii.shipment_item_id = gsi.id
    JOIN public.bills b ON b.id = gii.invoice_id
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

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'item_id', gsi.id,
        'product_name', coalesce(gsi.name, 'Item #' || gsi.id),
        'ordered_qty', gsi.ordered_quantity,
        'go_to_stock_qty', coalesce(
          oc.go_to_stock,
          greatest(gsi.ordered_quantity - coalesce(oc.lost_qty, 0), 0)
        )::int,
        'lost_at_receive_qty', coalesce(oc.lost_qty, 0)::int
      )
      ORDER BY gsi.id
    ),
    '[]'::jsonb
  )
  INTO v_items
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
    'sold', coalesce((v_pnl ->> 'net_sold_quantity')::int, 0)
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
    FROM public.global_shipment_items gsi
    JOIN public.global_invoice_items gii ON gii.shipment_item_id = gsi.id
    JOIN public.bills b ON b.id = gii.invoice_id
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
    'items', coalesce(v_items, '[]'::jsonb),
    'qty_summary', coalesce(v_qty_summary, '{}'::jsonb),
    'cost_buckets', coalesce(v_cost_buckets, '[]'::jsonb),
    'sell_lines', coalesce(v_sell_lines, '[]'::jsonb),
    'profit_matrix', coalesce(v_profit_matrix, '{}'::jsonb)
  );
END;
$function$;

COMMENT ON FUNCTION public.get_tenant_shipment_report_detail(bigint, bigint) IS 'Read-only shipment report detail: WTS layout (items, qty, cost buckets, sell lines, profit matrix), AP bills, FX.';

GRANT ALL ON FUNCTION public.get_tenant_shipment_report_detail(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.get_tenant_shipment_report_detail(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_tenant_shipment_report_detail(bigint, bigint) TO service_role;
