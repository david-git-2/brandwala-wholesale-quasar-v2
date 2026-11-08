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

  RETURN jsonb_build_object(
    'header', coalesce(v_header, '{}'::jsonb),
    'pnl', v_pnl,
    'ap_bills', coalesce(v_ap_bills, '[]'::jsonb),
    'ap_totals_by_currency', coalesce(v_ap_totals, '[]'::jsonb),
    'customer_bills', coalesce(v_customer_bills, '[]'::jsonb),
    'customer_attributed_revenue_bdt', coalesce(v_customer_revenue, 0)
  );
END;
$function$;

COMMENT ON FUNCTION public.get_tenant_shipment_report_detail(bigint, bigint) IS 'Read-only shipment report detail: P&L, quantities, AP bills by currency, attributed customer sales.';

GRANT ALL ON FUNCTION public.get_tenant_shipment_report_detail(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.get_tenant_shipment_report_detail(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_tenant_shipment_report_detail(bigint, bigint) TO service_role;
