-- Fix dispatch table delivery-paper breakdown: tenant match + total line qty (not packed-only).

CREATE OR REPLACE FUNCTION public.delivery_paper_line_total_qty(p_splits jsonb)
RETURNS integer
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT coalesce(sum(greatest(0, (elem->>'quantity')::integer)), 0)::integer
  FROM jsonb_array_elements(coalesce(p_splits, '[]'::jsonb)) AS elem;
$$;

GRANT EXECUTE ON FUNCTION public.delivery_paper_line_total_qty(jsonb) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.list_shop_order_delivery_paper_qty_by_item(
  p_tenant_id bigint,
  p_order_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_by_item jsonb := '{}'::jsonb;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  IF p_order_id IS NULL THEN
    RAISE EXCEPTION 'order_id is required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.shop_orders o
    WHERE o.id = p_order_id
      AND o.shop_type_snapshot = 'vendor_catalog'
      AND (
        o.tenant_id IS NOT DISTINCT FROM p_tenant_id
        OR o.parent_tenant_id IS NOT DISTINCT FROM p_tenant_id
      )
  ) THEN
    RAISE EXCEPTION 'shop order not found';
  END IF;

  SELECT coalesce(
    jsonb_object_agg(sub.order_item_id::text, sub.papers),
    '{}'::jsonb
  )
  INTO v_by_item
  FROM (
    SELECT
      oi.id AS order_item_id,
      jsonb_agg(
        jsonb_build_object(
          'delivery_paper_id', agg.delivery_paper_id,
          'paper_status', agg.paper_status,
          'quantity', agg.qty
        )
        ORDER BY agg.delivery_paper_id
      ) AS papers
    FROM public.shop_order_items oi
    INNER JOIN (
      SELECT
        pd.source_id AS order_item_id,
        dp.id AS delivery_paper_id,
        dp.status AS paper_status,
        coalesce(sum(public.delivery_paper_line_total_qty(dpl.splits)), 0)::integer AS qty
      FROM public.delivery_paper dp
      INNER JOIN public.delivery_paper_line dpl
        ON dpl.delivery_paper_id = dp.id
      INNER JOIN public.preorder_demand pd
        ON pd.id = dpl.preorder_demand_id
        AND pd.source_type = 'shop_order_item'::public.preorder_demand_source_type
      WHERE dp.source_type = 'shop_order'::public.delivery_paper_source_type
        AND dp.source_id = p_order_id
        AND dp.status <> 'cancelled'::public.delivery_paper_status
      GROUP BY pd.source_id, dp.id, dp.status
    ) agg ON agg.order_item_id = oi.id
    WHERE oi.order_id = p_order_id
    GROUP BY oi.id
  ) sub;

  RETURN jsonb_build_object('by_order_item_id', v_by_item);
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_shop_order_delivery_paper_qty_by_item(bigint, bigint)
  TO authenticated, service_role;
