-- Payments profile page: one round-trip for header, due, ledger, and pays.
-- Profile activity list (BP26): two-sided pay reads.

CREATE OR REPLACE FUNCTION public._kernel_pay_direction_tenant(p_source text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_source = ANY (ARRAY[
      'customer_cash'::text,
      'bank'::text,
      'store_credit'::text,
      'courier_remittance'::text
    ]) THEN 'in'
    WHEN p_source = ANY (ARRAY['ap_payout'::text, 'commission'::text, 'owner_withdraw'::text]) THEN 'out'
    WHEN p_source = 'deposit'::text THEN 'in'
    ELSE 'in'
  END;
$$;

CREATE OR REPLACE FUNCTION public._kernel_pay_direction_party(
  p_source text,
  p_entity_type text
) RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN public._kernel_pay_direction_tenant(p_source) = 'in' THEN 'out'
    ELSE 'in'
  END;
$$;

CREATE OR REPLACE FUNCTION public._kernel_cashbook_money_profile_id(
  p_books_id bigint,
  p_entity_type text,
  p_entity_id bigint
) RETURNS bigint
LANGUAGE sql
STABLE
SET search_path TO public
AS $$
  SELECT CASE p_entity_type
    WHEN 'tenant' THEN (
      SELECT pr.id FROM public.profiles pr
      WHERE pr.tenant_id = p_books_id
        AND pr.profile_type = 'tenant'::public.profile_party_type
        AND pr.subject_id = p_books_id
      LIMIT 1
    )
    WHEN 'customer' THEN p_entity_id
    WHEN 'vendor' THEN (
      SELECT pr.id FROM public.profiles pr
      WHERE pr.tenant_id = p_books_id
        AND pr.profile_type = 'vendor'::public.profile_party_type
        AND pr.subject_id = p_entity_id
      LIMIT 1
    )
    WHEN 'cargo_company' THEN (
      SELECT pr.id FROM public.profiles pr
      WHERE pr.tenant_id = p_books_id
        AND pr.profile_type = 'cargo'::public.profile_party_type
        AND pr.subject_id = p_entity_id
      LIMIT 1
    )
    WHEN 'investor' THEN (
      SELECT pr.id FROM public.profiles pr
      WHERE pr.tenant_id = p_books_id
        AND pr.profile_type = 'investor'::public.profile_party_type
        AND pr.subject_id = p_entity_id
      LIMIT 1
    )
  ELSE p_entity_id
  END;
$$;

CREATE OR REPLACE FUNCTION public._kernel_pay_row_json(
  py public.pays,
  p_direction text,
  p_counterparty_name text DEFAULT NULL,
  p_perspective text DEFAULT 'party'
) RETURNS jsonb
LANGUAGE sql
STABLE
AS $$
  SELECT jsonb_build_object(
    'id', py.id,
    'payment_date', py.payment_date,
    'amount', py.amount,
    'unallocated_amount', coalesce(py.unallocated_amount, 0),
    'source', py.source,
    'direction', p_direction,
    'method', py.method,
    'reference', py.reference,
    'note', py.note,
    'voided_at', py.voided_at,
    'from_profile_id', py.from_profile_id,
    'to_profile_id', py.to_profile_id,
    'description', py.description,
    'profile_id', py.profile_id,
    'profile_name', (SELECT pr.name FROM public.profiles pr WHERE pr.id = py.profile_id),
    'counterparty_name', coalesce(
      nullif(btrim(p_counterparty_name), ''),
      (SELECT pr.name FROM public.profiles pr WHERE pr.id = py.profile_id)
    ),
    'shop_order_id', py.shop_order_id,
    'settlement_currency_code', coalesce(py.settlement_currency_code, 'BDT'),
    'foreign_amount', py.foreign_amount,
    'exchange_rate', coalesce(py.exchange_rate, 1),
    'cashbook_point_id', py.cashbook_point_id,
    'cashbook_point_name', (
      SELECT cp.name FROM public.cashbook_points cp WHERE cp.id = py.cashbook_point_id
    ),
    'related_invoice_no', (
      SELECT b.invoice_no
      FROM public.pay_allocations pa
      INNER JOIN public.bills b ON b.id = pa.bill_id
      WHERE pa.payment_id = py.id
      ORDER BY pa.id ASC
      LIMIT 1
    ),
    'perspective', p_perspective
  );
$$;

CREATE OR REPLACE FUNCTION public.get_payment_profile_for_staff(
  p_tenant_id bigint,
  p_entity_type text,
  p_entity_id bigint,
  p_currency_code text DEFAULT 'BDT'::text,
  p_ledger_limit integer DEFAULT 50,
  p_pays_limit integer DEFAULT 50
) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO public
    AS $$
DECLARE
  v_books_id bigint;
  v_detail jsonb;
  v_ledger_entity_id bigint;
  v_ledger jsonb := '[]'::jsonb;
  v_pays jsonb := '[]'::jsonb;
  v_due_total numeric(18, 4) := 0;
  v_ledger_lim integer;
  v_pays_lim integer;
  v_money_profile_id bigint;
BEGIN
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

  v_detail := public.get_cashbook_detail_for_staff(
    p_tenant_id, p_entity_type, p_entity_id, p_currency_code
  );
  IF coalesce((v_detail->>'success')::boolean, false) IS NOT TRUE THEN
    RETURN v_detail;
  END IF;

  v_ledger_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN
    v_ledger_entity_id := v_books_id;
  END IF;

  v_ledger_lim := greatest(least(coalesce(p_ledger_limit, 50), 200), 1);
  v_pays_lim := greatest(least(coalesce(p_pays_limit, 50), 200), 1);

  SELECT coalesce(jsonb_agg(row_data ORDER BY sort_created DESC, sort_id DESC), '[]'::jsonb)
  INTO v_ledger
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
    ORDER BY l.created_at DESC, l.id DESC
    LIMIT v_ledger_lim
  ) ledger_rows;

  IF p_entity_type <> 'tenant' THEN
    SELECT coalesce(sum(b.due_amount), 0::numeric)
    INTO v_due_total
    FROM public.bills b
    WHERE b.tenant_id = v_books_id
      AND b.profile_id = coalesce(v_money_profile_id, p_entity_id)
      AND b.invoice_status = 'issued'
      AND coalesce(b.payment_status, '') <> 'paid';
  END IF;

  IF p_entity_type = 'tenant' THEN
    SELECT coalesce(jsonb_agg(row_data ORDER BY sort_payment_date DESC, sort_id DESC), '[]'::jsonb)
    INTO v_pays
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
      ORDER BY py.payment_date DESC, py.id DESC
      LIMIT v_pays_lim
    ) pay_rows;

  ELSIF p_entity_type IN ('customer', 'vendor', 'courier', 'cargo_company', 'investor') THEN
    SELECT coalesce(jsonb_agg(row_data ORDER BY sort_payment_date DESC, sort_id DESC), '[]'::jsonb)
    INTO v_pays
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
      ORDER BY py.payment_date DESC, py.id DESC
      LIMIT v_pays_lim
    ) pay_rows;
  END IF;

  RETURN v_detail
    || jsonb_build_object(
      'due_total', v_due_total,
      'ledger', v_ledger,
      'pays', v_pays
    );
END;
$$;

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

    IF p_entity_type = 'tenant' THEN
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

GRANT EXECUTE ON FUNCTION public._kernel_cashbook_money_profile_id(bigint, text, bigint)
  TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.get_payment_profile_for_staff(
  bigint, text, bigint, text, integer, integer
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.get_payment_profile_for_staff(
  bigint, text, bigint, text, integer, integer
) TO service_role;

GRANT EXECUTE ON FUNCTION public.list_profile_activity_for_staff(
  bigint, text, bigint, text, integer, text
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.list_profile_activity_for_staff(
  bigint, text, bigint, text, integer, text
) TO service_role;
