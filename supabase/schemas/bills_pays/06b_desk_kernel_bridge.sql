-- Desk read bridge: money_kernel.bills → list/detail shapes (legacy-compatible JSON)

CREATE OR REPLACE FUNCTION public._desk_kernel_kind_invoice_type(p_kind text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_kind IN ('shipment_cost_ap', 'dropship_courier_ap') THEN 'ap'
    WHEN p_kind LIKE 'sales_invoice_%' THEN 'ar'
    WHEN p_kind IN ('credit_note', 'debit_note') THEN 'ar'
    ELSE 'ap'
  END;
$$;

CREATE OR REPLACE FUNCTION public._desk_kernel_status_payment(p_status text, p_due numeric)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_status = 'voided' THEN 'voided'
    WHEN p_status = 'draft' THEN 'unpaid'
    WHEN p_status = 'paid' OR p_status = 'written_off' THEN 'paid'
    WHEN p_status = 'partial' THEN 'partially_paid'
    WHEN p_status = 'issued' AND COALESCE(p_due, 0) > 0 THEN 'due'
  WHEN p_status = 'issued' AND COALESCE(p_due, 0) <= 0 THEN 'paid'
    ELSE 'unpaid'
  END;
$$;

CREATE OR REPLACE FUNCTION public._desk_list_status_slug(
  p_invoice_status text,
  p_payment_status text,
  p_due_amount numeric,
  p_kernel_status text DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_st text := COALESCE(p_kernel_status, p_invoice_status::text);
  v_due numeric := COALESCE(p_due_amount, 0);
BEGIN
  IF v_st IN ('voided') OR p_invoice_status::text = 'voided' THEN
    RETURN 'voided';
  END IF;
  IF v_st IN ('draft', 'proforma_generated') OR p_invoice_status::text IN ('draft', 'proforma_generated') THEN
    RETURN 'draft';
  END IF;
  IF v_st = 'partial' OR p_payment_status = 'partially_paid' THEN
    RETURN 'partial';
  END IF;
  IF v_st IN ('paid', 'written_off') OR p_payment_status = 'paid' OR v_due <= 0 THEN
    RETURN 'paid';
  END IF;
  RETURN 'due';
END;
$$;

CREATE OR REPLACE FUNCTION public._desk_kernel_net_balances_json(p_bill_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_b money_kernel.bills;
BEGIN
  SELECT * INTO v_b FROM money_kernel.bills WHERE id = p_bill_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;
  RETURN jsonb_build_object(
    'bill_id', v_b.id,
    'invoice_no', v_b.invoice_no,
    'original_total', v_b.total_amount,
    'paid_amount', v_b.paid_amount,
    'credits_issued', 0,
    'debits_issued', 0,
    'due_amount', v_b.due_amount,
    'open_books', v_b.due_amount,
    'open_txn', v_b.due_amount,
    'credit_open', 0,
    'document_kind', 'standard'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._desk_kernel_payment_history_json(
  p_tenant_id bigint,
  p_bill_id bigint
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'entry_type', 'payment',
      'entry_id', bs.id,
      'payment_id', bs.pays_id,
      'payment_date', COALESCE(p.payment_date, bs.created_at::date),
      'amount', bs.allocated_amount,
      'receipt_amount', bs.allocated_amount,
      'voided_at', CASE WHEN p.status = 'voided' THEN p.updated_at ELSE NULL END,
      'method', NULL,
      'note', p.meta->>'note',
      'write_off_reason', NULL,
      'settlement_currency_code', p.currency_code,
      'foreign_amount', p.amount,
      'exchange_rate', p.exchange_rate,
      'instruments', '[]'::jsonb,
      'payment_source', 'kernel',
      'related_invoice_no', NULL,
      'related_document_kind', NULL
    )
    ORDER BY bs.created_at DESC
  ), '[]'::jsonb)
  FROM money_kernel.bill_settlements bs
  LEFT JOIN money_kernel.pays p ON p.id = bs.pays_id
  WHERE bs.bill_id = p_bill_id
    AND bs.tenant_id = p_tenant_id
    AND bs.settlement_kind = 'pay';
$$;

CREATE OR REPLACE FUNCTION public._desk_profile_json_public(p_profile_id bigint)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'id', p.id,
    'name', p.name,
    'email', p.email,
    'phone', p.phone,
    'address', p.address,
    'color', p.accent_color
  )
  FROM public.profiles p
  WHERE p.id = p_profile_id;
$$;

CREATE OR REPLACE FUNCTION public._desk_can_load_pay_cashbook(p_tenant_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    public.cashbook_staff_can_view(p_tenant_id)
    OR public.membership_has_module_action(public.resolve_books_tenant_id(p_tenant_id), 'payments', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'payments', 'view');
$$;

CREATE OR REPLACE FUNCTION public._desk_profile_cashbook_leg_json(
  p_books_tenant_id bigint,
  p_bill_profile_id bigint,
  p_currency_code text
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, money_kernel, pg_temp
AS $$
DECLARE
  v_account_id bigint;
  v_default_pot bigint;
  v_ccy_pot bigint;
  v_ccy text;
  v_points jsonb;
  v_pots jsonb;
BEGIN
  IF p_bill_profile_id IS NULL THEN
    RETURN NULL;
  END IF;

  v_ccy := upper(trim(coalesce(p_currency_code, 'BDT')));
  IF v_ccy = '' THEN
    v_ccy := 'BDT';
  END IF;

  BEGIN
    PERFORM public.money_kernel_assert_profile_in_tenant(p_books_tenant_id, p_bill_profile_id);
  EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
  END;

  PERFORM public.fn_provision_kernel_cashbook_for_profile_row(p_books_tenant_id, p_bill_profile_id);
  PERFORM public.fn_provision_kernel_cashbook_currency(p_books_tenant_id, p_bill_profile_id, v_ccy);

  SELECT ca.id, ca.default_cashbook_point_pot_id
  INTO v_account_id, v_default_pot
  FROM money_kernel.cashbook_accounts ca
  WHERE ca.tenant_id = p_books_tenant_id
    AND ca.entity_type = 'profile'
    AND ca.entity_id = p_bill_profile_id
  LIMIT 1;

  IF v_account_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT pp.id INTO v_ccy_pot
  FROM money_kernel.cashbook_point_pots pp
  JOIN money_kernel.cashbook_points pt ON pt.id = pp.cashbook_point_id
  WHERE pt.cashbook_account_id = v_account_id
    AND upper(trim(pp.currency_code)) = v_ccy
  ORDER BY pt.code, pp.id
  LIMIT 1;

  v_default_pot := coalesce(v_ccy_pot, v_default_pot);

  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'id', cp.id,
      'code', cp.code,
      'name', cp.name,
      'is_active', true
    )
    ORDER BY cp.name, cp.id
  ), '[]'::jsonb)
  INTO v_points
  FROM money_kernel.cashbook_points cp
  WHERE cp.cashbook_account_id = v_account_id;

  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'id', pp.id,
      'cashbook_point_id', pp.cashbook_point_id,
      'currency_code', upper(trim(pp.currency_code)),
      'amount', pp.amount,
      'point_code', pt.code,
      'point_name', pt.name
    )
    ORDER BY pt.name, pp.currency_code, pp.id
  ), '[]'::jsonb)
  INTO v_pots
  FROM money_kernel.cashbook_point_pots pp
  JOIN money_kernel.cashbook_points pt ON pt.id = pp.cashbook_point_id
  WHERE pt.cashbook_account_id = v_account_id;

  RETURN jsonb_build_object(
    'profile_id', p_bill_profile_id,
    'cashbook_account_id', v_account_id,
    'default_pot_id', v_default_pot,
    'points', v_points,
    'pots', v_pots
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._desk_bill_pay_cashbook_legs_json(
  p_tenant_id bigint,
  p_invoice_type text,
  p_from_profile_id bigint,
  p_to_profile_id bigint,
  p_currency_code text
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, money_kernel, pg_temp
AS $$
DECLARE
  v_books_id bigint;
  v_ccy text;
BEGIN
  v_books_id := public.resolve_books_tenant_id(p_tenant_id);
  v_ccy := upper(trim(coalesce(p_currency_code, 'BDT')));
  IF v_ccy = '' THEN
    v_ccy := 'BDT';
  END IF;

  RETURN jsonb_build_object(
    'currency_code', v_ccy,
    'from_leg', public._desk_profile_cashbook_leg_json(v_books_id, p_from_profile_id, v_ccy),
    'to_leg', public._desk_profile_cashbook_leg_json(v_books_id, p_to_profile_id, v_ccy)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._get_bill_detail_bundle_from_kernel(
  p_tenant_id bigint,
  p_bill_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_parent_id bigint;
  v_b money_kernel.bills;
  v_invoice_type text;
  v_invoice_status text;
  v_payment_status text;
  v_bill_json jsonb;
  v_bill_lines jsonb := '[]'::jsonb;
  v_adjustments jsonb := '[]'::jsonb;
  v_ap_kind text;
BEGIN
  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  IF NOT (
    public.user_can_manage_books_tenant(v_parent_id)
    OR public.membership_has_module_action(v_parent_id, 'global_invoice', 'view')
  ) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  SELECT * INTO v_b
  FROM money_kernel.bills
  WHERE id = p_bill_id AND tenant_id = v_parent_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;

  v_invoice_type := public._desk_kernel_kind_invoice_type(v_b.kind);
  v_invoice_status := CASE v_b.status
    WHEN 'draft' THEN 'draft'
    WHEN 'voided' THEN 'voided'
    WHEN 'proforma_generated' THEN 'draft'
    ELSE 'issued'
  END;
  v_payment_status := public._desk_kernel_status_payment(v_b.status, v_b.due_amount);
  v_ap_kind := COALESCE(v_b.meta->>'ap_kind', NULL);

  v_bill_json := jsonb_build_object(
    'id', v_b.id,
    'tenant_id', v_b.tenant_id,
    'invoice_no', v_b.invoice_no,
    'invoice_date', v_b.invoice_date,
    'due_date', v_b.due_date,
    'invoice_type', v_invoice_type,
    'invoice_status', v_invoice_status,
    'payment_status', v_payment_status,
    'document_kind', CASE v_b.kind WHEN 'credit_note' THEN 'credit_note' WHEN 'debit_note' THEN 'debit_note' ELSE 'standard' END,
    'total_amount', v_b.total_amount,
    'due_amount', v_b.due_amount,
    'paid_amount', v_b.paid_amount,
    'currency_code', v_b.currency_code,
    'from_profile_id', v_b.from_profile_id,
    'to_profile_id', v_b.to_profile_id,
    'profile_id', v_b.counterparty_profile_id,
    'source_type', v_b.source_type,
    'source_id', v_b.source_id,
    'source_key', v_b.source_key,
    'parent_bill_id', v_b.parent_bill_id,
    'ap_kind', v_ap_kind,
    'channel_meta', jsonb_build_object('ap_kind', v_ap_kind, 'money_kernel_v2', true),
    'note', v_b.note,
    'spine', 'kernel',
    'kernel_kind', v_b.kind
  )
  || jsonb_build_object(
    'profiles', public._desk_profile_json_public(v_b.counterparty_profile_id),
    'from_profile', public._desk_profile_json_public(v_b.from_profile_id),
    'to_profile', public._desk_profile_json_public(v_b.to_profile_id)
  );

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', bl.id,
      'name_snapshot', COALESCE(bl.description, 'Line'),
      'currency_code', upper(v_b.currency_code),
      'line_total_amount', bl.line_total,
      'books_amount', bl.line_total,
      'quantity', bl.quantity
    )
    ORDER BY bl.line_no
  ), '[]'::jsonb)
  INTO v_bill_lines
  FROM money_kernel.bill_lines bl
  WHERE bl.bill_id = p_bill_id AND bl.tenant_id = v_parent_id;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', c.id,
      'invoice_no', c.invoice_no,
      'document_kind', c.kind,
      'invoice_status', c.status,
      'total_amount', c.total_amount
    )
    ORDER BY c.id
  ), '[]'::jsonb)
  INTO v_adjustments
  FROM money_kernel.bills c
  WHERE c.parent_bill_id = p_bill_id
    AND c.tenant_id = v_parent_id
    AND c.kind IN ('credit_note', 'debit_note')
    AND c.status <> 'voided';

  RETURN jsonb_build_object(
    'bill', v_bill_json,
    'payment_history', public._desk_kernel_payment_history_json(v_parent_id, p_bill_id),
    'net_balances', public._desk_kernel_net_balances_json(p_bill_id),
    'adjustments', v_adjustments,
    'stock_items', '[]'::jsonb,
    'bill_lines', v_bill_lines,
    'pay_cashbook_legs', public._desk_bill_pay_cashbook_legs_json(
      p_tenant_id,
      v_invoice_type,
      v_b.from_profile_id,
      v_b.to_profile_id,
      v_b.currency_code
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_bill_detail_bundle(
  p_tenant_id bigint,
  p_bill_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_parent_id bigint;
  v_bill public.bills;
  v_bill_json jsonb;
  v_adjustments jsonb := '[]'::jsonb;
  v_stock_items jsonb := '[]'::jsonb;
  v_bill_lines jsonb := '[]'::jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_bill_id IS NULL THEN
    RAISE EXCEPTION 'Tenant and bill are required.';
  END IF;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  SELECT * INTO v_bill FROM public.bills WHERE id = p_bill_id;
  IF v_bill.id IS NULL THEN
    RETURN public._get_bill_detail_bundle_from_kernel(p_tenant_id, p_bill_id);
  END IF;

  IF NOT (v_bill.tenant_id = v_parent_id OR v_bill.issued_by_tenant_id = p_tenant_id) THEN
    RAISE EXCEPTION 'Invoice not found for this tenant.';
  END IF;

  v_bill_json := row_to_json(v_bill)::jsonb
    || jsonb_build_object(
      'spine', 'legacy',
      'profiles', public._desk_profile_json_public(v_bill.profile_id),
      'from_profile', public._desk_profile_json_public(v_bill.from_profile_id),
      'to_profile', public._desk_profile_json_public(v_bill.to_profile_id)
    );

  IF v_bill.document_kind = 'standard'::public.bill_document_kind THEN
    SELECT coalesce(jsonb_agg(row_to_json(adj)), '[]'::jsonb)
    INTO v_adjustments
    FROM public.list_bill_adjustments(p_bill_id) AS adj;
  END IF;

  IF v_bill.invoice_type <> 'ap'::public.global_invoice_type
    AND v_bill.document_kind IN (
      'standard'::public.bill_document_kind,
      'credit_note'::public.bill_document_kind,
      'debit_note'::public.bill_document_kind
    )
  THEN
    SELECT coalesce(jsonb_agg(row_to_json(li)), '[]'::jsonb)
    INTO v_stock_items
    FROM public.list_global_invoice_items(p_bill_id) AS li;
  END IF;

  IF v_bill.invoice_type = 'ap'::public.global_invoice_type
    OR v_bill.document_kind <> 'standard'::public.bill_document_kind
  THEN
    SELECT coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', bl.id,
          'name_snapshot', bl.name_snapshot,
          'currency_code', upper(coalesce(bl.currency_code, 'BDT')),
          'line_total_amount', bl.line_total_amount,
          'books_amount', coalesce(bl.books_amount, bl.line_total_amount),
          'quantity', bl.quantity
        )
        ORDER BY bl.id
      ),
      '[]'::jsonb
    )
    INTO v_bill_lines
    FROM public.bill_lines bl
    WHERE bl.invoice_id = p_bill_id;
  END IF;

  RETURN jsonb_build_object(
    'bill', v_bill_json,
    'payment_history', public.list_invoice_payment_history(p_tenant_id, p_bill_id),
    'net_balances', public.get_bill_net_balances(p_bill_id),
    'adjustments', v_adjustments,
    'stock_items', v_stock_items,
    'bill_lines', v_bill_lines,
    'pay_cashbook_legs', public._desk_bill_pay_cashbook_legs_json(
      p_tenant_id,
      v_bill.invoice_type::text,
      v_bill.from_profile_id,
      v_bill.to_profile_id,
      coalesce(nullif(trim(v_bill.currency_code), ''), 'BDT')
    )
  );
