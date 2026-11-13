-- Profile activity: kernel + legacy public pays
CREATE OR REPLACE FUNCTION public.list_profile_activity_for_staff(
  p_tenant_id bigint,
  p_entity_type text,
  p_entity_id bigint,
  p_kind text DEFAULT 'payments',
  p_limit integer DEFAULT 50,
  p_cursor text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_books_id bigint;
  v_ledger_entity_id bigint;
  v_lim integer;
  v_items jsonb := '[]'::jsonb;
  v_next_cursor text;
  v_cursor_pay_id bigint;
  v_cursor_bill_id bigint;
  v_cursor_created timestamptz;
  v_cursor_entry_id uuid;
  v_money_profile_id bigint;
BEGIN
  IF p_kind NOT IN ('payments', 'custody', 'bills') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid kind');
  END IF;

  IF p_entity_type NOT IN ('tenant', 'customer', 'vendor', 'courier', 'cargo_company', 'investor') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid entity_type');
  END IF;

  v_books_id := public.resolve_books_tenant_id(p_tenant_id);
  v_money_profile_id := public._kernel_cashbook_money_profile_id(v_books_id, p_entity_type, p_entity_id);

  IF NOT (
    public.cashbook_staff_can_view(p_tenant_id)
    OR public.membership_has_module_action(v_books_id, 'payments', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'payments', 'view')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  v_lim := greatest(least(coalesce(p_limit, 50), 200), 1);
  v_ledger_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN
    v_ledger_entity_id := v_books_id;
  END IF;

  IF p_kind = 'payments' THEN
    v_cursor_pay_id := NULLIF(btrim(coalesce(p_cursor, '')), '')::bigint;

    IF v_money_profile_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM money_kernel.cashbooks a
      WHERE a.tenant_id = v_books_id AND a.profile_id = v_money_profile_id
    ) THEN
      SELECT coalesce(jsonb_agg(row_data ORDER BY sort_payment_date DESC, sort_id DESC), '[]'::jsonb)
      INTO v_items
      FROM (
        SELECT merged.row_data, merged.sort_payment_date, merged.sort_id
        FROM (
          SELECT
            public._kernel_profile_pay_row_json(py, v_money_profile_id) AS row_data,
            py.payment_date AS sort_payment_date,
            py.id AS sort_id
          FROM money_kernel.pays py
          WHERE py.tenant_id = v_books_id
            AND py.kind IN ('deposit', 'withdrawal', 'transfer')
            AND py.status = 'posted'
            AND (
              py.from_cash_bundle_id IN (
                SELECT cb.id
                  FROM money_kernel.cash_bundles cb
                  JOIN money_kernel.cash_locations cl ON cl.id = cb.cash_location_id
                  JOIN money_kernel.cashbooks a ON a.id = cl.cashbook_id
                 WHERE a.tenant_id = v_books_id
                   AND a.profile_id = v_money_profile_id
              )
              OR py.to_cash_bundle_id IN (
                SELECT cb.id
                  FROM money_kernel.cash_bundles cb
                  JOIN money_kernel.cash_locations cl ON cl.id = cb.cash_location_id
                  JOIN money_kernel.cashbooks a ON a.id = cl.cashbook_id
                 WHERE a.tenant_id = v_books_id
                   AND a.profile_id = v_money_profile_id
              )
            )

          UNION ALL

          SELECT
            public._kernel_pay_row_json(
              py,
              CASE
                WHEN p_entity_type = 'tenant' THEN public._kernel_pay_direction_tenant(py.source)
                ELSE public._kernel_pay_direction_party(py.source, p_entity_type)
              END,
              CASE
                WHEN p_entity_type = 'tenant' THEN
                  coalesce((SELECT pr.name FROM public.profiles pr WHERE pr.id = py.profile_id), '')
                ELSE NULL
              END,
              CASE WHEN p_entity_type = 'tenant' THEN 'tenant' ELSE 'party' END
            ) AS row_data,
            py.payment_date AS sort_payment_date,
            py.id AS sort_id
          FROM public.pays py
          WHERE py.tenant_id = v_books_id
            AND py.voided_at IS NULL
            AND (
              p_entity_type = 'tenant'
              OR py.from_profile_id = v_money_profile_id
              OR py.to_profile_id = v_money_profile_id
              OR (
                py.from_profile_id IS NULL
                AND py.to_profile_id IS NULL
                AND py.profile_id = v_money_profile_id
              )
            )
        ) merged
        WHERE v_cursor_pay_id IS NULL OR merged.sort_id < v_cursor_pay_id
        ORDER BY merged.sort_payment_date DESC, merged.sort_id DESC
        LIMIT v_lim + 1
      ) pay_rows;

    ELSIF p_entity_type = 'tenant' THEN
      SELECT coalesce(jsonb_agg(row_data ORDER BY sort_payment_date DESC, sort_id DESC), '[]'::jsonb)
      INTO v_items
      FROM (
        SELECT
          public._kernel_pay_row_json(
            py,
            public._kernel_pay_direction_tenant(py.source),
            coalesce((SELECT pr.name FROM public.profiles pr WHERE pr.id = py.profile_id), ''),
            'tenant'
          ) AS row_data,
          py.payment_date AS sort_payment_date,
          py.id AS sort_id
        FROM public.pays py
        WHERE py.tenant_id = v_books_id
          AND py.voided_at IS NULL
          AND (v_cursor_pay_id IS NULL OR py.id < v_cursor_pay_id)
        ORDER BY py.payment_date DESC, py.id DESC
        LIMIT v_lim + 1
      ) pay_rows;

    ELSE
      SELECT coalesce(jsonb_agg(row_data ORDER BY sort_payment_date DESC, sort_id DESC), '[]'::jsonb)
      INTO v_items
      FROM (
        SELECT
          public._kernel_pay_row_json(
            py,
            public._kernel_pay_direction_party(py.source, p_entity_type),
            NULL,
            'party'
          ) AS row_data,
          py.payment_date AS sort_payment_date,
          py.id AS sort_id
        FROM public.pays py
        WHERE py.tenant_id = v_books_id
          AND (
            py.from_profile_id = coalesce(v_money_profile_id, p_entity_id)
            OR py.to_profile_id = coalesce(v_money_profile_id, p_entity_id)
            OR (
              py.from_profile_id IS NULL
              AND py.to_profile_id IS NULL
              AND py.profile_id = coalesce(v_money_profile_id, p_entity_id)
            )
          )
          AND py.voided_at IS NULL
          AND (v_cursor_pay_id IS NULL OR py.id < v_cursor_pay_id)
        ORDER BY py.payment_date DESC, py.id DESC
        LIMIT v_lim + 1
      ) pay_rows;
    END IF;

    IF jsonb_array_length(v_items) > v_lim THEN
      v_next_cursor := (v_items->(v_lim - 1)->>'id');
      v_items := (
        SELECT coalesce(jsonb_agg(elem), '[]'::jsonb)
        FROM jsonb_array_elements(v_items) WITH ORDINALITY AS t(elem, ord)
        WHERE ord <= v_lim
      );
    END IF;

  ELSIF p_kind = 'custody' THEN
    IF coalesce(btrim(p_cursor), '') <> '' THEN
      v_cursor_entry_id := p_cursor::uuid;
    END IF;

    SELECT coalesce(jsonb_agg(row_data ORDER BY sort_created DESC, sort_id DESC), '[]'::jsonb)
    INTO v_items
    FROM (
      SELECT
        jsonb_build_object(
          'id', l.id::text,
          'type', l.type,
          'amount', l.amount,
          'balance_after', l.balance_after,
          'source_type', l.source_type,
          'source_id', l.source_id,
          'created_at', l.created_at,
          'is_reversal', (l.metadata ? 'reversal_of'),
          'metadata', coalesce(l.metadata, '{}'::jsonb),
          'cashbook_point_id', l.cashbook_point_id,
          'cashbook_point_name', cp.name
        ) AS row_data,
        l.created_at AS sort_created,
        l.id AS sort_id
      FROM public.cashbook_entries l
      LEFT JOIN public.cashbook_points cp ON cp.id = l.cashbook_point_id
      WHERE l.tenant_id = v_books_id
        AND l.entity_type = p_entity_type
        AND l.entity_id = v_ledger_entity_id
        AND (v_cursor_entry_id IS NULL OR l.created_at < (
          SELECT l2.created_at FROM public.cashbook_entries l2 WHERE l2.id = v_cursor_entry_id
        ))
      ORDER BY l.created_at DESC, l.id DESC
      LIMIT v_lim + 1
    ) ledger_rows;

    IF jsonb_array_length(v_items) > v_lim THEN
      v_next_cursor := (v_items->(v_lim - 1)->>'id');
      v_items := (
        SELECT coalesce(jsonb_agg(elem), '[]'::jsonb)
        FROM jsonb_array_elements(v_items) WITH ORDINALITY AS t(elem, ord)
        WHERE ord <= v_lim
      );
    END IF;

  ELSIF p_kind = 'bills' THEN
    v_cursor_bill_id := NULLIF(btrim(coalesce(p_cursor, '')), '')::bigint;

    SELECT coalesce(jsonb_agg(row_data ORDER BY sort_id DESC), '[]'::jsonb)
    INTO v_items
    FROM (
      SELECT
        jsonb_build_object(
          'bill_id', s.bill_id,
          'invoice_no', s.invoice_no,
          'total_amount', s.total_amount,
          'open_books', s.open_books,
          'due_date', s.due_date,
          'invoice_type', s.invoice_type,
          'document_kind', s.document_kind,
          'lifecycle_status', s.lifecycle_status,
          'payment_status', s.payment_status,
          'profile_id', s.profile_id,
          'from_profile_id', s.from_profile_id,
          'to_profile_id', s.to_profile_id
        ) AS row_data,
        s.bill_id AS sort_id
      FROM public.v_kernel_bill_summaries s
      WHERE s.tenant_id = v_books_id
        AND s.lifecycle_status = 'issued'::public.bill_lifecycle_status
        AND (
          (p_entity_type = 'tenant' AND s.tenant_id = v_books_id)
          OR (
            p_entity_type <> 'tenant'
            AND (
              s.profile_id = coalesce(v_money_profile_id, p_entity_id)
              OR s.from_profile_id = coalesce(v_money_profile_id, p_entity_id)
              OR s.to_profile_id = coalesce(v_money_profile_id, p_entity_id)
            )
          )
        )
        AND (v_cursor_bill_id IS NULL OR s.bill_id < v_cursor_bill_id)
      ORDER BY s.bill_id DESC
      LIMIT v_lim + 1
    ) bill_rows;

    IF jsonb_array_length(v_items) > v_lim THEN
      v_next_cursor := (v_items->(v_lim - 1)->>'bill_id');
      v_items := (
        SELECT coalesce(jsonb_agg(elem), '[]'::jsonb)
        FROM jsonb_array_elements(v_items) WITH ORDINALITY AS t(elem, ord)
        WHERE ord <= v_lim
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'kind', p_kind,
    'items', v_items,
    'next_cursor', v_next_cursor
  );
END;
$$;

