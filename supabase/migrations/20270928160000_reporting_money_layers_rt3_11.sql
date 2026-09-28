-- RT3–RT11: money layers on treasury report RPCs

-- RT3: invoice profit by invoice_type
DROP FUNCTION IF EXISTS public.get_tenant_invoice_profit_report(
  bigint, date, date, text, bigint, bigint, integer, integer, boolean
);

CREATE OR REPLACE FUNCTION public.get_tenant_invoice_profit_report(
  p_tenant_id bigint,
  p_start_date date DEFAULT NULL,
  p_end_date date DEFAULT NULL,
  p_search text DEFAULT NULL,
  p_invoice_type text DEFAULT NULL,
  p_issued_by_tenant_id bigint DEFAULT NULL,
  p_invoice_id bigint DEFAULT NULL,
  p_page integer DEFAULT 1,
  p_page_size integer DEFAULT 50,
  p_skip_count boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO public
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
      AND (p_invoice_type IS NULL OR btrim(p_invoice_type) = '' OR si.invoice_type::text = p_invoice_type)
  ),
  invoice_metrics AS (
    SELECT
      si.id,
      si.invoice_no,
      si.invoice_date,
      si.invoice_type::text AS invoice_type,
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
      AND (p_invoice_type IS NULL OR btrim(p_invoice_type) = '' OR si.invoice_type::text = p_invoice_type)
      AND (
        p_search IS NULL OR btrim(p_search) = ''
        OR si.invoice_no ILIKE ('%' || btrim(p_search) || '%')
        OR bp.name ILIKE ('%' || btrim(p_search) || '%')
        OR si.recipient_name ILIKE ('%' || btrim(p_search) || '%')
      )
    GROUP BY si.id, si.invoice_no, si.invoice_date, si.invoice_type, bp.name, si.recipient_name
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
      'id', id, 'invoice_no', invoice_no, 'invoice_date', invoice_date, 'invoice_type', invoice_type,
      'customer_name', customer_name,
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

GRANT ALL ON FUNCTION public.get_tenant_invoice_profit_report(
  bigint, date, date, text, text, bigint, bigint, integer, integer, boolean
) TO authenticated;

-- RT5 + RT8: month snapshot sales_by_type, AR all billed profiles, merchant_payable
CREATE OR REPLACE FUNCTION public.get_tenant_month_snapshot_report(p_tenant_id bigint, p_month date) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO public
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
    FROM public.sales_invoice_items sii GROUP BY sii.invoice_id
  ),
  month_invoices AS (
    SELECT si.id, si.invoice_type::text AS invoice_type, si.total_amount, coalesce(ir.returned, 0) AS returned
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
    AND si.billing_profile_id IS NOT NULL
    AND si.due_amount > 0;

  SELECT round(
    coalesce(sum(CASE WHEN entity_type IN ('customer', 'middleman') THEN pending_balance ELSE 0 END), 0)
    + coalesce(sum(CASE WHEN entity_type IN ('customer', 'middleman') THEN available_balance ELSE 0 END), 0),
    2
  )
  INTO v_merchant_payable
  FROM public.wallet_accounts
  WHERE parent_tenant_id = v_books_id;

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
    )
  );
END;
$$;

