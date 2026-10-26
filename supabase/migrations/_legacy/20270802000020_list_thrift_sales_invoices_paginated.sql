-- Paginated thrift sales invoice list API: { data, meta: { page, total, page_size, total_pages } }

CREATE OR REPLACE FUNCTION public.list_thrift_sales_invoices_paginated(
  p_tenant_id BIGINT,
  p_page INTEGER DEFAULT 1,
  p_page_size INTEGER DEFAULT 20,
  p_search TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_page INTEGER := greatest(coalesce(p_page, 1), 1);
  v_page_size INTEGER := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_search TEXT := nullif(trim(coalesce(p_search, '')), '');
  v_total_count BIGINT;
  v_total_pages INTEGER;
  v_data JSONB;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE m.tenant_id = p_tenant_id
      AND lower(trim(m.email)) = public.current_user_email()
      AND m.is_active = true
  ) THEN
    RAISE EXCEPTION 'Not authorized for this tenant';
  END IF;

  SELECT count(*)
  INTO v_total_count
  FROM public.thrift_sales_invoices inv
  WHERE inv.tenant_id = p_tenant_id
    AND (
      v_search IS NULL
      OR coalesce(inv.invoice_number, '') ILIKE '%' || v_search || '%'
      OR coalesce(inv.customer_name, '') ILIKE '%' || v_search || '%'
      OR coalesce(inv.customer_phone, '') ILIKE '%' || v_search || '%'
    );

  SELECT coalesce(jsonb_agg(row_data ORDER BY sort_created_at DESC, sort_id DESC), '[]'::jsonb)
  INTO v_data
  FROM (
    SELECT
      jsonb_build_object(
        'id', inv.id,
        'invoice_number', inv.invoice_number,
        'customer_name', inv.customer_name,
        'customer_phone', inv.customer_phone,
        'date', inv.date,
        'payment_method', inv.payment_method,
        'payment_status', inv.payment_status,
        'total_invoice_amount', inv.total_invoice_amount,
        'created_by', inv.created_by,
        'notes', inv.notes,
        'created_at', inv.created_at,
        'status', inv.status,
        'reverted_at', inv.reverted_at,
        'reverted_by', inv.reverted_by,
        'revert_reason', inv.revert_reason,
        'revert_notes', inv.revert_notes,
        'item_count', (
          SELECT count(*)::INT
          FROM public.thrift_sales_invoice_items si
          WHERE si.invoice_id = inv.id
            AND si.tenant_id = inv.tenant_id
        )
      ) AS row_data,
      inv.created_at AS sort_created_at,
      inv.id AS sort_id
    FROM public.thrift_sales_invoices inv
    WHERE inv.tenant_id = p_tenant_id
      AND (
        v_search IS NULL
        OR coalesce(inv.invoice_number, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.customer_name, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.customer_phone, '') ILIKE '%' || v_search || '%'
      )
    ORDER BY inv.created_at DESC, inv.id DESC
    OFFSET (v_page - 1) * v_page_size
    LIMIT v_page_size
  ) paged;

  IF v_total_count = 0 THEN
    v_total_pages := 0;
  ELSE
    v_total_pages := ceil(v_total_count::NUMERIC / v_page_size)::INTEGER;
  END IF;

  RETURN jsonb_build_object(
    'data', coalesce(v_data, '[]'::jsonb),
    'meta', jsonb_build_object(
      'page', v_page,
      'total', v_total_count,
      'page_size', v_page_size,
      'total_pages', v_total_pages
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.list_thrift_sales_invoices_paginated(BIGINT, INTEGER, INTEGER, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_thrift_sales_invoices_paginated(BIGINT, INTEGER, INTEGER, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_thrift_sales_invoices_paginated(BIGINT, INTEGER, INTEGER, TEXT) TO service_role;
