-- Extend get_bill_detail_bundle with stock_items + bill_lines (see 06_bills_desk_wrappers.sql)

CREATE OR REPLACE FUNCTION public.get_bill_detail_bundle(
  p_tenant_id bigint,
  p_bill_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
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

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  SELECT * INTO v_bill FROM public.bills WHERE id = p_bill_id;
  IF v_bill.id IS NULL THEN
    RAISE EXCEPTION 'bill not found';
  END IF;

  IF NOT (v_bill.parent_tenant_id = v_parent_id OR v_bill.issued_by_tenant_id = p_tenant_id) THEN
    RAISE EXCEPTION 'Invoice not found for this tenant.';
  END IF;

  v_bill_json := row_to_json(v_bill)::jsonb
    || jsonb_build_object(
      'profiles', (
        SELECT jsonb_build_object(
          'id', p.id,
          'name', p.name,
          'email', p.email,
          'phone', p.phone,
          'address', p.address,
          'color', p.accent_color
        )
        FROM public.profiles p
        WHERE p.id = v_bill.profile_id
      ),
      'from_profile', (
        SELECT jsonb_build_object(
          'id', p.id,
          'name', p.name,
          'email', p.email,
          'phone', p.phone,
          'address', p.address
        )
        FROM public.profiles p
        WHERE p.id = v_bill.from_profile_id
      ),
      'to_profile', (
        SELECT jsonb_build_object(
          'id', p.id,
          'name', p.name,
          'email', p.email,
          'phone', p.phone,
          'address', p.address
        )
        FROM public.profiles p
        WHERE p.id = v_bill.to_profile_id
      )
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
    'bill_lines', v_bill_lines
  );
END;
$$;
