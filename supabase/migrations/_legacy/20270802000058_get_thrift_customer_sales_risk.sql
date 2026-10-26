-- Phase 2: Customer sales risk history (RTO + post-pay returns) by phone.
-- Used by create-sale UI (phase 3). No schema changes.

BEGIN;

CREATE OR REPLACE FUNCTION public.get_thrift_customer_sales_risk(
  p_tenant_id BIGINT,
  p_phone TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_phone TEXT := public.normalize_thrift_phone(p_phone);
  v_customer_id BIGINT;
  v_rto_count BIGINT := 0;
  v_return_count BIGINT := 0;
  v_rtos JSONB := '[]'::jsonb;
  v_returns JSONB := '[]'::jsonb;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'view') THEN
    RAISE EXCEPTION 'Get thrift customer sales risk requires thrift_sales view permission';
  END IF;

  IF v_phone = '' THEN
    RETURN jsonb_build_object(
      'customer_id', NULL,
      'rto_count', 0,
      'return_count', 0,
      'rtos', '[]'::jsonb,
      'returns', '[]'::jsonb
    );
  END IF;

  SELECT c.id
  INTO v_customer_id
  FROM public.thrift_customers c
  WHERE c.tenant_id = p_tenant_id
    AND c.phone_normalized = v_phone
  LIMIT 1;

  SELECT count(*)
  INTO v_rto_count
  FROM public.thrift_sales_invoices inv
  WHERE inv.tenant_id = p_tenant_id
    AND inv.close_reason = 'RTO'
    AND (
      (v_customer_id IS NOT NULL AND inv.customer_id = v_customer_id)
      OR public.normalize_thrift_phone(inv.customer_phone) = v_phone
    );

  SELECT coalesce(jsonb_agg(row_data ORDER BY sort_at DESC, sort_id DESC), '[]'::jsonb)
  INTO v_rtos
  FROM (
    SELECT
      jsonb_build_object(
        'kind', 'RTO',
        'invoice_id', inv.id,
        'invoice_number', inv.invoice_number,
        'at', COALESCE(inv.reverted_at, inv.economics_closed_at, inv.updated_at),
        'total_invoice_amount', inv.total_invoice_amount
      ) AS row_data,
      COALESCE(inv.reverted_at, inv.economics_closed_at, inv.updated_at) AS sort_at,
      inv.id AS sort_id
    FROM public.thrift_sales_invoices inv
    WHERE inv.tenant_id = p_tenant_id
      AND inv.close_reason = 'RTO'
      AND (
        (v_customer_id IS NOT NULL AND inv.customer_id = v_customer_id)
        OR public.normalize_thrift_phone(inv.customer_phone) = v_phone
      )
    ORDER BY sort_at DESC, sort_id DESC
    LIMIT 20
  ) t;

  SELECT count(*)
  INTO v_return_count
  FROM public.thrift_sales_returns r
  JOIN public.thrift_sales_invoices inv
    ON inv.id = r.invoice_id
   AND inv.tenant_id = r.tenant_id
  WHERE r.tenant_id = p_tenant_id
    AND (
      (v_customer_id IS NOT NULL AND inv.customer_id = v_customer_id)
      OR public.normalize_thrift_phone(inv.customer_phone) = v_phone
    );

  SELECT coalesce(jsonb_agg(row_data ORDER BY sort_at DESC, sort_id DESC), '[]'::jsonb)
  INTO v_returns
  FROM (
    SELECT
      jsonb_build_object(
        'kind', 'CUSTOMER_RETURN',
        'return_id', r.id,
        'return_number', r.return_number,
        'invoice_id', r.invoice_id,
        'invoice_number', inv.invoice_number,
        'at', r.created_at,
        'refund_amount', r.refund_amount,
        'line_count', (
          SELECT count(*)::INT
          FROM public.thrift_sales_return_items ri
          WHERE ri.return_id = r.id
        ),
        'has_damaged', EXISTS (
          SELECT 1
          FROM public.thrift_sales_return_items ri
          WHERE ri.return_id = r.id
            AND ri.condition = 'DAMAGED'
        )
      ) AS row_data,
      r.created_at AS sort_at,
      r.id AS sort_id
    FROM public.thrift_sales_returns r
    JOIN public.thrift_sales_invoices inv
      ON inv.id = r.invoice_id
     AND inv.tenant_id = r.tenant_id
    WHERE r.tenant_id = p_tenant_id
      AND (
        (v_customer_id IS NOT NULL AND inv.customer_id = v_customer_id)
        OR public.normalize_thrift_phone(inv.customer_phone) = v_phone
      )
    ORDER BY sort_at DESC, sort_id DESC
    LIMIT 20
  ) t;

  RETURN jsonb_build_object(
    'customer_id', v_customer_id,
    'rto_count', v_rto_count,
    'return_count', v_return_count,
    'rtos', v_rtos,
    'returns', v_returns
  );
END;
$$;

COMMENT ON FUNCTION public.get_thrift_customer_sales_risk(BIGINT, TEXT) IS
  'Customer RTO + post-pay return history by phone for create-sale risk panel. Separate lists, dated DESC, max 20 each.';

REVOKE ALL ON FUNCTION public.get_thrift_customer_sales_risk(BIGINT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_thrift_customer_sales_risk(BIGINT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_thrift_customer_sales_risk(BIGINT, TEXT) TO service_role;

COMMIT;
