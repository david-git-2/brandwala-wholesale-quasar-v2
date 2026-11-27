-- remove_shop_order_item_stock_pick(bigint) legacy overload collides with 4-arg signature.

DROP FUNCTION IF EXISTS public.remove_shop_order_item_stock_pick(bigint);

CREATE OR REPLACE FUNCTION public.delete_catalog_shop_order_draft_bill(p_bill_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_bill money_kernel.bills;
  v_line record;
  v_meta jsonb;
  v_pick_id bigint;
  v_source_stock_id bigint;
  v_order_item_id bigint;
  v_pick_ids bigint[] := ARRAY[]::bigint[];
BEGIN
  IF p_bill_id IS NULL OR p_bill_id <= 0 THEN
    RAISE EXCEPTION 'bill_id required';
  END IF;

  SELECT * INTO v_bill FROM money_kernel.bills WHERE id = p_bill_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;

  IF NOT public.user_can_manage_books_tenant(v_bill.tenant_id) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  IF v_bill.status IS DISTINCT FROM 'draft' THEN
    RAISE EXCEPTION 'Only draft bills can be deleted';
  END IF;

  FOR v_line IN
    SELECT bl.meta, bl.global_stock_id
    FROM money_kernel.bill_lines bl
    WHERE bl.bill_id = p_bill_id
      AND bl.tenant_id = v_bill.tenant_id
  LOOP
    v_meta := coalesce(v_line.meta, '{}'::jsonb);
    v_pick_id := nullif(v_meta->>'shop_order_item_stock_pick_id', '')::bigint;

    IF v_pick_id IS NULL THEN
      v_order_item_id := nullif(v_meta->>'shop_order_item_id', '')::bigint;
      v_source_stock_id := coalesce(
        nullif(v_meta->>'source_global_stock_id', '')::bigint,
        v_line.global_stock_id
      );

      IF v_order_item_id IS NOT NULL AND v_source_stock_id IS NOT NULL THEN
        SELECT sp.id
        INTO v_pick_id
        FROM public.shop_order_item_stock_picks sp
        WHERE sp.order_item_id = v_order_item_id
          AND (
            sp.global_stock_id = v_source_stock_id
            OR (v_line.global_stock_id IS NOT NULL AND sp.held_stock_id = v_line.global_stock_id)
          )
        ORDER BY sp.id DESC
        LIMIT 1;
      END IF;
    END IF;

    IF v_pick_id IS NOT NULL AND NOT (v_pick_id = ANY (v_pick_ids)) THEN
      v_pick_ids := array_append(v_pick_ids, v_pick_id);
    END IF;
  END LOOP;

  IF array_length(v_pick_ids, 1) IS NOT NULL THEN
    FOREACH v_pick_id IN ARRAY v_pick_ids
    LOOP
      PERFORM public.remove_shop_order_item_stock_pick(v_pick_id, NULL::text, 50, 0);
    END LOOP;
  END IF;

  PERFORM public.delete_draft_bill_from_desk(p_bill_id);

  RETURN jsonb_build_object(
    'success', true,
    'bill_id', p_bill_id,
    'released_pick_ids', to_jsonb(v_pick_ids)
  );
END;
$$;