-- RT5: customer dues — all billed profiles (not wholesale-only)
CREATE OR REPLACE FUNCTION public.get_customer_dues_report(
  p_tenant_id bigint,
  p_issued_by_tenant_id bigint DEFAULT NULL,
  p_search text DEFAULT NULL,
  p_aging_bucket text DEFAULT NULL,
  p_min_due numeric DEFAULT 0,
  p_over_limit_only boolean DEFAULT false,
  p_page integer DEFAULT 1,
  p_page_size integer DEFAULT 50,
  p_skip_count boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_books_id bigint;
  v_today date;
  v_totals jsonb;
  v_rows jsonb;
  v_total_count bigint;
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_offset integer;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'Tenant ID is required';
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_today := (timezone('Asia/Dhaka', now()))::date;
  v_offset := (v_page - 1) * v_page_size;

  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  WITH invoice_returned AS (
    SELECT
      sii.invoice_id,
      coalesce(sum(sii.return_quantity * sii.sell_price_amount), 0)::numeric(12,2) AS returned
    FROM public.sales_invoice_items sii
    GROUP BY sii.invoice_id
  ),
  invoice_payments_agg AS (
    SELECT
      ip.global_invoice_id AS invoice_id,
      coalesce(sum(CASE WHEN coalesce(gp.method, '') <> 'wallet_credit' THEN ip.amount ELSE 0 END), 0)::numeric(12,2) AS collected_cash,
      coalesce(sum(CASE WHEN gp.method = 'wallet_credit' THEN ip.amount ELSE 0 END), 0)::numeric(12,2) AS wallet_applied
    FROM public.invoice_payments ip
    JOIN public.global_payments gp ON gp.id = ip.payment_id
    WHERE ip.global_invoice_id IS NOT NULL
      AND gp.voided_at IS NULL
    GROUP BY ip.global_invoice_id
  ),
  per_invoice AS (
    SELECT
      si.billing_profile_id,
      si.due_amount,
      (si.total_amount + coalesce(ir.returned, 0))::numeric(12,2) AS billed,
      coalesce(ir.returned, 0)::numeric(12,2) AS returned,
      coalesce(ipa.collected_cash, 0)::numeric(12,2) AS collected_cash,
      coalesce(ipa.wallet_applied, 0)::numeric(12,2) AS wallet_applied,
      coalesce(si.written_off_amount, 0)::numeric(12,2) AS settlement,
      coalesce(si.due_date, si.invoice_date) AS aging_date,
      CASE
        WHEN si.due_amount <= 0 THEN NULL
        WHEN (v_today - coalesce(si.due_date, si.invoice_date)) <= 0 THEN 'current'
        WHEN (v_today - coalesce(si.due_date, si.invoice_date)) BETWEEN 1 AND 30 THEN '1_30'
        WHEN (v_today - coalesce(si.due_date, si.invoice_date)) BETWEEN 31 AND 60 THEN '31_60'
        WHEN (v_today - coalesce(si.due_date, si.invoice_date)) BETWEEN 61 AND 90 THEN '61_90'
        ELSE '90_plus'
      END AS aging_bucket
    FROM public.sales_invoices si
    LEFT JOIN invoice_returned ir ON ir.invoice_id = si.id
    LEFT JOIN invoice_payments_agg ipa ON ipa.invoice_id = si.id
    WHERE si.parent_tenant_id = v_books_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.billing_profile_id IS NOT NULL
      AND (p_issued_by_tenant_id IS NULL OR si.issued_by_tenant_id = p_issued_by_tenant_id)
  ),
  customer_base AS (
    SELECT
      pi.billing_profile_id,
      round(sum(pi.billed), 2) AS billed,
      round(sum(pi.returned), 2) AS returned,
      round(sum(pi.collected_cash), 2) AS collected_cash,
      round(sum(pi.wallet_applied), 2) AS wallet_applied,
      round(sum(pi.settlement), 2) AS settlement,
      round(sum(pi.due_amount), 2) AS still_due,
      min(pi.aging_date) FILTER (WHERE pi.due_amount > 0) AS oldest_due_date,
      count(*) FILTER (WHERE pi.due_amount > 0)::bigint AS open_invoice_count,
      round(coalesce(sum(pi.due_amount) FILTER (WHERE pi.aging_bucket = 'current'), 0), 2) AS aging_current,
      round(coalesce(sum(pi.due_amount) FILTER (WHERE pi.aging_bucket = '1_30'), 0), 2) AS aging_d1_30,
      round(coalesce(sum(pi.due_amount) FILTER (WHERE pi.aging_bucket = '31_60'), 0), 2) AS aging_d31_60,
      round(coalesce(sum(pi.due_amount) FILTER (WHERE pi.aging_bucket = '61_90'), 0), 2) AS aging_d61_90,
      round(coalesce(sum(pi.due_amount) FILTER (WHERE pi.aging_bucket = '90_plus'), 0), 2) AS aging_d90_plus
    FROM per_invoice pi
    GROUP BY pi.billing_profile_id
    HAVING sum(pi.due_amount) > 0
  ),
  customer_rows AS (
    SELECT
      cb.*,
      bp.name,
      bp.phone,
      cl.credit_limit
    FROM customer_base cb
    JOIN public.billing_profiles bp ON bp.id = cb.billing_profile_id
    LEFT JOIN LATERAL (
      SELECT max(scga.credit_limit_amount)::numeric(12,2) AS credit_limit
      FROM public.shop_customer_group_access scga
      JOIN public.shops sh ON sh.id = scga.shop_id
      WHERE scga.customer_group_id = bp.customer_group_id
        AND public.resolve_parent_tenant_id(sh.tenant_id) = v_books_id
    ) cl ON true
    WHERE cb.still_due >= coalesce(p_min_due, 0)
      AND (
        p_search IS NULL
        OR btrim(p_search) = ''
        OR bp.name ILIKE ('%' || btrim(p_search) || '%')
        OR bp.phone ILIKE ('%' || btrim(p_search) || '%')
      )
      AND (
        p_aging_bucket IS NULL
        OR btrim(p_aging_bucket) = ''
        OR (p_aging_bucket = 'current' AND cb.aging_current > 0)
        OR (p_aging_bucket = '1_30' AND cb.aging_d1_30 > 0)
        OR (p_aging_bucket = '31_60' AND cb.aging_d31_60 > 0)
        OR (p_aging_bucket = '61_90' AND cb.aging_d61_90 > 0)
        OR (p_aging_bucket = '90_plus' AND cb.aging_d90_plus > 0)
      )
      AND (
        NOT coalesce(p_over_limit_only, false)
        OR (cl.credit_limit IS NOT NULL AND cb.still_due > cl.credit_limit)
      )
  ),
  totals_calc AS (
    SELECT
      round(coalesce(sum(billed), 0), 2) AS billed,
      round(coalesce(sum(returned), 0), 2) AS returned,
      round(coalesce(sum(collected_cash), 0), 2) AS collected_cash,
      round(coalesce(sum(wallet_applied), 0), 2) AS wallet_applied,
      round(coalesce(sum(settlement), 0), 2) AS settlement,
      round(coalesce(sum(still_due), 0), 2) AS still_due,
      count(*)::bigint AS customer_count
    FROM customer_rows
  ),
  paged AS (
    SELECT * FROM customer_rows ORDER BY still_due DESC, name ASC OFFSET v_offset LIMIT v_page_size
  )
  SELECT (SELECT count(*) FROM customer_rows),
    (SELECT jsonb_build_object(
      'billed', billed, 'returned', returned, 'collected_cash', collected_cash,
      'wallet_applied', wallet_applied, 'settlement', settlement, 'still_due', still_due,
      'customer_count', customer_count
    ) FROM totals_calc),
    coalesce((SELECT jsonb_agg(jsonb_build_object(
      'billing_profile_id', billing_profile_id, 'name', name, 'phone', phone, 'credit_limit', credit_limit,
      'billed', billed, 'returned', returned, 'collected_cash', collected_cash, 'wallet_applied', wallet_applied,
      'settlement', settlement, 'still_due', still_due, 'oldest_due_date', oldest_due_date,
      'open_invoice_count', open_invoice_count,
      'aging', jsonb_build_object(
        'current', aging_current, 'd1_30', aging_d1_30, 'd31_60', aging_d31_60,
        'd61_90', aging_d61_90, 'd90_plus', aging_d90_plus
      )
    ) ORDER BY still_due DESC, name ASC) FROM paged), '[]'::jsonb)
  INTO v_total_count, v_totals, v_rows;

  RETURN jsonb_build_object(
    'totals', coalesce(v_totals, '{}'::jsonb),
    'rows', coalesce(v_rows, '[]'::jsonb),
    'page', v_page,
    'page_size', v_page_size,
    'total_count', CASE WHEN coalesce(p_skip_count, true) THEN NULL ELSE v_total_count END
  );
END;
$$;

-- RT4 + RT11: cash in by receipt source and payment instruments
CREATE OR REPLACE FUNCTION public.get_tenant_cash_in_report(
  p_tenant_id bigint,
  p_start_date timestamptz DEFAULT NULL,
  p_end_date timestamptz DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO public
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
  receipt_lines as (
    select
      gp.id as payment_id,
      gp.id::text || '-' || coalesce(gpi.id::text, 'h') as line_id,
      coalesce(gpi.amount, gp.amount) as amount,
      case
        when gp.collection_source = 'recipient'::public.collection_source_type then 'courier_remittance'
        else 'buyer_receipt'
      end as source_type,
      gp.id::text as source_id,
      nullif(trim(gp.note), '') as label,
      ri.invoice_id,
      gp.created_at,
      coalesce(gpi.payment_method_code, nullif(trim(gp.method::text), ''), 'other') as method,
      gpi.reference as instrument_reference,
      gpi.cheque_number,
      bb.name as bank_name
    from public.global_payments gp
    left join public.global_payment_instruments gpi on gpi.payment_id = gp.id
    left join public.bd_banks bb on bb.id = gpi.bd_bank_id
    left join receipt_invoice ri on ri.payment_id = gp.id
    where gp.tenant_id = v_books_id
      and gp.voided_at is null
      and coalesce(gp.method::text, '') <> 'wallet_credit'
      and (p_start_date is null or coalesce(gp.payment_date::timestamptz, gp.created_at) >= p_start_date)
      and (p_end_date is null or coalesce(gp.payment_date::timestamptz, gp.created_at) <= p_end_date)
  ),
  lined as (
    select distinct on (line_id)
      line_id as id,
      amount,
      source_type,
      source_id,
      case
        when bank_name is not null and cheque_number is not null then
          coalesce(label, '') || ' Cheque ' || cheque_number || ' @ ' || bank_name
        when instrument_reference is not null then coalesce(label, instrument_reference)
        else label
      end as label,
      invoice_id,
      created_at,
      method
    from receipt_lines
    order by line_id, amount desc
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

-- RT7: wallet liability buckets
CREATE OR REPLACE FUNCTION public.get_tenant_wallet_liability_report(
  p_tenant_id bigint,
  p_start_date date DEFAULT NULL,
  p_end_date date DEFAULT NULL,
  p_search text DEFAULT NULL,
  p_page integer DEFAULT 1,
  p_page_size integer DEFAULT 50,
  p_skip_count boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_books_id bigint;
  v_totals jsonb;
  v_rows jsonb;
  v_total_count bigint;
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_offset integer := (greatest(coalesce(p_page, 1), 1) - 1) * greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_start_ts timestamptz := CASE WHEN p_start_date IS NULL THEN NULL ELSE p_start_date::timestamptz END;
  v_end_ts timestamptz := CASE WHEN p_end_date IS NULL THEN NULL ELSE (p_end_date + interval '1 day' - interval '1 microsecond') END;
  v_customer_store_credit numeric(18,4) := 0;
  v_merchant_payable numeric(18,4) := 0;
  v_courier numeric(18,4) := 0;
BEGIN
  IF p_tenant_id IS NULL THEN RAISE EXCEPTION 'Tenant ID is required'; END IF;
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN RAISE EXCEPTION 'Not authorized'; END IF;

  SELECT
    round(coalesce(sum(CASE WHEN entity_type = 'customer' THEN available_balance ELSE 0 END), 0), 2),
    round(coalesce(sum(CASE WHEN entity_type IN ('customer', 'middleman') THEN pending_balance + available_balance ELSE 0 END), 0), 2),
    round(coalesce(sum(CASE WHEN entity_type = 'courier' THEN pending_balance + available_balance ELSE 0 END), 0), 2)
  INTO v_customer_store_credit, v_merchant_payable, v_courier
  FROM public.wallet_accounts
  WHERE parent_tenant_id = v_books_id;

  WITH ledger_agg AS (
    SELECT
      l.entity_id AS billing_profile_id,
      round(
        coalesce(sum(CASE
          WHEN l.type = 'credit'
            AND coalesce(l.metadata->>'reversed_by', '') = ''
            AND coalesce(l.metadata->>'purpose', '') IN ('customer_ar_reduction', 'store_credit')
          THEN l.amount
          ELSE 0
        END), 0)
        - coalesce(sum(CASE
          WHEN l.type = 'debit'
            AND coalesce(l.metadata->>'purpose', '') IN ('reverse_customer_ar_reduction', 'void_store_credit')
          THEN l.amount
          ELSE 0
        END), 0),
        4
      ) AS credit_issued,
      round(coalesce(sum(CASE
        WHEN l.type = 'debit' AND coalesce(l.metadata->>'purpose', '') = 'apply_store_credit' THEN l.amount
        ELSE 0 END), 0), 4) AS credit_applied
    FROM public.universal_wallet_ledger l
    WHERE l.parent_tenant_id = v_books_id
      AND l.entity_type = 'customer'
      AND (v_start_ts IS NULL OR l.created_at >= v_start_ts)
      AND (v_end_ts IS NULL OR l.created_at <= v_end_ts)
    GROUP BY l.entity_id
  ),
  base AS (
    SELECT
      wa.entity_id AS billing_profile_id,
      bp.name,
      bp.phone,
      round(coalesce(la.credit_issued, 0), 2) AS credit_issued,
      round(coalesce(la.credit_applied, 0), 2) AS credit_applied,
      round(coalesce(wa.available_balance, 0), 2) AS outstanding
    FROM public.wallet_accounts wa
    JOIN public.billing_profiles bp ON bp.id = wa.entity_id
    LEFT JOIN ledger_agg la ON la.billing_profile_id = wa.entity_id
    WHERE wa.parent_tenant_id = v_books_id
      AND wa.entity_type = 'customer'
      AND (
        coalesce(wa.available_balance, 0) > 0
        OR coalesce(la.credit_issued, 0) > 0
        OR coalesce(la.credit_applied, 0) > 0
      )
      AND (
        p_search IS NULL OR btrim(p_search) = ''
        OR bp.name ILIKE ('%' || btrim(p_search) || '%')
        OR bp.phone ILIKE ('%' || btrim(p_search) || '%')
      )
  ),
  totals_calc AS (
    SELECT round(coalesce(sum(credit_issued), 0), 2) AS credit_issued,
      round(coalesce(sum(credit_applied), 0), 2) AS credit_applied,
      round(coalesce(sum(outstanding), 0), 2) AS outstanding,
      count(*)::bigint AS customer_count
    FROM base
  ),
  paged AS (
    SELECT * FROM base ORDER BY outstanding DESC, name ASC OFFSET v_offset LIMIT v_page_size
  )
  SELECT (SELECT count(*) FROM base),
    (SELECT jsonb_build_object(
      'credit_issued', credit_issued, 'credit_applied', credit_applied,
      'outstanding', outstanding, 'customer_count', customer_count,
      'customer_store_credit', v_customer_store_credit,
      'merchant_payable', v_merchant_payable,
      'courier', v_courier
    ) FROM totals_calc),
    coalesce((SELECT jsonb_agg(jsonb_build_object(
      'billing_profile_id', billing_profile_id, 'name', name, 'phone', phone,
      'credit_issued', credit_issued, 'credit_applied', credit_applied, 'outstanding', outstanding
    ) ORDER BY outstanding DESC, name ASC) FROM paged), '[]'::jsonb)
  INTO v_total_count, v_totals, v_rows;

  RETURN jsonb_build_object('totals', coalesce(v_totals, '{}'::jsonb), 'rows', coalesce(v_rows, '[]'::jsonb),
    'page', v_page, 'page_size', v_page_size,
    'total_count', CASE WHEN coalesce(p_skip_count, true) THEN NULL ELSE v_total_count END);
END;
$$;

-- RT6: courier COD remitted = net remittance, not COD face
CREATE OR REPLACE FUNCTION public.get_tenant_courier_cod_report(
  p_tenant_id bigint,
  p_start_date date DEFAULT NULL,
  p_end_date date DEFAULT NULL,
  p_courier_service_id uuid DEFAULT NULL,
  p_page integer DEFAULT 1,
  p_page_size integer DEFAULT 50,
  p_skip_count boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_books_id bigint;
  v_totals jsonb;
  v_rows jsonb;
  v_orders jsonb := NULL;
  v_total_count bigint;
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_offset integer := (greatest(coalesce(p_page, 1), 1) - 1) * greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_start_ts timestamptz := CASE WHEN p_start_date IS NULL THEN NULL ELSE p_start_date::timestamptz END;
  v_end_ts timestamptz := CASE WHEN p_end_date IS NULL THEN NULL ELSE (p_end_date + interval '1 day' - interval '1 microsecond') END;
BEGIN
  IF p_tenant_id IS NULL THEN RAISE EXCEPTION 'Tenant ID is required'; END IF;
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN RAISE EXCEPTION 'Not authorized'; END IF;

  WITH delivered_orders AS (
    SELECT
      so.id AS order_id,
      so.order_no,
      coalesce(so.courier_awb_number, so.courier_tracking_number) AS awb,
      coalesce(so.cod_collect_amount, 0)::numeric(12,2) AS cod_collect_amount,
      so.courier_remittance_ref AS remittance_ref,
      so.delivered_at,
      so.courier_service_id,
      coalesce(cs.name, so.courier_name, 'Unassigned') AS courier_name,
      round(coalesce((
        SELECT l.amount
        FROM public.universal_wallet_ledger l
        WHERE l.parent_tenant_id = v_books_id
          AND l.entity_type = 'tenant'
          AND l.source_type = 'shop_order'
          AND l.source_id = so.id::text
          AND coalesce(l.metadata->>'purpose', '') = 'tenant_remittance_received'
        LIMIT 1
      ), 0), 2) AS remitted_amount
    FROM public.shop_orders so
    LEFT JOIN public.courier_services cs ON cs.id = so.courier_service_id
    WHERE public.resolve_parent_tenant_id(so.tenant_id) = v_books_id
      AND so.status = 'delivered'::public.shop_order_status
      AND so.shop_type_snapshot = 'dropship'::public.shop_type_enum
      AND coalesce(so.cod_collect_amount, 0) > 0
      AND (v_start_ts IS NULL OR so.delivered_at >= v_start_ts)
      AND (v_end_ts IS NULL OR so.delivered_at <= v_end_ts)
      AND (p_courier_service_id IS NULL OR so.courier_service_id = p_courier_service_id)
  ),
  order_amounts AS (
    SELECT *,
      remitted_amount AS remitted,
      round(greatest(cod_collect_amount - remitted_amount, 0), 2) AS unremitted,
      round(remitted_amount - cod_collect_amount, 2) AS short_over
    FROM delivered_orders
  ),
  courier_rows AS (
    SELECT
      courier_service_id,
      courier_name,
      round(coalesce(sum(cod_collect_amount), 0), 2) AS delivered_cod,
      round(coalesce(sum(remitted), 0), 2) AS remitted,
      round(coalesce(sum(unremitted), 0), 2) AS unremitted,
      round(coalesce(sum(short_over), 0), 2) AS short_over,
      count(*)::bigint AS order_count
    FROM order_amounts
    GROUP BY courier_service_id, courier_name
  ),
  totals_calc AS (
    SELECT round(coalesce(sum(delivered_cod), 0), 2) AS delivered_cod,
      round(coalesce(sum(remitted), 0), 2) AS remitted,
      round(coalesce(sum(unremitted), 0), 2) AS unremitted,
      round(coalesce(sum(short_over), 0), 2) AS short_over,
      coalesce(sum(order_count), 0)::bigint AS order_count
    FROM courier_rows
  ),
  paged AS (
    SELECT * FROM courier_rows ORDER BY delivered_cod DESC, courier_name ASC OFFSET v_offset LIMIT v_page_size
  )
  SELECT (SELECT count(*) FROM courier_rows),
    (SELECT jsonb_build_object('delivered_cod', delivered_cod, 'remitted', remitted, 'unremitted', unremitted,
      'short_over', short_over, 'order_count', order_count) FROM totals_calc),
    coalesce((SELECT jsonb_agg(jsonb_build_object(
      'courier_service_id', courier_service_id, 'courier_name', courier_name,
      'delivered_cod', delivered_cod, 'remitted', remitted, 'unremitted', unremitted,
      'short_over', short_over, 'order_count', order_count
    ) ORDER BY delivered_cod DESC, courier_name ASC) FROM paged), '[]'::jsonb)
  INTO v_total_count, v_totals, v_rows;

  IF p_courier_service_id IS NOT NULL THEN
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      'order_id', order_id, 'order_no', order_no, 'awb', awb,
      'cod_collect_amount', cod_collect_amount, 'remittance_ref', remittance_ref, 'delivered_at', delivered_at,
      'remitted', remitted
    ) ORDER BY delivered_at DESC NULLS LAST, order_id DESC), '[]'::jsonb)
    INTO v_orders
    FROM order_amounts;
  END IF;

  RETURN jsonb_build_object('totals', coalesce(v_totals, '{}'::jsonb), 'rows', coalesce(v_rows, '[]'::jsonb),
    'orders', v_orders, 'page', v_page, 'page_size', v_page_size,
    'total_count', CASE WHEN coalesce(p_skip_count, true) THEN NULL ELSE v_total_count END);
END;
$$;
