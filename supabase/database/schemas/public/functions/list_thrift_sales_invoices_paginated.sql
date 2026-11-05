CREATE FUNCTION public.list_thrift_sales_invoices_paginated (
  p_tenant_id       bigint,
  p_page            integer DEFAULT 1,
  p_page_size       integer DEFAULT 20,
  p_search          text    DEFAULT NULL::text,
  p_payment_status  text    DEFAULT NULL::text,
  p_status          text    DEFAULT NULL::text,
  p_delivery_status text    DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_page INTEGER := greatest(coalesce(p_page, 1), 1);
  v_page_size INTEGER := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_search TEXT := nullif(trim(coalesce(p_search, '')), '');
  v_payment_status TEXT := nullif(upper(trim(coalesce(p_payment_status, ''))), '');
  v_status TEXT := nullif(upper(trim(coalesce(p_status, ''))), '');
  v_delivery_status TEXT := nullif(upper(trim(coalesce(p_delivery_status, ''))), '');
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
    )
    AND (v_payment_status IS NULL OR inv.payment_status = v_payment_status)
    AND (v_status IS NULL OR coalesce(inv.status, 'ACTIVE') = v_status)
    AND (
      v_delivery_status IS NULL
      OR inv.delivery_status = v_delivery_status
    );

  SELECT coalesce(jsonb_agg(row_data ORDER BY sort_created_at DESC, sort_id DESC), '[]'::jsonb)
  INTO v_data
  FROM (
    SELECT
      jsonb_build_object(
        'id', inv.id,
        'invoice_number', inv.invoice_number,
        'sale_channel', inv.sale_channel,
        'customer_id', inv.customer_id,
        'customer_name', inv.customer_name,
        'customer_phone', inv.customer_phone,
        'customer_address', inv.customer_address,
        'date', inv.date,
        'payment_method', inv.payment_method,
        'payment_status', inv.payment_status,
        'delivery_status', inv.delivery_status,
        'total_invoice_amount', inv.total_invoice_amount,
        'courier_amount', inv.courier_amount,
        'courier_paid_by', inv.courier_paid_by,
        'cod_expected', inv.cod_expected,
        'cod_remitted_amount', inv.cod_remitted_amount,
        'cod_remitted_at', inv.cod_remitted_at,
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
      AND (v_payment_status IS NULL OR inv.payment_status = v_payment_status)
      AND (v_status IS NULL OR coalesce(inv.status, 'ACTIVE') = v_status)
      AND (
        v_delivery_status IS NULL
        OR inv.delivery_status = v_delivery_status
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
$function$;

GRANT ALL ON FUNCTION public.list_thrift_sales_invoices_paginated(bigint, integer, integer, text, text, text, text) TO anon;

GRANT ALL ON FUNCTION public.list_thrift_sales_invoices_paginated(bigint, integer, integer, text, text, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.list_thrift_sales_invoices_paginated(bigint, integer, integer, text, text, text, text) TO service_role;