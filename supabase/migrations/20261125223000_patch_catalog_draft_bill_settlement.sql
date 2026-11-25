-- Patch wholesale draft bill settlement (delivery_kind) without re-sending lines.

CREATE OR REPLACE FUNCTION public.patch_catalog_draft_bill_settlement(
  p_tenant_id bigint,
  p_bill_id bigint,
  p_settlement_kind public.bill_settlement_kind DEFAULT 'take'::public.bill_settlement_kind
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_books bigint;
  v_bill money_kernel.bills;
  v_kind text;
BEGIN
  IF p_tenant_id IS NULL OR p_bill_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'tenant_id and bill_id required');
  END IF;

  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  v_kind := lower(trim(coalesce(p_settlement_kind::text, 'take')));
  IF v_kind NOT IN ('take', 'condition') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid settlement_kind');
  END IF;

  v_books := public.resolve_books_tenant_id(p_tenant_id);

  PERFORM public.assert_kernel_money_access(v_books, 'bills');

  SELECT * INTO v_bill
  FROM money_kernel.bills
  WHERE id = p_bill_id AND tenant_id = v_books
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'bill not found');
  END IF;

  IF v_bill.status IS DISTINCT FROM 'draft' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', format('only draft bills can be updated (got %s)', v_bill.status)
    );
  END IF;

  IF v_bill.kind IS DISTINCT FROM 'sales_invoice_wholesale' THEN
    RETURN jsonb_build_object('success', false, 'error', 'bill is not a wholesale sales invoice');
  END IF;

  UPDATE money_kernel.bills
  SET
    meta = coalesce(meta, '{}'::jsonb) || jsonb_build_object('delivery_kind', v_kind),
    updated_at = now()
  WHERE id = p_bill_id AND tenant_id = v_books;

  RETURN jsonb_build_object(
    'success', true,
    'bill_id', p_bill_id,
    'settlement_kind', v_kind
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.patch_catalog_draft_bill_settlement(
  bigint,
  bigint,
  public.bill_settlement_kind
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.patch_catalog_draft_bill_settlement(
  bigint,
  bigint,
  public.bill_settlement_kind
) TO service_role;