END;
$$;

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
          'invoice_type', b.invoice_type::text,
          'invoice_status', b.invoice_status::text,
          'payment_status', b.payment_status::text,
          'total_amount', b.total_amount,
          'due_amount', COALESCE(ks.open_books, b.due_amount),
          'currency_code', upper(COALESCE(b.currency_code, 'BDT')),
          'from_profile_id', b.from_profile_id,
          'from_profile_name', from_pr.name,
          'from_profile_type', from_pr.profile_type::text,
          'to_profile_id', b.to_profile_id,
          'to_profile_name', to_pr.name,
          'to_profile_type', to_pr.profile_type::text,
          'profile_name', to_pr.name,
          'ap_kind', b.ap_kind,
          'document_kind', b.document_kind::text,
          'parent_bill_id', b.parent_bill_id,
          'spine', 'legacy',
          'kind', NULL,
          'list_status', public._desk_list_status_slug(
            b.invoice_status::text,
            b.payment_status::text,
            COALESCE(ks.open_books, b.due_amount),
            NULL
          )
        ) AS row_json
      FROM public.bills b
      INNER JOIN public.profiles to_pr
        ON to_pr.id = b.to_profile_id AND to_pr.tenant_id = v_parent_id
      LEFT JOIN public.profiles from_pr
        ON from_pr.id = b.from_profile_id AND from_pr.tenant_id = v_parent_id
      LEFT JOIN public.v_kernel_bill_summaries ks ON ks.bill_id = b.id
      WHERE b.tenant_id = v_parent_id
        AND (v_to_type IS NULL OR to_pr.profile_type::text = v_to_type)
        AND (p_from_profile_id IS NULL OR b.from_profile_id = p_from_profile_id)
        AND (p_payment_status IS NULL OR b.payment_status::text = p_payment_status)
        AND (
          p_invoice_status IS NULL
          OR (
            p_invoice_status = 'draft'
            AND b.invoice_status IN ('draft', 'proforma_generated')
          )
          OR (
            p_invoice_status <> 'draft'
            AND b.invoice_status::text = p_invoice_status
          )
        )
        AND (
          p_quick_filter IS NULL OR p_quick_filter = ''
          OR (p_quick_filter = 'paid' AND COALESCE(ks.open_books, b.due_amount) <= 0 AND b.invoice_status = 'issued')
          OR (p_quick_filter = 'paid' AND b.payment_status = 'paid')
          OR (p_quick_filter = 'unpaid' AND COALESCE(ks.open_books, b.due_amount) > 0 AND b.invoice_status = 'issued')
        )
        AND (p_cursor IS NULL OR b.id < p_cursor)

      UNION ALL

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
        AND NOT EXISTS (SELECT 1 FROM public.bills pb WHERE pb.id = b.id)
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

DROP FUNCTION IF EXISTS public.list_bills_desk_page(
  bigint, bigint, text, text, text, text, text, integer, bigint
);

GRANT EXECUTE ON FUNCTION public.list_bills_desk_page(
  bigint, text, bigint, text, text, text, integer, bigint
) TO authenticated, service_role;
