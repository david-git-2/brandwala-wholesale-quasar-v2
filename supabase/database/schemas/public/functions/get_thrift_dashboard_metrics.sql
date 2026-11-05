CREATE FUNCTION public.get_thrift_dashboard_metrics (
  p_tenant_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_items_added_today BIGINT;
  v_total_items BIGINT;
  v_available_items BIGINT;
  v_sold_items BIGINT;
  v_cod_pending_count BIGINT;
  v_cod_expected_total NUMERIC(14,2);
  v_active_invoices_today BIGINT;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_reports', 'view') THEN
    RAISE EXCEPTION 'Thrift dashboard metrics require thrift_reports view permission';
  END IF;

  SELECT COUNT(*)
  INTO v_items_added_today
  FROM public.thrift_stocks
  WHERE tenant_id = p_tenant_id
    AND deleted_at IS NULL
    AND created_at >= date_trunc('day', NOW());

  SELECT COUNT(*)
  INTO v_total_items
  FROM public.thrift_stocks
  WHERE tenant_id = p_tenant_id
    AND deleted_at IS NULL;

  SELECT COUNT(*)
  INTO v_available_items
  FROM public.thrift_stocks
  WHERE tenant_id = p_tenant_id
    AND deleted_at IS NULL
    AND status = 'AVAILABLE'::public.thrift_stock_status;

  SELECT COUNT(*)
  INTO v_sold_items
  FROM public.thrift_stocks
  WHERE tenant_id = p_tenant_id
    AND deleted_at IS NULL
    AND status = 'SOLD'::public.thrift_stock_status;

  SELECT
    COUNT(*)::BIGINT,
    COALESCE(SUM(COALESCE(inv.cod_expected, 0)), 0)::NUMERIC(14,2)
  INTO v_cod_pending_count, v_cod_expected_total
  FROM public.thrift_sales_invoices inv
  WHERE inv.tenant_id = p_tenant_id
    AND COALESCE(inv.status, 'ACTIVE') = 'ACTIVE'
    AND inv.payment_status = 'COD_PENDING';

  SELECT COUNT(*)
  INTO v_active_invoices_today
  FROM public.thrift_sales_invoices inv
  WHERE inv.tenant_id = p_tenant_id
    AND COALESCE(inv.status, 'ACTIVE') = 'ACTIVE'
    AND inv.date >= date_trunc('day', NOW());

  RETURN jsonb_build_object(
    'items_added_today', v_items_added_today,
    'total_items', v_total_items,
    'available_items', v_available_items,
    'sold_items', v_sold_items,
    'cod_pending_count', v_cod_pending_count,
    'cod_expected_total', v_cod_expected_total,
    'active_invoices_today', v_active_invoices_today
  );
END;
$function$;

GRANT ALL ON FUNCTION public.get_thrift_dashboard_metrics(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_thrift_dashboard_metrics(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_thrift_dashboard_metrics(bigint) TO service_role;