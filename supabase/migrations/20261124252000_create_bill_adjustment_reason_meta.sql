-- credit_note / debit_note registry requires meta.reason

CREATE OR REPLACE FUNCTION public.create_bill_adjustment(
  p_parent_bill_id bigint,
  p_kind text,
  p_amount numeric,
  p_reason text,
  p_issue boolean DEFAULT true,
  p_refund_amount numeric DEFAULT NULL,
  p_cashbook_point_id bigint DEFAULT NULL,
  p_lines jsonb DEFAULT '[]'::jsonb
) RETURNS public.bills
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO money_kernel, public, pg_temp
AS $$
DECLARE
  v_parent money_kernel.bills;
  v_kind text;
  v_amount numeric(12, 2);
  v_reason text;
  v_rpc jsonb;
  v_bill_id bigint;
  v_row public.bills;
BEGIN
  IF p_parent_bill_id IS NULL THEN
    RAISE EXCEPTION 'parent_bill_id is required';
  END IF;

  v_kind := CASE lower(trim(coalesce(p_kind, '')))
    WHEN 'credit_note' THEN 'credit_note'
    WHEN 'credit' THEN 'credit_note'
    WHEN 'debit_note' THEN 'debit_note'
    WHEN 'debit' THEN 'debit_note'
    ELSE NULL
  END;
  IF v_kind IS NULL THEN
    RAISE EXCEPTION 'kind must be credit_note or debit_note';
  END IF;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  IF v_reason IS NULL THEN
    RAISE EXCEPTION 'reason is required';
  END IF;

  SELECT * INTO v_parent FROM money_kernel.bills WHERE id = p_parent_bill_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;
  IF v_parent.status NOT IN ('issued', 'partial', 'paid', 'written_off') THEN
    RAISE EXCEPTION 'parent bill must be issued';
  END IF;

  IF NOT (
    coalesce(auth.role(), '') = 'service_role'
    OR public.user_can_manage_books_tenant(v_parent.tenant_id)
    OR public.membership_has_module_action(v_parent.tenant_id, 'global_invoice', 'edit')
  ) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  v_amount := round(coalesce(p_amount, 0), 2);
  IF v_amount <= 0 THEN
    RAISE EXCEPTION 'amount must be greater than zero';
  END IF;

  v_rpc := public.rpc_create_bill(jsonb_strip_nulls(jsonb_build_object(
    'tenant_id', v_parent.tenant_id,
    'kind', v_kind,
    'parent_bill_id', p_parent_bill_id,
    'currency_code', v_parent.currency_code,
    'note', v_reason,
    'auto_issue', coalesce(p_issue, true),
    'meta', jsonb_build_object(
      'reason', v_reason,
      'adjustment_reason', v_reason,
      'subtotal_amount', v_amount
    ),
    'lines', jsonb_build_array(jsonb_build_object(
      'item_kind', 'charge',
      'description', v_reason,
      'quantity', 1,
      'unit_price', v_amount,
      'line_total', v_amount
    ))
  )));

  v_bill_id := nullif(v_rpc->>'bill_id', '')::bigint;
  IF v_bill_id IS NULL THEN
    RAISE EXCEPTION '%', coalesce(v_rpc->>'error', 'create_bill_adjustment failed');
  END IF;

  SELECT * INTO v_row FROM public.bills WHERE id = v_bill_id;
  RETURN v_row;
END;
$$;
