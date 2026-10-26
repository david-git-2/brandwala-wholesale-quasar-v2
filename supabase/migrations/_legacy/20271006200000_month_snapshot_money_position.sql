CREATE OR REPLACE FUNCTION "public"."get_tenant_month_snapshot_report"("p_tenant_id" bigint, "p_month" "date") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_start date;
  v_end date;
  v_start_ts timestamptz;
  v_end_ts timestamptz;
  v_net_sales numeric(18,4) := 0;
  v_cogs numeric(18,4) := 0;
  v_gross_profit numeric(18,4) := 0;
  v_cash_collected numeric(18,4) := 0;
  v_ar_outstanding numeric(18,4) := 0;
  v_merchant_payable numeric(18,4) := 0;
  v_tenant_cash numeric(18,4) := 0;
  v_ledger_cash numeric(18,4);
  v_courier_holding numeric(18,4) := 0;
  v_cod_unremitted numeric(18,4) := 0;
  v_ap_payable numeric(18,4) := 0;
  v_customer_store_credit numeric(18,4) := 0;
  v_merchant_leftover numeric(18,4) := 0;
  v_net_buffer numeric(18,4) := 0;
  v_sales_by_invoice_type jsonb := '{}'::jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_month IS NULL THEN
    RAISE EXCEPTION 'Tenant ID and month are required';
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_start := date_trunc('month', p_month)::date;
  v_end := (date_trunc('month', p_month) + interval '1 month' - interval '1 day')::date;
  v_start_ts := v_start::timestamptz;
  v_end_ts := (v_end + interval '1 day' - interval '1 microsecond');

  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN RAISE EXCEPTION 'Not authorized'; END IF;

  WITH invoice_returned AS (
    SELECT sii.invoice_id, coalesce(sum(sii.return_quantity * sii.sell_price_amount), 0)::numeric(12,2) AS returned
    FROM public.bill_lines sii GROUP BY sii.invoice_id
  ),
  month_invoices AS (
    SELECT si.id, si.invoice_type::text AS invoice_type, si.total_amount, coalesce(ir.returned, 0) AS returned
    FROM public.bills si
    LEFT JOIN invoice_returned ir ON ir.invoice_id = si.id
    WHERE si.parent_tenant_id = v_books_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.invoice_date BETWEEN v_start AND v_end
  ),
  line_metrics AS (
    SELECT
      round(coalesce(sum(
        greatest(sii.quantity - sii.return_quantity, 0) * sii.sell_price_amount
        - coalesce(sii.line_discount_amount, 0) * (greatest(sii.quantity - sii.return_quantity, 0) / nullif(sii.quantity, 0))
      ), 0), 2) AS net_revenue,
      0::numeric AS cogs
    FROM public.bill_lines sii
    JOIN public.bills si ON si.id = sii.invoice_id
    WHERE si.parent_tenant_id = v_books_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.invoice_date BETWEEN v_start AND v_end
  ),
  sales_by_type AS (
    SELECT invoice_type, round(coalesce(sum(total_amount), 0), 2) AS sales
    FROM month_invoices
    GROUP BY invoice_type
  )
  SELECT
    round(coalesce((SELECT sum(total_amount) FROM month_invoices), 0), 2),
    round(coalesce((SELECT cogs FROM line_metrics), 0), 2),
    coalesce((SELECT jsonb_object_agg(invoice_type, sales) FROM sales_by_type), '{}'::jsonb)
  INTO v_net_sales, v_cogs, v_sales_by_invoice_type;

  v_gross_profit := round(v_net_sales - v_cogs, 2);

  SELECT round(coalesce(sum(gp.amount), 0), 2)
  INTO v_cash_collected
  FROM public.pays gp
  WHERE gp.tenant_id = v_books_id
    AND gp.voided_at IS NULL
    AND coalesce(gp.method::text, '') <> 'wallet_credit'
    AND coalesce(gp.payment_date::timestamptz, gp.created_at) BETWEEN v_start_ts AND v_end_ts;

  SELECT round(coalesce(sum(si.due_amount), 0), 2)
  INTO v_ar_outstanding
  FROM public.bills si
  WHERE si.parent_tenant_id = v_books_id
    AND si.invoice_status = 'issued'::public.global_invoice_status
    AND si.invoice_type <> 'ap'::public.global_invoice_type
    AND si.profile_id IS NOT NULL
    AND si.due_amount > 0;

  SELECT round(
    coalesce(sum(CASE WHEN entity_type IN ('customer', 'middleman') THEN pending_balance ELSE 0 END), 0)
    + coalesce(sum(CASE WHEN entity_type IN ('customer', 'middleman') THEN available_balance ELSE 0 END), 0),
    2
  )
  INTO v_merchant_payable
  FROM public.cashbook_accounts
  WHERE parent_tenant_id = v_books_id;

  SELECT coalesce(w.available_balance, 0.0000)
  INTO v_tenant_cash
  FROM public.cashbook_accounts w
  WHERE w.parent_tenant_id = v_books_id
    AND w.entity_type = 'tenant'
    AND w.entity_id = v_books_id
    AND w.currency_code = 'BDT'
  LIMIT 1;

  SELECT l.balance_after
  INTO v_ledger_cash
  FROM public.cashbook_entries l
  WHERE l.parent_tenant_id = v_books_id
    AND l.entity_type = 'tenant'
    AND l.entity_id = v_books_id
    AND coalesce(l.currency_code, 'BDT') = 'BDT'
  ORDER BY l.id DESC
  LIMIT 1;

  IF coalesce(v_tenant_cash, 0) = 0 AND coalesce(v_ledger_cash, 0) <> 0 THEN
    v_tenant_cash := v_ledger_cash;
  END IF;

  SELECT round(coalesce(sum(pending_balance + available_balance), 0), 2)
  INTO v_courier_holding
  FROM public.cashbook_accounts
  WHERE parent_tenant_id = v_books_id
    AND entity_type = 'courier';

  WITH delivered_orders AS (
    SELECT
      coalesce(so.cod_collect_amount, 0)::numeric(12,2) AS cod_collect_amount,
      round(coalesce((
        SELECT l.amount
        FROM public.cashbook_entries l
        WHERE l.parent_tenant_id = v_books_id
          AND l.entity_type = 'tenant'
          AND l.source_type = 'shop_order'
          AND l.source_id = so.id::text
          AND coalesce(l.metadata->>'purpose', '') = 'tenant_remittance_received'
        LIMIT 1
      ), 0), 2) AS remitted_amount
    FROM public.shop_orders so
    WHERE public.resolve_parent_tenant_id(so.tenant_id) = v_books_id
      AND so.status IN ('delivered'::public.shop_order_status, 'payment_received'::public.shop_order_status)
      AND so.shop_type_snapshot = 'dropship'::public.shop_type_enum
      AND coalesce(so.cod_collect_amount, 0) > 0
  )
  SELECT round(coalesce(sum(greatest(cod_collect_amount - remitted_amount, 0)), 0), 2)
  INTO v_cod_unremitted
  FROM delivered_orders;

  SELECT round(coalesce(sum(si.due_amount), 0), 2)
  INTO v_ap_payable
  FROM public.bills si
  WHERE si.parent_tenant_id = v_books_id
    AND si.invoice_type = 'ap'::public.global_invoice_type
    AND si.invoice_status = 'issued'::public.global_invoice_status
    AND si.due_amount > 0;

  SELECT
    round(coalesce(sum(CASE WHEN entity_type = 'customer' THEN available_balance ELSE 0 END), 0), 2),
    round(coalesce(sum(CASE WHEN entity_type = 'middleman' THEN pending_balance + available_balance ELSE 0 END), 0), 2)
  INTO v_customer_store_credit, v_merchant_leftover
  FROM public.cashbook_accounts
  WHERE parent_tenant_id = v_books_id;

  v_net_buffer := round(
    coalesce(v_tenant_cash, 0)
    + coalesce(v_courier_holding, 0)
    + coalesce(v_ar_outstanding, 0)
    + coalesce(v_cod_unremitted, 0)
    - coalesce(v_ap_payable, 0)
    - coalesce(v_merchant_leftover, 0)
    - coalesce(v_customer_store_credit, 0),
    2
  );

  RETURN jsonb_build_object(
    'tenant_id', v_books_id,
    'month', v_start,
    'start_date', v_start,
    'end_date', v_end,
    'sales_by_invoice_type', v_sales_by_invoice_type,
    'kpis', jsonb_build_object(
      'net_sales', v_net_sales,
      'cogs', v_cogs,
      'gross_profit', v_gross_profit,
      'cash_collected', v_cash_collected,
      'ar_outstanding', v_ar_outstanding,
      'merchant_payable', v_merchant_payable
    ),
    'position', jsonb_build_object(
      'tenant_cash', round(coalesce(v_tenant_cash, 0), 2),
      'courier_holding', coalesce(v_courier_holding, 0),
      'ar_outstanding', v_ar_outstanding,
      'cod_unremitted', coalesce(v_cod_unremitted, 0),
      'ap_payable', coalesce(v_ap_payable, 0),
      'merchant_payable', coalesce(v_merchant_leftover, 0),
      'customer_store_credit', coalesce(v_customer_store_credit, 0),
      'net_buffer', v_net_buffer
    )
  );
END;
$$;
