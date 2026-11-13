-- Bill detail bundle: pay cashbook legs (points + pots) for from/to profiles

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
  p_profile_id bigint,
  p_currency_code text
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_account_id bigint;
  v_default_pot bigint;
  v_ccy text;
  v_points jsonb;
  v_pots jsonb;
BEGIN
  IF p_profile_id IS NULL THEN
    RETURN NULL;
  END IF;

  v_ccy := upper(trim(coalesce(p_currency_code, 'BDT')));
  IF v_ccy = '' THEN
    v_ccy := 'BDT';
  END IF;

  v_account_id := public.ensure_cashbook_account_for_profile(p_profile_id, v_ccy);

  SELECT ca.default_cashbook_point_pot_id
  INTO v_default_pot
  FROM public.cashbook_accounts ca
  WHERE ca.id = v_account_id;

  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'id', cp.id,
      'code', cp.code,
      'name', cp.name,
      'is_active', cp.is_active
    )
    ORDER BY cp.name, cp.id
  ), '[]'::jsonb)
  INTO v_points
  FROM public.cashbook_points cp
  WHERE cp.cashbook_account_id = v_account_id
    AND cp.is_active = true;

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
  FROM public.cashbook_point_pots pp
  JOIN public.cashbook_points pt ON pt.id = pp.cashbook_point_id
  WHERE pt.cashbook_account_id = v_account_id
    AND pt.is_active = true;

  RETURN jsonb_build_object(
    'profile_id', p_profile_id,
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
SET search_path = public
AS $$
DECLARE
  v_ccy text;
  v_is_ap boolean;
  v_payer_profile_id bigint;
  v_payee_profile_id bigint;
BEGIN
  v_ccy := upper(trim(coalesce(p_currency_code, 'BDT')));
  IF v_ccy = '' THEN
    v_ccy := 'BDT';
  END IF;

  v_is_ap := lower(trim(coalesce(p_invoice_type, ''))) = 'ap';
  v_payer_profile_id := CASE WHEN v_is_ap THEN p_to_profile_id ELSE p_from_profile_id END;
  v_payee_profile_id := CASE WHEN v_is_ap THEN p_from_profile_id ELSE p_to_profile_id END;

  RETURN jsonb_build_object(
    'currency_code', v_ccy,
    'from_leg', public._desk_profile_cashbook_leg_json(v_payer_profile_id, v_ccy),
    'to_leg', public._desk_profile_cashbook_leg_json(v_payee_profile_id, v_ccy)
  );
END;
$$;

-- get_bill_detail_bundle + kernel bridge (add pay_cashbook_legs; VOLATILE for ensure side effects)
-- Copied from supabase/schemas/bills_pays/06b_desk_kernel_bridge.sql

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
    'profiles', public._desk_profile_json_kernel(v_b.tenant_id, v_b.counterparty_profile_id),
    'from_profile', public._desk_profile_json_kernel(v_b.tenant_id, v_b.from_profile_id),
    'to_profile', public._desk_profile_json_kernel(v_b.tenant_id, v_b.to_profile_id)
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
