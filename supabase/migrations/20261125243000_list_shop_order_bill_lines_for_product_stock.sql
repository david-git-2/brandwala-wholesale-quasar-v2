-- Catalog pick-stock: bill lines on all order bills for product + stock lot.

CREATE OR REPLACE FUNCTION public.list_shop_order_bill_lines_for_product_stock(
  p_tenant_id bigint,
  p_order_id bigint,
  p_product_id bigint,
  p_global_stock_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_order public.shop_orders%rowtype;
  v_parent_id bigint;
  v_lines jsonb;
  v_total numeric := 0;
  v_stock_id bigint;
BEGIN
  IF p_tenant_id IS NULL OR p_order_id IS NULL OR p_product_id IS NULL OR p_global_stock_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'tenant_id, order_id, product_id, and global_stock_id required');
  END IF;

  v_stock_id := p_global_stock_id;
  IF v_stock_id <= 0 OR p_product_id <= 0 OR p_order_id <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid ids');
  END IF;

  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  SELECT * INTO v_order FROM public.shop_orders o WHERE o.id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order not found');
  END IF;

  IF v_order.tenant_id IS DISTINCT FROM p_tenant_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'tenant mismatch');
  END IF;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'bill_id', b.id,
        'line_id', bl.id,
        'product_id', bl.product_id,
        'global_stock_id', bl.global_stock_id,
        'quantity', bl.quantity,
        'invoice_status', CASE b.status
          WHEN 'draft' THEN 'draft'
          WHEN 'voided' THEN 'voided'
          WHEN 'proforma_generated' THEN 'draft'
          ELSE 'issued'
        END,
        'line_meta', coalesce(bl.meta, '{}'::jsonb)
      )
      ORDER BY b.id, bl.line_no, bl.id
    ),
    '[]'::jsonb
  ),
  coalesce(sum(bl.quantity), 0)
  INTO v_lines, v_total
  FROM money_kernel.bills b
  JOIN money_kernel.bill_lines bl ON bl.bill_id = b.id AND bl.tenant_id = b.tenant_id
  WHERE b.tenant_id = v_parent_id
    AND b.status IS DISTINCT FROM 'voided'
    AND (
      nullif(b.meta->>'shop_order_id', '')::bigint = p_order_id
      OR (b.source_type = 'shop_order' AND b.source_id = p_order_id::text)
    )
    AND bl.product_id = p_product_id
    AND (
      bl.global_stock_id = v_stock_id
      OR nullif(bl.meta->>'source_global_stock_id', '')::bigint = v_stock_id
    );

  RETURN jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'product_id', p_product_id,
    'global_stock_id', v_stock_id,
    'lines', v_lines,
    'total_quantity', coalesce(v_total, 0)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.list_shop_order_bill_lines_for_product_stock(bigint, bigint, bigint, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_shop_order_bill_lines_for_product_stock(bigint, bigint, bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_shop_order_bill_lines_for_product_stock(bigint, bigint, bigint, bigint) TO service_role;