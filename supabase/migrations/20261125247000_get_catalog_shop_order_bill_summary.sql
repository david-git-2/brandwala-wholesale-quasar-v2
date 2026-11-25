CREATE OR REPLACE FUNCTION public.get_catalog_shop_order_bill_summary(
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
  v_books bigint;
  v_bill money_kernel.bills;
  v_kind text;
  v_invoice_status text;
BEGIN
  IF p_tenant_id IS NULL OR p_bill_id IS NULL OR p_bill_id <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'tenant_id and bill_id required');
  END IF;

  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  v_books := public.resolve_books_tenant_id(p_tenant_id);
  PERFORM public.assert_kernel_money_access(v_books, 'bills');

  SELECT * INTO v_bill
  FROM money_kernel.bills
  WHERE id = p_bill_id AND tenant_id = v_books;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'bill not found');
  END IF;

  v_kind := lower(trim(coalesce(nullif(v_bill.meta->>'delivery_kind', ''), 'take')));
  IF v_kind NOT IN ('take', 'condition') THEN
    v_kind := 'take';
  END IF;

  v_invoice_status := public._kernel_bill_invoice_status_enum(v_bill.status::text)::text;

  RETURN jsonb_build_object(
    'success', true,
    'bill_id', p_bill_id,
    'invoice_status', v_invoice_status,
    'settlement_kind', v_kind
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_catalog_shop_order_bill_summary(bigint, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_catalog_shop_order_bill_summary(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_catalog_shop_order_bill_summary(bigint, bigint) TO service_role;