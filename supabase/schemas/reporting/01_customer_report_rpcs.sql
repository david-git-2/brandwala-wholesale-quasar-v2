-- Customers report (reporting_treasury): list, header, cursor sections.

CREATE OR REPLACE FUNCTION public.list_customers_report(
  p_tenant_id bigint,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 30,
  p_cursor text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_books_id bigint;
  v_lim integer;
  v_search text;
  v_cursor_id bigint;
  v_items jsonb := '[]'::jsonb;
  v_next_cursor text;
BEGIN
  IF p_tenant_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'tenant_id is required');
  END IF;

  v_books_id := public.resolve_books_tenant_id(p_tenant_id);

  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authorized');
  END IF;

  v_lim := greatest(least(coalesce(p_limit, 30), 100), 1);
  v_search := nullif(trim(coalesce(p_search, '')), '');
  v_cursor_id := nullif(trim(coalesce(p_cursor, '')), '')::bigint;

  SELECT coalesce(jsonb_agg(row_json ORDER BY sort_id DESC), '[]'::jsonb)
  INTO v_items
  FROM (
    SELECT
      cg.id AS sort_id,
      jsonb_build_object(
        'customer_group_id', cg.id,
        'profile_id', bp.id,
        'name', cg.name,
        'phone', nullif(concat_ws(' ', bp.phone_country_code, bp.phone), ''),
        'is_active', cg.is_active,
        'member_count', coalesce(mem.cnt, 0::bigint),
        'still_due', coalesce(due.still_due, 0.00),
        'store_credit_balance', coalesce(wa.available_balance, 0.00),
        'created_at', cg.created_at
      ) AS row_json
    FROM public.customer_groups cg
    LEFT JOIN public.profiles bp
      ON bp.customer_group_id = cg.id
     AND bp.tenant_id = v_books_id
     AND bp.profile_type = 'customer'::public.profile_party_type
     AND bp.deleted_at IS NULL
    LEFT JOIN (
      SELECT cgm.customer_group_id AS c_group_id, count(*)::bigint AS cnt
      FROM public.customer_group_members cgm
      GROUP BY cgm.customer_group_id
    ) mem ON mem.c_group_id = cg.id
    LEFT JOIN public.cashbook_accounts wa
      ON wa.tenant_id = v_books_id
     AND wa.entity_type = 'customer'
     AND wa.profile_id = bp.id
     AND wa.currency_code = 'BDT'
    LEFT JOIN LATERAL (
      SELECT round(coalesce(sum(b.due_amount), 0), 2)::numeric(12, 2) AS still_due
      FROM public.profiles pr
      JOIN public.bills b ON b.profile_id = pr.id
      WHERE pr.customer_group_id = cg.id
        AND pr.tenant_id = v_books_id
        AND pr.profile_type = 'customer'::public.profile_party_type
        AND b.invoice_status = 'issued'::public.global_invoice_status
        AND b.document_kind = 'standard'::public.bill_document_kind
    ) due ON true
    WHERE cg.tenant_id = v_books_id
      AND cg.deleted_at IS NULL
      AND (
        v_search IS NULL
        OR cg.name ILIKE '%' || v_search || '%'
        OR bp.name ILIKE '%' || v_search || '%'
        OR bp.phone ILIKE '%' || v_search || '%'
        OR bp.email ILIKE '%' || v_search || '%'
      )
      AND (v_cursor_id IS NULL OR cg.id < v_cursor_id)
    ORDER BY cg.id DESC
    LIMIT v_lim
  ) q;

  IF jsonb_array_length(v_items) = v_lim THEN
    v_next_cursor := (v_items->(v_lim - 1)->>'customer_group_id');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'items', v_items,
    'next_cursor', v_next_cursor
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_customer_report_header(
  p_tenant_id bigint,
  p_customer_group_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_books_id bigint;
  v_group public.customer_groups;
  v_profile_id bigint;
  v_profile_ids bigint[];
  v_still_due numeric(12, 2) := 0;
  v_total_billed numeric(12, 2) := 0;
  v_settlement numeric(12, 2) := 0;
  v_collected_cash numeric(12, 2) := 0;
  v_wallet_applied numeric(12, 2) := 0;
  v_store_credit numeric(15, 4) := 0;
  v_unallocated numeric(12, 2) := 0;
  v_members jsonb := '[]'::jsonb;
  v_shop_access jsonb := '[]'::jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_customer_group_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'tenant and customer group are required');
  END IF;

  v_books_id := public.resolve_books_tenant_id(p_tenant_id);

  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authorized');
  END IF;

  SELECT *
  INTO v_group
  FROM public.customer_groups cg
  WHERE cg.id = p_customer_group_id
    AND cg.tenant_id = v_books_id
    AND cg.deleted_at IS NULL;

  IF v_group.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'customer group not found');
  END IF;

  SELECT
    coalesce(array_agg(pr.id ORDER BY pr.id), '{}'::bigint[]),
    (array_agg(pr.id ORDER BY pr.id))[1]
  INTO v_profile_ids, v_profile_id
  FROM public.profiles pr
  WHERE pr.customer_group_id = p_customer_group_id
    AND pr.tenant_id = v_books_id
    AND pr.profile_type = 'customer'::public.profile_party_type
    AND pr.deleted_at IS NULL;

  IF v_profile_id IS NOT NULL THEN
    SELECT
      coalesce(sum(b.due_amount), 0.00),
      coalesce(sum(b.total_amount), 0.00),
      coalesce(sum(b.written_off_amount), 0.00)
    INTO v_still_due, v_total_billed, v_settlement
    FROM public.bills b
    WHERE b.profile_id = ANY(v_profile_ids)
      AND b.invoice_status = 'issued'::public.global_invoice_status
      AND b.document_kind = 'standard'::public.bill_document_kind;

    SELECT
      coalesce(sum(pa.amount) FILTER (
        WHERE coalesce(py.method, '') <> 'store_credit'
          AND coalesce(py.source, '') <> 'store_credit'
      ), 0.00),
      coalesce(sum(pa.amount) FILTER (
        WHERE coalesce(py.method, '') = 'store_credit'
          OR coalesce(py.source, '') = 'store_credit'
      ), 0.00)
    INTO v_collected_cash, v_wallet_applied
    FROM public.pay_allocations pa
    JOIN public.pays py ON py.id = pa.payment_id
    JOIN public.bills b ON b.id = coalesce(pa.bill_id, pa.global_invoice_id)
    WHERE b.profile_id = ANY(v_profile_ids)
      AND py.voided_at IS NULL;

    SELECT coalesce(wa.available_balance, 0.0000)
    INTO v_store_credit
    FROM public.cashbook_accounts wa
    WHERE wa.tenant_id = v_books_id
      AND wa.entity_type = 'customer'
      AND wa.profile_id = v_profile_id
      AND wa.currency_code = 'BDT';

    SELECT coalesce(sum(py.unallocated_amount), 0.00)
    INTO v_unallocated
    FROM public.pays py
    WHERE py.profile_id = ANY(v_profile_ids)
      AND py.voided_at IS NULL;
  END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  INTO v_members
  FROM (
    SELECT
      cgm.id,
      cgm.name,
      cgm.email,
      cgm.role,
      cgm.is_active,
      cgm.created_at
    FROM public.customer_group_members cgm
    WHERE cgm.customer_group_id = p_customer_group_id
    ORDER BY cgm.created_at ASC, cgm.id ASC
    LIMIT 20
  ) r;

  SELECT coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  INTO v_shop_access
  FROM (
    SELECT
      s.id AS shop_id,
      s.name AS shop_name,
      s.shop_type::text AS shop_type,
      st.id AS shop_tenant_id,
      st.name AS shop_tenant_name,
      scga.status,
      scga.credit_limit_amount
    FROM public.shop_customer_group_access scga
    JOIN public.shops s ON s.id = scga.shop_id
    JOIN public.tenants st ON st.id = s.tenant_id
    WHERE scga.customer_group_id = p_customer_group_id
    ORDER BY st.name, s.name
    LIMIT 20
  ) r;

  RETURN jsonb_build_object(
    'success', true,
    'customer_group_id', v_group.id,
    'group_name', v_group.name,
    'profile_id', v_profile_id,
    'phone', (
      SELECT nullif(concat_ws(' ', bp.phone_country_code, bp.phone), '')
      FROM public.profiles bp
      WHERE bp.id = v_profile_id
    ),
    'email', (SELECT bp.email FROM public.profiles bp WHERE bp.id = v_profile_id),
    'address', (SELECT bp.address FROM public.profiles bp WHERE bp.id = v_profile_id),
    'is_active', v_group.is_active,
    'accent_color', v_group.accent_color,
    'created_at', v_group.created_at,
    'still_due', v_still_due,
    'total_billed', v_total_billed,
    'collected_cash', v_collected_cash,
    'wallet_applied', v_wallet_applied,
    'settlement', v_settlement,
    'store_credit_balance', v_store_credit,
    'unallocated_payments', v_unallocated,
    'members', v_members,
    'shop_access', v_shop_access
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.list_customer_report_section(
  p_tenant_id bigint,
  p_customer_group_id bigint,
  p_kind text,
  p_limit integer DEFAULT 30,
  p_cursor text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_books_id bigint;
  v_lim integer;
  v_profile_ids bigint[];
  v_items jsonb := '[]'::jsonb;
  v_next_cursor text;
  v_cursor_id bigint;
  v_cursor_uuid uuid;
  v_kind text;
BEGIN
  IF p_tenant_id IS NULL OR p_customer_group_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'tenant and customer group are required');
  END IF;

  v_kind := lower(trim(coalesce(p_kind, '')));
  IF v_kind NOT IN ('payments', 'orders', 'bills', 'ledger') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid kind');
  END IF;

  v_books_id := public.resolve_books_tenant_id(p_tenant_id);

  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'Not authorized');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.customer_groups cg
    WHERE cg.id = p_customer_group_id
      AND cg.tenant_id = v_books_id
      AND cg.deleted_at IS NULL
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'customer group not found');
  END IF;

  SELECT coalesce(array_agg(pr.id ORDER BY pr.id), '{}'::bigint[])
  INTO v_profile_ids
  FROM public.profiles pr
  WHERE pr.customer_group_id = p_customer_group_id
    AND pr.tenant_id = v_books_id
    AND pr.profile_type = 'customer'::public.profile_party_type
    AND pr.deleted_at IS NULL;

  v_lim := greatest(least(coalesce(p_limit, 30), 100), 1);

  IF v_kind = 'payments' THEN
    v_cursor_id := nullif(trim(coalesce(p_cursor, '')), '')::bigint;

    SELECT coalesce(jsonb_agg(row_json ORDER BY sort_payment_date DESC, sort_id DESC), '[]'::jsonb)
    INTO v_items
    FROM (
      SELECT
        py.payment_date AS sort_payment_date,
        py.id AS sort_id,
        jsonb_build_object(
          'payment_id', py.id,
          'payment_date', py.payment_date,
          'method', py.method,
          'amount', py.amount,
          'unallocated_amount', py.unallocated_amount,
          'purpose_code', py.source,
          'source', py.source,
          'voided_at', py.voided_at,
          'note', py.note
        ) AS row_json
      FROM public.pays py
      WHERE (
          py.profile_id = ANY(v_profile_ids)
          OR py.from_profile_id = ANY(v_profile_ids)
        )
        AND py.tenant_id = v_books_id
        AND (v_cursor_id IS NULL OR py.id < v_cursor_id)
      ORDER BY py.payment_date DESC, py.id DESC
      LIMIT v_lim
    ) q;

    IF jsonb_array_length(v_items) = v_lim THEN
      v_next_cursor := (v_items->(v_lim - 1)->>'payment_id');
    END IF;
  ELSIF v_kind = 'orders' THEN
    v_cursor_id := nullif(trim(coalesce(p_cursor, '')), '')::bigint;

    SELECT coalesce(jsonb_agg(row_json ORDER BY sort_id DESC), '[]'::jsonb)
    INTO v_items
    FROM (
      SELECT
        so.id AS sort_id,
        jsonb_build_object(
          'order_id', so.id,
          'order_no', so.order_no,
          'name', so.name,
          'status', so.status,
          'shop_id', so.shop_id,
          'shop_name', sh.name,
          'cod_collect_amount', so.cod_collect_amount,
          'payout_settlement_status', so.payout_settlement_status,
          'recipient_name', so.recipient_name,
          'recipient_phone', so.recipient_phone,
          'created_at', so.created_at
        ) AS row_json
      FROM public.shop_orders so
      LEFT JOIN public.shops sh ON sh.id = so.shop_id
      WHERE so.customer_group_id = p_customer_group_id
        AND so.tenant_id = v_books_id
        AND (v_cursor_id IS NULL OR so.id < v_cursor_id)
      ORDER BY so.id DESC
      LIMIT v_lim
    ) q;

    IF jsonb_array_length(v_items) = v_lim THEN
      v_next_cursor := (v_items->(v_lim - 1)->>'order_id');
    END IF;
  ELSIF v_kind = 'bills' THEN
    v_cursor_id := nullif(trim(coalesce(p_cursor, '')), '')::bigint;

    IF coalesce(cardinality(v_profile_ids), 0) = 0 THEN
      v_items := '[]'::jsonb;
    ELSE
      SELECT coalesce(jsonb_agg(row_json ORDER BY sort_id DESC), '[]'::jsonb)
      INTO v_items
      FROM (
        SELECT
          b.id AS sort_id,
          jsonb_build_object(
            'bill_id', b.id,
            'invoice_no', b.invoice_no,
            'invoice_status', b.invoice_status::text,
            'payment_status', b.payment_status,
            'total_amount', b.total_amount,
            'paid_amount', b.paid_amount,
            'due_amount', b.due_amount,
            'written_off_amount', b.written_off_amount,
            'shop_order_id', b.shop_order_id,
            'invoice_date', b.invoice_date
          ) AS row_json
        FROM public.bills b
        WHERE b.profile_id = ANY(v_profile_ids)
          AND b.invoice_status = 'issued'::public.global_invoice_status
          AND b.document_kind = 'standard'::public.bill_document_kind
          AND (v_cursor_id IS NULL OR b.id < v_cursor_id)
        ORDER BY b.id DESC
        LIMIT v_lim
      ) q;
    END IF;

    IF jsonb_array_length(v_items) = v_lim THEN
      v_next_cursor := (v_items->(v_lim - 1)->>'bill_id');
    END IF;
  ELSIF v_kind = 'ledger' THEN
    v_cursor_uuid := nullif(trim(coalesce(p_cursor, '')), '')::uuid;

    IF coalesce(cardinality(v_profile_ids), 0) = 0 THEN
      v_items := '[]'::jsonb;
    ELSE
      SELECT coalesce(jsonb_agg(row_json ORDER BY sort_created DESC, sort_id DESC), '[]'::jsonb)
      INTO v_items
      FROM (
        SELECT
          l.created_at AS sort_created,
          l.id AS sort_id,
          jsonb_build_object(
            'entry_id', l.id,
            'type', l.type,
            'amount', l.amount,
            'balance_after', l.balance_after,
            'currency_code', l.currency_code,
            'source_type', l.source_type,
            'source_id', l.source_id,
            'created_at', l.created_at,
            'label', coalesce(
              l.metadata->>'label',
              l.metadata->>'purpose',
              l.metadata->>'transaction_type',
              'Entry'
            ),
            'payment_id', l.metadata->>'payment_id'
          ) AS row_json
        FROM public.cashbook_entries l
        WHERE l.tenant_id = v_books_id
          AND l.entity_type = 'customer'
          AND l.entity_id = ANY(v_profile_ids)
          AND (
            v_cursor_uuid IS NULL
            OR l.created_at < (SELECT l2.created_at FROM public.cashbook_entries l2 WHERE l2.id = v_cursor_uuid)
            OR (
              l.created_at = (SELECT l2.created_at FROM public.cashbook_entries l2 WHERE l2.id = v_cursor_uuid)
              AND l.id::text < v_cursor_uuid::text
            )
          )
        ORDER BY l.created_at DESC, l.id DESC
        LIMIT v_lim
      ) q;
    END IF;

    IF jsonb_array_length(v_items) = v_lim THEN
      v_next_cursor := (v_items->(v_lim - 1)->>'entry_id');
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'kind', v_kind,
    'items', v_items,
    'next_cursor', v_next_cursor
  );
END;
$$;

GRANT ALL ON FUNCTION public.list_customers_report(bigint, text, integer, text) TO authenticated;
GRANT ALL ON FUNCTION public.list_customers_report(bigint, text, integer, text) TO service_role;

GRANT ALL ON FUNCTION public.get_customer_report_header(bigint, bigint) TO authenticated;
GRANT ALL ON FUNCTION public.get_customer_report_header(bigint, bigint) TO service_role;

GRANT ALL ON FUNCTION public.list_customer_report_section(bigint, bigint, text, integer, text) TO authenticated;
GRANT ALL ON FUNCTION public.list_customer_report_section(bigint, bigint, text, integer, text) TO service_role;