CREATE FUNCTION public.hold_shop_grade_stock_for_order (
  p_parent_tenant_id bigint,
  p_shop_tenant_id   bigint,
  p_product_id       bigint,
  p_grade_tag_id     bigint,
  p_quantity         integer,
  p_order_id         bigint,
  p_notes            text    DEFAULT NULL::text
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_grade_tag_id bigint;
  v_remaining integer;
  v_stock record;
  v_take integer;
  v_primary_held bigint := NULL;
  v_held_stock_id bigint;
BEGIN
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'quantity must be positive';
  END IF;

  v_grade_tag_id := coalesce(p_grade_tag_id, public.default_stock_grade_tag_id());
  v_remaining := p_quantity;

  FOR v_stock IN
    SELECT
      gs.id,
      gs.location_id,
      gs.grade_tag_id,
      gs.shipment_item_id,
      greatest(0, floor(public.global_stock_atp_qty(gs.id)))::integer AS atp
    FROM public.global_stocks gs
    JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
    JOIN public.global_shipments gship ON gship.id = gsi.shipment_id
    LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
    WHERE gsi.product_id = p_product_id
      AND coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id
      AND gs.parent_tenant_id = p_parent_tenant_id
      AND public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, p_shop_tenant_id)
      AND gship.status = 'received'
      AND gs.availability = 'sellable'::public.stock_availability
      AND (gs.location_id IS NULL OR sl.is_pickable = TRUE)
    ORDER BY gs.id
    FOR UPDATE OF gs
  LOOP
    IF v_remaining <= 0 THEN
      EXIT;
    END IF;

    v_take := least(v_remaining, v_stock.atp);
    IF v_take <= 0 THEN
      CONTINUE;
    END IF;

    PERFORM public.create_and_post_stock_movement(
      p_parent_tenant_id,
      v_stock.id,
      v_take,
      v_stock.location_id,
      'held'::public.stock_availability,
      v_stock.grade_tag_id,
      'availability_transfer'::public.stock_movement_type,
      coalesce(p_notes, 'Shop order hold'),
      'shop_order',
      p_order_id::text
    );

    SELECT gs.id
    INTO v_held_stock_id
    FROM public.global_stocks gs
    WHERE gs.shipment_item_id = v_stock.shipment_item_id
      AND gs.parent_tenant_id = p_parent_tenant_id
      AND gs.availability = 'held'::public.stock_availability
      AND gs.location_id IS NOT DISTINCT FROM v_stock.location_id
      AND coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id())
        = coalesce(v_stock.grade_tag_id, public.default_stock_grade_tag_id())
    ORDER BY gs.id DESC
    LIMIT 1;

    v_primary_held := coalesce(v_primary_held, v_held_stock_id);
    v_remaining := v_remaining - v_take;
  END LOOP;

  IF v_remaining > 0 THEN
    RAISE EXCEPTION 'insufficient sellable stock for product % (grade %): short by %',
      p_product_id, v_grade_tag_id, v_remaining;
  END IF;

  RETURN v_primary_held;
END;
$function$;

GRANT ALL ON FUNCTION public.hold_shop_grade_stock_for_order(bigint, bigint, bigint, bigint, integer, bigint, text) TO anon;

GRANT ALL ON FUNCTION public.hold_shop_grade_stock_for_order(bigint, bigint, bigint, bigint, integer, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.hold_shop_grade_stock_for_order(bigint, bigint, bigint, bigint, integer, bigint, text) TO service_role;