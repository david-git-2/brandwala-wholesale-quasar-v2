-- RT12: finance report RPC fixes

CREATE OR REPLACE FUNCTION "public"."get_customer_dues_report"("p_tenant_id" bigint, "p_issued_by_tenant_id" bigint DEFAULT NULL::bigint, "p_search" "text" DEFAULT NULL::"text", "p_aging_bucket" "text" DEFAULT NULL::"text", "p_min_due" numeric DEFAULT 0, "p_over_limit_only" boolean DEFAULT false, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 50, "p_skip_count" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
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
      AND si.invoice_type = 'wholesale'::public.global_invoice_type
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
    SELECT *
    FROM customer_rows
    ORDER BY still_due DESC, name ASC
    OFFSET v_offset
    LIMIT v_page_size
  )
  SELECT
    (SELECT count(*) FROM customer_rows),
    (SELECT jsonb_build_object(
      'billed', billed,
      'returned', returned,
      'collected_cash', collected_cash,
      'wallet_applied', wallet_applied,
      'settlement', settlement,
      'still_due', still_due,
      'customer_count', customer_count
    ) FROM totals_calc),
    coalesce(
      (SELECT jsonb_agg(jsonb_build_object(
        'billing_profile_id', billing_profile_id,
        'name', name,
        'phone', phone,
        'credit_limit', credit_limit,
        'billed', billed,
        'returned', returned,
        'collected_cash', collected_cash,
        'wallet_applied', wallet_applied,
        'settlement', settlement,
        'still_due', still_due,
        'oldest_due_date', oldest_due_date,
        'aging', jsonb_build_object(
          'current', aging_current,
          'd1_30', aging_d1_30,
          'd31_60', aging_d31_60,
          'd61_90', aging_d61_90,
          'd90_plus', aging_d90_plus
        ),
        'open_invoice_count', open_invoice_count
      ) ORDER BY still_due DESC, name ASC) FROM paged),
      '[]'::jsonb
    )
  INTO v_total_count, v_totals, v_rows;

  RETURN jsonb_build_object(
    'totals', coalesce(v_totals, jsonb_build_object(
      'billed', 0, 'returned', 0, 'collected_cash', 0, 'wallet_applied', 0,
      'settlement', 0, 'still_due', 0, 'customer_count', 0
    )),
    'rows', coalesce(v_rows, '[]'::jsonb),
    'page', v_page,
    'page_size', v_page_size,
    'total_count', CASE WHEN coalesce(p_skip_count, true) THEN NULL ELSE v_total_count END
  );
END;
$$;;


