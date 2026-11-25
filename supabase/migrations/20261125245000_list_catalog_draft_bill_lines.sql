-- Catalog draft bill merge: definer read of money_kernel.bill_lines (desk JWT vs books tenant).

CREATE OR REPLACE FUNCTION public.list_catalog_draft_bill_lines(p_bill_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_books_tenant_id bigint;
  v_lines jsonb;
BEGIN
  IF p_bill_id IS NULL OR p_bill_id <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'bill_id required');
  END IF;

  SELECT kb.tenant_id
  INTO v_books_tenant_id
  FROM money_kernel.bills kb
  WHERE kb.id = p_bill_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'bill not found');
  END IF;

  IF NOT (
    public.user_can_manage_books_tenant(v_books_tenant_id)
    OR public.membership_has_module_action(v_books_tenant_id, 'global_invoice', 'view')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'global_stock_id', bl.global_stock_id,
        'name_snapshot', bl.description,
        'quantity', bl.quantity,
        'sell_price_amount', bl.unit_price,
        'line_total_amount', bl.line_total,
        'shipment_item_id', bl.shipment_item_id,
        'product_id', bl.product_id,
        'line_meta', coalesce(bl.meta, '{}'::jsonb)
      )
      ORDER BY bl.line_no, bl.id
    ),
    '[]'::jsonb
  )
  INTO v_lines
  FROM money_kernel.bill_lines bl
  WHERE bl.bill_id = p_bill_id
    AND bl.tenant_id = v_books_tenant_id
    AND bl.item_kind IN ('stock', 'charge');

  RETURN jsonb_build_object(
    'success', true,
    'bill_id', p_bill_id,
    'lines', v_lines
  );
END;
$$;

REVOKE ALL ON FUNCTION public.list_catalog_draft_bill_lines(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_catalog_draft_bill_lines(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_catalog_draft_bill_lines(bigint) TO service_role;