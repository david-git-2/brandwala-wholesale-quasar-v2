CREATE FUNCTION public.list_thrift_sales_returns_paginated (
  p_tenant_id   bigint,
  p_page        integer                  DEFAULT 1,
  p_page_size   integer                  DEFAULT 20,
  p_search      text                     DEFAULT NULL::text,
  p_date_from   timestamp with time zone DEFAULT NULL::timestamp WITH time zone,
  p_date_to     timestamp with time zone DEFAULT NULL::timestamp WITH time zone,
  p_invoice_id  bigint                   DEFAULT NULL::bigint,
  p_has_damaged boolean                  DEFAULT NULL::boolean,
  p_skip_count  boolean                  DEFAULT false
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
  v_total_count BIGINT := 0;
  v_total_pages INTEGER := 0;
  v_data JSONB;
  v_skip_count BOOLEAN := COALESCE(p_skip_count, false);
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'view') THEN
    RAISE EXCEPTION 'List thrift sales returns requires thrift_sales view permission';
  END IF;

  IF NOT v_skip_count THEN
    SELECT count(*)
    INTO v_total_count
    FROM public.thrift_sales_returns r
    JOIN public.thrift_sales_invoices inv
      ON inv.id = r.invoice_id
     AND inv.tenant_id = r.tenant_id
    WHERE r.tenant_id = p_tenant_id
      AND (p_invoice_id IS NULL OR r.invoice_id = p_invoice_id)
      AND (p_date_from IS NULL OR r.created_at >= p_date_from)
      AND (p_date_to IS NULL OR r.created_at <= p_date_to)
      AND (
        v_search IS NULL
        OR coalesce(r.return_number, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.invoice_number, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.customer_name, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.customer_phone, '') ILIKE '%' || v_search || '%'
      )
      AND (
        p_has_damaged IS NULL
        OR (
          p_has_damaged = TRUE
          AND EXISTS (
            SELECT 1
            FROM public.thrift_sales_return_items ri
            WHERE ri.return_id = r.id
              AND ri.condition = 'DAMAGED'
          )
        )
        OR (
          p_has_damaged = FALSE
          AND NOT EXISTS (
            SELECT 1
            FROM public.thrift_sales_return_items ri
            WHERE ri.return_id = r.id
              AND ri.condition = 'DAMAGED'
          )
        )
      );
  END IF;

  SELECT coalesce(jsonb_agg(row_data ORDER BY sort_created_at DESC, sort_id DESC), '[]'::jsonb)
  INTO v_data
  FROM (
    SELECT
      jsonb_build_object(
        'id', r.id,
        'return_number', r.return_number,
        'invoice_id', r.invoice_id,
        'invoice_number', inv.invoice_number,
        'customer_name', inv.customer_name,
        'customer_phone', inv.customer_phone,
        'refund_amount', r.refund_amount,
        'return_courier_amount', r.return_courier_amount,
        'status', r.status,
        'notes', r.notes,
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
        ),
        'created_by', r.created_by,
        'created_at', r.created_at
      ) AS row_data,
      r.created_at AS sort_created_at,
      r.id AS sort_id
    FROM public.thrift_sales_returns r
    JOIN public.thrift_sales_invoices inv
      ON inv.id = r.invoice_id
     AND inv.tenant_id = r.tenant_id
    WHERE r.tenant_id = p_tenant_id
      AND (p_invoice_id IS NULL OR r.invoice_id = p_invoice_id)
      AND (p_date_from IS NULL OR r.created_at >= p_date_from)
      AND (p_date_to IS NULL OR r.created_at <= p_date_to)
      AND (
        v_search IS NULL
        OR coalesce(r.return_number, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.invoice_number, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.customer_name, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.customer_phone, '') ILIKE '%' || v_search || '%'
      )
      AND (
        p_has_damaged IS NULL
        OR (
          p_has_damaged = TRUE
          AND EXISTS (
            SELECT 1
            FROM public.thrift_sales_return_items ri
            WHERE ri.return_id = r.id
              AND ri.condition = 'DAMAGED'
          )
        )
        OR (
          p_has_damaged = FALSE
          AND NOT EXISTS (
            SELECT 1
            FROM public.thrift_sales_return_items ri
            WHERE ri.return_id = r.id
              AND ri.condition = 'DAMAGED'
          )
        )
      )
    ORDER BY r.created_at DESC, r.id DESC
    OFFSET (v_page - 1) * v_page_size
    LIMIT v_page_size
  ) paged;

  IF v_skip_count THEN
    v_total_pages := 0;
  ELSIF v_total_count = 0 THEN
    v_total_pages := 0;
  ELSE
    v_total_pages := ceil(v_total_count::NUMERIC / v_page_size)::INTEGER;
  END IF;

  RETURN jsonb_build_object(
    'data', coalesce(v_data, '[]'::jsonb),
    'meta', jsonb_build_object(
      'page', v_page,
      'total', CASE WHEN v_skip_count THEN NULL ELSE v_total_count END,
      'page_size', v_page_size,
      'total_pages', CASE WHEN v_skip_count THEN NULL ELSE v_total_pages END,
      'skip_count', v_skip_count
    )
  );
END;
$function$;

COMMENT ON FUNCTION public.list_thrift_sales_returns_paginated(bigint,integer,integer,text,timestamp with time zone,timestamp
  with time zone,bigint,boolean,boolean) IS 'Paginated thrift post-pay returns list for hub + invoice history.';

GRANT ALL ON FUNCTION public.list_thrift_sales_returns_paginated(bigint, integer, integer, text, timestamp WITH time zone, timestamp
  WITH time zone, bigint, boolean, boolean) TO anon;

GRANT ALL ON FUNCTION public.list_thrift_sales_returns_paginated(bigint, integer, integer, text, timestamp WITH time zone, timestamp
  WITH time zone, bigint, boolean, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.list_thrift_sales_returns_paginated(bigint, integer, integer, text, timestamp WITH time zone, timestamp
  WITH time zone, bigint, boolean, boolean) TO service_role;