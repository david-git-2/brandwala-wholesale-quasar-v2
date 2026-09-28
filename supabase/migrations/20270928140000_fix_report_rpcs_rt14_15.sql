-- RT14–RT15: cash in + month snapshot cash from live global_payments receipts
CREATE OR REPLACE FUNCTION "public"."get_tenant_cash_in_report"("p_tenant_id" bigint, "p_start_date" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_end_date" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_books_id bigint;
  v_cash_in numeric(18,4) := 0.0000;
  v_count integer := 0;
  v_by_method jsonb;
  v_entries jsonb;
begin
  if p_tenant_id is null then
    raise exception 'Tenant ID is required';
  end if;

  select coalesce(t.parent_id, t.id)
  into v_books_id
  from public.tenants t
  where t.id = p_tenant_id;

  if v_books_id is null then
    raise exception 'Tenant not found';
  end if;

  if not (
    public.membership_has_module_action(p_tenant_id, 'universal_wallet', 'view')
    or public.membership_has_module_action(v_books_id, 'universal_wallet', 'view')
  ) then
    raise exception 'Not authorized';
  end if;

  with receipt_invoice as (
    select
      ip.payment_id,
      min(ip.global_invoice_id) as invoice_id
    from public.invoice_payments ip
    group by ip.payment_id
  ),
  lined as (
    select
      gp.id::text as id,
      gp.amount,
      'sales_invoice'::text as source_type,
      gp.id::text as source_id,
      nullif(trim(gp.note), '') as label,
      ri.invoice_id,
      gp.created_at,
      coalesce(nullif(trim(gp.method::text), ''), 'other') as method
    from public.global_payments gp
    left join receipt_invoice ri on ri.payment_id = gp.id
    where gp.tenant_id = v_books_id
      and gp.voided_at is null
      and coalesce(gp.method::text, '') <> 'wallet_credit'
      and (p_start_date is null or coalesce(gp.payment_date::timestamptz, gp.created_at) >= p_start_date)
      and (p_end_date is null or coalesce(gp.payment_date::timestamptz, gp.created_at) <= p_end_date)
  )
  select
    coalesce(sum(amount), 0.0000),
    count(*)::integer,
    coalesce(
      (
        select jsonb_agg(jsonb_build_object(
          'method', m.method,
          'amount', m.amt,
          'count', m.cnt
        ) order by m.amt desc)
        from (
          select method, sum(amount) as amt, count(*)::integer as cnt
          from lined
          group by method
        ) m
      ),
      '[]'::jsonb
    ),
    coalesce(
      (
        select jsonb_agg(jsonb_build_object(
          'id', e.id,
          'amount', e.amount,
          'method', e.method,
          'source_type', e.source_type,
          'source_id', e.source_id,
          'label', e.label,
          'invoice_id', e.invoice_id,
          'created_at', e.created_at
        ) order by e.created_at desc, e.id desc)
        from lined e
      ),
      '[]'::jsonb
    )
  into v_cash_in, v_count, v_by_method, v_entries
  from lined;

  return jsonb_build_object(
    'tenant_id', v_books_id,
    'start_date', p_start_date,
    'end_date', p_end_date,
    'cash_in_total', v_cash_in,
    'entry_count', v_count,
    'by_method', v_by_method,
    'entries', v_entries
  );
end;
$_$;

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
  v_wallet_liability numeric(18,4) := 0;
  v_unsold_stock_value numeric(18,4) := 0;
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
    FROM public.sales_invoice_items sii GROUP BY sii.invoice_id
  ),
  month_invoices AS (
    SELECT si.id, si.total_amount, coalesce(ir.returned, 0) AS returned
    FROM public.sales_invoices si
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
      round(coalesce(sum(greatest(sii.quantity - sii.return_quantity, 0) * coalesce(sii.unit_cost_price, 0)), 0), 2) AS cogs
    FROM public.sales_invoice_items sii
    JOIN public.sales_invoices si ON si.id = sii.invoice_id
    WHERE si.parent_tenant_id = v_books_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.invoice_date BETWEEN v_start AND v_end
  )
  SELECT
    round(coalesce((SELECT sum(total_amount + returned) FROM month_invoices), 0)
      - coalesce((SELECT sum(returned) FROM month_invoices), 0), 2),
    round(coalesce((SELECT cogs FROM line_metrics), 0), 2)
  INTO v_net_sales, v_cogs;

  v_gross_profit := round(v_net_sales - v_cogs, 2);

  SELECT round(coalesce(sum(gp.amount), 0), 2)
  INTO v_cash_collected
  FROM public.global_payments gp
  WHERE gp.tenant_id = v_books_id
    AND gp.voided_at IS NULL
    AND coalesce(gp.method::text, '') <> 'wallet_credit'
    AND coalesce(gp.payment_date::timestamptz, gp.created_at) BETWEEN v_start_ts AND v_end_ts;

  SELECT round(coalesce(sum(si.due_amount), 0), 2)
  INTO v_ar_outstanding
  FROM public.sales_invoices si
  WHERE si.parent_tenant_id = v_books_id
    AND si.invoice_status = 'issued'::public.global_invoice_status
    AND si.invoice_type = 'wholesale'::public.global_invoice_type
    AND si.due_amount > 0;

  SELECT round(coalesce(sum(wa.available_balance), 0), 2)
  INTO v_wallet_liability
  FROM public.wallet_accounts wa
  WHERE wa.parent_tenant_id = v_books_id
    AND wa.entity_type = 'customer';

  SELECT round(coalesce(sum(inv.sellable_qty * coalesce(gsi.landed_cost_bdt, 0)), 0), 2)
  INTO v_unsold_stock_value
  FROM public.global_shipments s
  JOIN public.global_shipment_items gsi ON gsi.shipment_id = s.id
  LEFT JOIN LATERAL (
    SELECT coalesce(sum(CASE WHEN gs.availability = 'sellable' THEN gs.quantity ELSE 0 END), 0) AS sellable_qty
    FROM public.global_stocks gs
    WHERE gs.shipment_item_id = gsi.id
  ) inv ON true
  WHERE s.parent_tenant_id = v_books_id;

  RETURN jsonb_build_object(
    'tenant_id', v_books_id,
    'month', v_start,
    'start_date', v_start,
    'end_date', v_end,
    'kpis', jsonb_build_object(
      'net_sales', v_net_sales,
      'cogs', v_cogs,
      'gross_profit', v_gross_profit,
      'cash_collected', v_cash_collected,
      'ar_outstanding', v_ar_outstanding,
      'wallet_liability', v_wallet_liability,
      'unsold_stock_value', v_unsold_stock_value
    )
  );
END;
$$;
