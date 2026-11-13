-- AP desk line detail for kernel shipment bills comes from bundle bill_lines + UI (not channel_meta ap_paper).

CREATE OR REPLACE FUNCTION public._get_bill_detail_bundle_from_kernel(
  p_tenant_id bigint,
  p_bill_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
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
    'bill_lines', v_bill_lines
  );
END;
$$;
