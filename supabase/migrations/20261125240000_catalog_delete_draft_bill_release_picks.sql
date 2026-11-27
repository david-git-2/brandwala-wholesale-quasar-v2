-- Catalog draft bill delete: release all related picks (held -> sellable), then delete draft bill.
-- Harden remove_shop_order_item_stock_pick so holds are not dropped without warehouse release.

DROP FUNCTION IF EXISTS public.remove_shop_order_item_stock_pick(bigint);

CREATE OR REPLACE FUNCTION public.remove_shop_order_item_stock_pick(
  p_pick_id bigint,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pick public.shop_order_item_stock_picks%rowtype;
  v_order public.shop_orders%rowtype;
  v_stock public.global_stocks%rowtype;
  v_books_tenant_id bigint;
  v_order_item_id bigint;
  v_confirmed_qty numeric;
  v_fulfillment_resolved boolean;
  v_pick_list jsonb;
  v_released boolean := false;
BEGIN
  SELECT * INTO v_pick FROM public.shop_order_item_stock_picks WHERE id = p_pick_id FOR UPDATE;
  IF v_pick.id IS NULL THEN
    RAISE EXCEPTION 'pick not found';
  END IF;

  SELECT * INTO v_order FROM public.shop_orders WHERE id = v_pick.order_id FOR UPDATE;
  IF NOT public.is_tenant_staff(v_order.tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  IF NOT public._shop_order_allows_stock_pick(v_order) THEN
    RAISE EXCEPTION 'pick removal is not allowed for this order status';
  END IF;

  v_books_tenant_id := public.resolve_books_tenant_id(v_order.tenant_id);

  IF v_pick.held_stock_id IS NOT NULL THEN
    SELECT * INTO v_stock FROM public.global_stocks WHERE id = v_pick.held_stock_id FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'held stock lot % for pick % not found', v_pick.held_stock_id, p_pick_id;
    END IF;
    IF v_stock.availability IS DISTINCT FROM 'held'::public.stock_availability THEN
      RAISE EXCEPTION 'held stock lot % for pick % is not held (status=%)',
        v_pick.held_stock_id, p_pick_id, v_stock.availability;
    END IF;
    IF v_stock.quantity < v_pick.quantity THEN
      RAISE EXCEPTION 'held stock lot % has qty % but pick % needs %',
        v_pick.held_stock_id, v_stock.quantity, p_pick_id, v_pick.quantity;
    END IF;

    PERFORM public.create_and_post_stock_movement(
      p_tenant_id => v_books_tenant_id,
      p_stock_id => v_stock.id,
      p_quantity => v_pick.quantity,
      p_to_location_id => v_stock.location_id,
      p_to_availability => 'sellable'::public.stock_availability,
      p_to_grade_tag_id => v_stock.grade_tag_id,
      p_movement_type => 'availability_transfer'::public.stock_movement_type,
      p_notes => CASE
        WHEN v_order.shop_type_snapshot = 'vendor_catalog' THEN 'Undo catalog order stock pick'
        ELSE 'Undo dropship processing pick'
      END,
      p_reference_type => 'shop_order',
      p_reference_id => v_order.id::text
    );
    v_released := true;
  END IF;

  v_order_item_id := v_pick.order_item_id;

  DELETE FROM public.shop_order_item_stock_picks WHERE id = p_pick_id;

  PERFORM public._recompute_shop_order_item_fulfillment(v_order_item_id);
  IF v_order.shop_type_snapshot = 'dropship'::public.shop_type_enum THEN
    PERFORM public.recompute_dropship_cod_collect_amount(v_order.id);
  END IF;

  SELECT
    soi.confirmed_quantity,
    coalesce(soi.is_fulfillment_unavailable, false)
      OR coalesce(soi.confirmed_quantity, 0) > 0
      OR (
        coalesce(soi.is_gift, false)
        AND soi.gift_source = 'customer_stock'
        AND coalesce(soi.confirmed_quantity, 0) >= soi.quantity
      )
      OR (coalesce(soi.is_gift, false) AND soi.gift_source = 'stock')
  INTO v_confirmed_qty, v_fulfillment_resolved
  FROM public.shop_order_items soi
  WHERE soi.id = v_order_item_id;

  v_pick_list := public.list_stock_for_order_item_pick(
    v_order_item_id,
    p_search,
    p_limit,
    p_offset
  );

  RETURN jsonb_build_object(
    'success', true,
    'held_released', v_released,
    'order_line', jsonb_build_object(
      'id', v_order_item_id,
      'confirmed_quantity', v_confirmed_qty,
      'fulfillment_resolved', v_fulfillment_resolved
    ),
    'pick_list', v_pick_list
  );
END;
$$;

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

GRANT EXECUTE ON FUNCTION public.delete_catalog_shop_order_draft_bill(bigint) TO authenticated, service_role;