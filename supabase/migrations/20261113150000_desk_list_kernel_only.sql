-- B2: desk bills list reads money_kernel.bills only (no public.bills merge).

CREATE OR REPLACE FUNCTION public.list_bills_desk_page(
  p_tenant_id bigint,
  p_to_profile_type text DEFAULT NULL,
  p_from_profile_id bigint DEFAULT NULL,
  p_invoice_status text DEFAULT NULL,
  p_payment_status text DEFAULT NULL,
  p_quick_filter text DEFAULT NULL,
  p_page_size integer DEFAULT 25,
  p_cursor bigint DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_parent_id bigint;
  v_limit integer;
  v_data jsonb;
  v_fetched integer;
  v_has_more boolean := false;
  v_next_cursor bigint;
  v_to_type text := nullif(trim(coalesce(p_to_profile_type, '')), '');
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  IF NOT (
    public.membership_has_module_action(v_parent_id, 'global_invoice', 'view')
    OR public.user_can_manage_books_tenant(v_parent_id)
  ) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  v_limit := greatest(COALESCE(p_page_size, 25), 1);

  SELECT COALESCE(jsonb_agg(row_json ORDER BY sort_id DESC), '[]'::jsonb)
  INTO v_data
  FROM (
    SELECT sort_id, row_json
    FROM (
      SELECT
        b.id AS sort_id,
        jsonb_build_object(
          'id', b.id,
          'invoice_no', b.invoice_no,
          'invoice_date', b.invoice_date,
          'invoice_type', public._desk_kernel_kind_invoice_type(b.kind),
          'invoice_status', CASE b.status WHEN 'draft' THEN 'draft' WHEN 'voided' THEN 'voided' ELSE 'issued' END,
          'payment_status', public._desk_kernel_status_payment(b.status, b.due_amount),
          'total_amount', b.total_amount,
          'due_amount', b.due_amount,
          'currency_code', upper(b.currency_code),
          'from_profile_id', b.from_profile_id,
          'from_profile_name', from_pr.name,
          'from_profile_type', from_pr.profile_type,
          'to_profile_id', b.to_profile_id,
          'to_profile_name', to_pr.name,
          'to_profile_type', to_pr.profile_type,
          'profile_name', to_pr.name,
          'ap_kind', COALESCE(b.meta->>'ap_kind', NULL),
          'document_kind', CASE b.kind WHEN 'credit_note' THEN 'credit_note' WHEN 'debit_note' THEN 'debit_note' ELSE 'standard' END,
          'parent_bill_id', b.parent_bill_id,
          'spine', 'kernel',
          'kind', b.kind,
          'list_status', public._desk_list_status_slug(
            CASE b.status WHEN 'draft' THEN 'draft' WHEN 'voided' THEN 'voided' ELSE 'issued' END,
            public._desk_kernel_status_payment(b.status, b.due_amount),
            b.due_amount,
            b.status
          )
        ) AS row_json
      FROM money_kernel.bills b
      INNER JOIN public.profiles to_pr
        ON to_pr.id = b.to_profile_id AND to_pr.tenant_id = b.tenant_id
      LEFT JOIN public.profiles from_pr
        ON from_pr.id = b.from_profile_id AND from_pr.tenant_id = b.tenant_id
      WHERE b.tenant_id = v_parent_id
        AND (v_to_type IS NULL OR to_pr.profile_type::text = v_to_type)
        AND (p_from_profile_id IS NULL OR b.from_profile_id = p_from_profile_id)
        AND (p_payment_status IS NULL OR public._desk_kernel_status_payment(b.status, b.due_amount) = p_payment_status)
        AND (
          p_invoice_status IS NULL
          OR (p_invoice_status = 'draft' AND b.status = 'draft')
          OR (p_invoice_status = 'voided' AND b.status = 'voided')
          OR (p_invoice_status = 'issued' AND b.status IN ('issued', 'partial', 'paid', 'written_off'))
        )
        AND (
          p_quick_filter IS NULL OR p_quick_filter = ''
          OR (p_quick_filter = 'paid' AND (b.status IN ('paid', 'written_off') OR b.due_amount <= 0))
          OR (p_quick_filter = 'unpaid' AND b.due_amount > 0 AND b.status NOT IN ('voided', 'draft', 'paid', 'written_off'))
        )
        AND (p_cursor IS NULL OR b.id < p_cursor)
    ) combined
    ORDER BY sort_id DESC
    LIMIT v_limit + 1
  ) q;

  v_fetched := COALESCE(jsonb_array_length(v_data), 0);
  IF v_fetched > v_limit THEN
    v_has_more := true;
    v_data := COALESCE(
      (
        SELECT jsonb_agg(elem ORDER BY (elem->>'id')::bigint DESC)
        FROM (
          SELECT elem
          FROM jsonb_array_elements(v_data) AS elem
          LIMIT v_limit
        ) trimmed
      ),
      '[]'::jsonb
    );
  END IF;

  IF COALESCE(jsonb_array_length(v_data), 0) > 0 THEN
    v_next_cursor := (v_data->(jsonb_array_length(v_data) - 1)->>'id')::bigint;
  ELSE
    v_next_cursor := NULL;
  END IF;

  IF NOT v_has_more THEN
    v_next_cursor := NULL;
  END IF;

  RETURN jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'has_more', v_has_more,
      'next_cursor', v_next_cursor
    )
  );
END;
$$;