CREATE OR REPLACE FUNCTION "public"."get_tenant_invoice_book_report"("p_tenant_id" bigint, "p_start_date" "date" DEFAULT NULL::"date", "p_end_date" "date" DEFAULT NULL::"date", "p_search" "text" DEFAULT NULL::"text", "p_invoice_type" "text" DEFAULT NULL::"text", "p_payment_status" "text" DEFAULT NULL::"text", "p_issued_by_tenant_id" bigint DEFAULT NULL::bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 50, "p_skip_count" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_totals jsonb;
  v_rows jsonb;
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

  WITH invoice_returned AS (
    SELECT sii.invoice_id, coalesce(sum(sii.return_quantity * sii.sell_price_amount), 0)::numeric(12,2) AS returned
    FROM public.sales_invoice_items sii GROUP BY sii.invoice_id
  ),
  invoice_payments_agg AS (
    SELECT ip.global_invoice_id AS invoice_id,
      coalesce(sum(CASE WHEN coalesce(gp.method, '') <> 'wallet_credit' THEN ip.amount ELSE 0 END), 0)::numeric(12,2) AS collected_cash,
      coalesce(sum(CASE WHEN gp.method = 'wallet_credit' THEN ip.amount ELSE 0 END), 0)::numeric(12,2) AS wallet_applied
    FROM public.invoice_payments ip
    JOIN public.global_payments gp ON gp.id = ip.payment_id
    WHERE ip.global_invoice_id IS NOT NULL
      AND gp.voided_at IS NULL
    GROUP BY ip.global_invoice_id
  ),
  base AS (
    SELECT
      si.id, si.invoice_no, si.invoice_date, si.invoice_type::text AS invoice_type,
      si.payment_status, si.billing_profile_id, si.due_amount,
      coalesce(nullif(trim(bp.name), ''), nullif(trim(si.recipient_name), ''), 'Unknown') AS customer_name,
      coalesce(child.name, parent.name) AS issued_by_name,
      round((si.total_amount + coalesce(ir.returned, 0)), 2) AS billed,
      round(coalesce(ir.returned, 0), 2) AS returned,
      round(coalesce(ipa.collected_cash, 0), 2) AS collected_cash,
      round(coalesce(ipa.wallet_applied, 0), 2) AS wallet_applied,
      round(coalesce(si.written_off_amount, 0), 2) AS settlement,
      round(coalesce(si.due_amount, 0), 2) AS still_due
    FROM public.sales_invoices si
    LEFT JOIN public.billing_profiles bp ON bp.id = si.billing_profile_id
    LEFT JOIN public.tenants child ON child.id = si.issued_by_tenant_id
    LEFT JOIN public.tenants parent ON parent.id = si.parent_tenant_id
    LEFT JOIN invoice_returned ir ON ir.invoice_id = si.id
    LEFT JOIN invoice_payments_agg ipa ON ipa.invoice_id = si.id
    WHERE si.parent_tenant_id = v_books_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND (p_start_date IS NULL OR si.invoice_date >= p_start_date)
      AND (p_end_date IS NULL OR si.invoice_date <= p_end_date)
      AND (p_invoice_type IS NULL OR btrim(p_invoice_type) = '' OR si.invoice_type::text = p_invoice_type)
      AND (p_payment_status IS NULL OR btrim(p_payment_status) = '' OR si.payment_status = p_payment_status)
      AND (p_issued_by_tenant_id IS NULL OR si.issued_by_tenant_id = p_issued_by_tenant_id)
      AND (
        p_search IS NULL OR btrim(p_search) = ''
        OR si.invoice_no ILIKE ('%' || btrim(p_search) || '%')
        OR bp.name ILIKE ('%' || btrim(p_search) || '%')
        OR si.recipient_name ILIKE ('%' || btrim(p_search) || '%')
      )
  ),
  totals_calc AS (
    SELECT round(coalesce(sum(billed), 0), 2) AS billed, round(coalesce(sum(returned), 0), 2) AS returned,
      round(coalesce(sum(collected_cash), 0), 2) AS collected_cash, round(coalesce(sum(wallet_applied), 0), 2) AS wallet_applied,
      round(coalesce(sum(settlement), 0), 2) AS settlement, round(coalesce(sum(still_due), 0), 2) AS still_due,
      count(*)::bigint AS invoice_count FROM base
  ),
  paged AS (
    SELECT * FROM base ORDER BY invoice_date DESC, id DESC OFFSET v_offset LIMIT v_page_size
  )
  SELECT (SELECT count(*) FROM base),
    (SELECT jsonb_build_object('billed', billed, 'returned', returned, 'collected_cash', collected_cash,
      'wallet_applied', wallet_applied, 'settlement', settlement, 'still_due', still_due, 'invoice_count', invoice_count) FROM totals_calc),
    coalesce((SELECT jsonb_agg(jsonb_build_object(
      'id', id, 'invoice_no', invoice_no, 'invoice_date', invoice_date, 'invoice_type', invoice_type,
      'payment_status', payment_status, 'customer_name', customer_name, 'billing_profile_id', billing_profile_id,
      'issued_by_name', issued_by_name, 'billed', billed, 'returned', returned, 'collected_cash', collected_cash,
      'wallet_applied', wallet_applied, 'settlement', settlement, 'still_due', still_due
    ) ORDER BY invoice_date DESC, id DESC) FROM paged), '[]'::jsonb)
  INTO v_total_count, v_totals, v_rows;

  RETURN jsonb_build_object('totals', coalesce(v_totals, '{}'::jsonb), 'rows', coalesce(v_rows, '[]'::jsonb),
    'page', v_page, 'page_size', v_page_size,
    'total_count', CASE WHEN coalesce(p_skip_count, true) THEN NULL ELSE v_total_count END);
END;
$$;;
