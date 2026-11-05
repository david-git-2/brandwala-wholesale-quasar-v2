CREATE FUNCTION public.get_sales_invoice_dashboard_metrics (
  p_tenant_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_today date;
  v_today_billed numeric := 0;
  v_unpaid_count bigint := 0;
  v_overdue_count bigint := 0;
  v_draft_count bigint := 0;
  v_paid numeric := 0;
  v_due numeric := 0;
  v_overdue numeric := 0;
  v_customers jsonb := '[]'::jsonb;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'global_invoice', 'view') THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_today := (timezone('Asia/Dhaka', now()))::date;

  SELECT
    coalesce(sum(si.total_amount) FILTER (
      WHERE si.invoice_status = 'issued'::public.global_invoice_status
        AND si.invoice_date = v_today
    ), 0),
    count(*) FILTER (
      WHERE si.invoice_status = 'issued'::public.global_invoice_status
        AND si.due_amount > 0
    ),
    count(*) FILTER (
      WHERE si.invoice_status = 'issued'::public.global_invoice_status
        AND si.due_amount > 0
        AND si.due_date IS NOT NULL
        AND si.due_date < v_today
    ),
    count(*) FILTER (WHERE si.invoice_status = 'draft'::public.global_invoice_status),
    coalesce(sum(si.paid_amount) FILTER (
      WHERE si.invoice_status = 'issued'::public.global_invoice_status
    ), 0),
    coalesce(sum(si.due_amount) FILTER (
      WHERE si.invoice_status = 'issued'::public.global_invoice_status
        AND (si.due_date IS NULL OR si.due_date >= v_today)
        AND si.due_amount > 0
    ), 0),
    coalesce(sum(si.due_amount) FILTER (
      WHERE si.invoice_status = 'issued'::public.global_invoice_status
        AND si.due_amount > 0
        AND si.due_date IS NOT NULL
        AND si.due_date < v_today
    ), 0)
  INTO v_today_billed, v_unpaid_count, v_overdue_count, v_draft_count, v_paid, v_due, v_overdue
  FROM public.bills si
  WHERE si.issued_by_tenant_id = p_tenant_id;

  SELECT coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  INTO v_customers
  FROM (
    SELECT
      coalesce(nullif(trim(bp.name), ''), nullif(trim(si.recipient_name), ''), 'Unknown') AS name,
      round(sum(si.due_amount), 2) AS due_amount,
      count(*)::bigint AS invoice_count
    FROM public.bills si
    LEFT JOIN public.billing_profiles bp ON bp.id = si.profile_id
    WHERE si.issued_by_tenant_id = p_tenant_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.due_amount > 0
      AND si.due_date IS NOT NULL
      AND si.due_date < v_today
    GROUP BY 1
    ORDER BY sum(si.due_amount) DESC
    LIMIT 5
  ) r;

  RETURN jsonb_build_object(
    'tenant_id', p_tenant_id,
    'today_billed_amount', round(v_today_billed, 2),
    'unpaid_count', v_unpaid_count,
    'overdue_count', v_overdue_count,
    'draft_count', v_draft_count,
    'paid_amount', round(v_paid, 2),
    'due_amount', round(v_due, 2),
    'overdue_amount', round(v_overdue, 2),
    'overdue_customers', v_customers
  );
END;
$function$;

GRANT ALL ON FUNCTION public.get_sales_invoice_dashboard_metrics(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_sales_invoice_dashboard_metrics(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_sales_invoice_dashboard_metrics(bigint) TO service_role;