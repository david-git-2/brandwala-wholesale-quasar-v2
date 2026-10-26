-- Default shop_product_listings.grade_tag_id to warehouse "standard" on create and backfill.

-- 1. Backfill: dedupe null-grade drafts, then assign standard
WITH ranked AS (
  SELECT
    l.id,
    row_number() OVER (
      PARTITION BY l.shop_id, l.product_id
      ORDER BY l.is_active DESC, l.id ASC
    ) AS rn
  FROM public.shop_product_listings l
  WHERE l.grade_tag_id IS NULL
)
DELETE FROM public.shop_product_listings spl
USING ranked r
WHERE spl.id = r.id
  AND r.rn > 1;

DELETE FROM public.shop_product_listings l
WHERE l.grade_tag_id IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.shop_product_listings l2
    WHERE l2.shop_id = l.shop_id
      AND l2.product_id = l.product_id
      AND l2.grade_tag_id = public.default_stock_grade_tag_id()
  );

UPDATE public.shop_product_listings
SET grade_tag_id = public.default_stock_grade_tag_id()
WHERE grade_tag_id IS NULL;

-- 2. upsert_shop_product_listing: new product-only listings get standard grade
CREATE OR REPLACE FUNCTION public.upsert_shop_product_listing(
  p_tenant_id bigint,
  p_shop_id bigint,
  p_global_stock_allocation_id bigint DEFAULT NULL,
  p_sell_price_amount numeric DEFAULT NULL,
  p_sell_price_currency_id bigint DEFAULT NULL,
  p_minimum_sell_price_amount numeric DEFAULT NULL,
  p_minimum_sell_price_currency_id bigint DEFAULT NULL,
  p_show_quantity boolean DEFAULT NULL,
  p_display_quantity_override integer DEFAULT NULL,
  p_is_active boolean DEFAULT NULL,
  p_id bigint DEFAULT NULL,
  p_is_price_locked boolean DEFAULT NULL,
  p_is_quantity_locked boolean DEFAULT NULL,
  p_quantity_override_type text DEFAULT NULL,
  p_global_stock_id bigint DEFAULT NULL,
  p_product_id bigint DEFAULT NULL
)
RETURNS SETOF public.shop_product_listings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_product_id bigint;
  v_target_stock_id bigint;
  v_grade_tag_id bigint;
  v_standard_grade_tag_id bigint;
  v_existing record;
  v_price_locked boolean;
  v_qty_locked boolean;
  v_override_type text;
  v_default_sell_amount numeric;
BEGIN
  v_standard_grade_tag_id := public.default_stock_grade_tag_id();

  IF NOT public.user_can_manage_shop_tenant(p_tenant_id)
     AND NOT public.user_can_manage_shop_tenant(public.resolve_parent_tenant_id(p_tenant_id))
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF p_id IS NOT NULL THEN
    SELECT * INTO v_existing FROM public.shop_product_listings WHERE id = p_id;

    IF v_existing.id IS NULL THEN
      RAISE EXCEPTION 'listing not found';
    END IF;

    IF v_existing.global_stock_id IS NULL
       AND coalesce(v_existing.grade_tag_id, v_standard_grade_tag_id) = v_standard_grade_tag_id THEN
      v_price_locked := coalesce(p_is_price_locked, v_existing.is_price_locked, false);
      v_qty_locked := coalesce(p_is_quantity_locked, v_existing.is_quantity_locked, false);
      v_override_type := coalesce(p_quantity_override_type, v_existing.quantity_override_type, 'absolute');

      RETURN QUERY
      UPDATE public.shop_product_listings
      SET
        grade_tag_id = coalesce(grade_tag_id, v_standard_grade_tag_id),
        sell_price_amount = coalesce(p_sell_price_amount, sell_price_amount),
        sell_price_currency_id = coalesce(p_sell_price_currency_id, sell_price_currency_id),
        minimum_sell_price_amount = p_minimum_sell_price_amount,
        minimum_sell_price_currency_id = p_minimum_sell_price_currency_id,
        show_quantity = coalesce(p_show_quantity, show_quantity),
        display_quantity_override = p_display_quantity_override,
        is_active = coalesce(p_is_active, is_active),
        is_price_locked = v_price_locked,
        is_quantity_locked = v_qty_locked,
        quantity_override_type = v_override_type,
        updated_at = now()
      WHERE id = v_existing.id
      RETURNING *;
      RETURN;
    END IF;
  END IF;

  v_target_stock_id := coalesce(p_global_stock_id, p_global_stock_allocation_id, v_existing.global_stock_id);

  IF v_target_stock_id IS NOT NULL THEN
    SELECT gsi.product_id, coalesce(gs.grade_tag_id, v_standard_grade_tag_id)
    INTO v_product_id, v_grade_tag_id
    FROM public.global_stocks gs
    JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
    WHERE gs.id = v_target_stock_id;

    IF v_product_id IS NULL THEN
      RAISE EXCEPTION 'global stock not found';
    END IF;

    IF p_id IS NOT NULL THEN
      SELECT * INTO v_existing FROM public.shop_product_listings WHERE id = p_id;
    ELSE
      SELECT * INTO v_existing
      FROM public.shop_product_listings
      WHERE shop_id = p_shop_id
        AND product_id = v_product_id
        AND grade_tag_id = v_grade_tag_id;
    END IF;

    v_price_locked := coalesce(p_is_price_locked, v_existing.is_price_locked, false);
    v_qty_locked := coalesce(p_is_quantity_locked, v_existing.is_quantity_locked, false);
    v_override_type := coalesce(p_quantity_override_type, v_existing.quantity_override_type, 'absolute');

    IF v_existing.id IS NOT NULL THEN
      RETURN QUERY
      UPDATE public.shop_product_listings
      SET
        sell_price_amount = coalesce(p_sell_price_amount, sell_price_amount),
        sell_price_currency_id = coalesce(p_sell_price_currency_id, sell_price_currency_id),
        minimum_sell_price_amount = p_minimum_sell_price_amount,
        minimum_sell_price_currency_id = p_minimum_sell_price_currency_id,
        show_quantity = coalesce(p_show_quantity, show_quantity),
        display_quantity_override = p_display_quantity_override,
        is_active = coalesce(p_is_active, is_active),
        is_price_locked = v_price_locked,
        is_quantity_locked = v_qty_locked,
        quantity_override_type = v_override_type,
        grade_tag_id = coalesce(grade_tag_id, v_grade_tag_id),
        global_stock_allocation_id = NULL,
        updated_at = now()
      WHERE id = v_existing.id
      RETURNING *;
      RETURN;
    END IF;

    RETURN QUERY
    INSERT INTO public.shop_product_listings (
      tenant_id, shop_id, global_stock_allocation_id, global_stock_id, product_id,
      grade_tag_id, sell_price_amount, sell_price_currency_id,
      minimum_sell_price_amount, minimum_sell_price_currency_id,
      show_quantity, display_quantity_override, is_active,
      is_price_locked, is_quantity_locked, quantity_override_type
    ) VALUES (
      p_tenant_id, p_shop_id, NULL, NULL, v_product_id,
      v_grade_tag_id, p_sell_price_amount, p_sell_price_currency_id,
      p_minimum_sell_price_amount, p_minimum_sell_price_currency_id,
      p_show_quantity, p_display_quantity_override, coalesce(p_is_active, true),
      v_price_locked, v_qty_locked, v_override_type
    )
    RETURNING *;
    RETURN;
  END IF;

  v_product_id := coalesce(p_product_id, v_existing.product_id);
  IF v_product_id IS NULL THEN
    RAISE EXCEPTION 'product or stock required';
  END IF;

  v_grade_tag_id := v_standard_grade_tag_id;

  SELECT p.id, coalesce(p.list_price_amount, p.reference_cost_amount, 0)::numeric
  INTO v_product_id, v_default_sell_amount
  FROM public.products p
  WHERE p.id = v_product_id;

  IF v_product_id IS NULL THEN
    RAISE EXCEPTION 'product not found';
  END IF;

  IF p_id IS NOT NULL THEN
    SELECT * INTO v_existing FROM public.shop_product_listings WHERE id = p_id;
  ELSE
    SELECT * INTO v_existing
    FROM public.shop_product_listings
    WHERE shop_id = p_shop_id
      AND product_id = v_product_id
      AND coalesce(grade_tag_id, v_standard_grade_tag_id) = v_standard_grade_tag_id
      AND global_stock_id IS NULL;
  END IF;

  v_price_locked := coalesce(p_is_price_locked, v_existing.is_price_locked, false);
  v_qty_locked := coalesce(p_is_quantity_locked, v_existing.is_quantity_locked, false);
  v_override_type := coalesce(p_quantity_override_type, v_existing.quantity_override_type, 'absolute');

  IF v_existing.id IS NOT NULL THEN
    RETURN QUERY
    UPDATE public.shop_product_listings
    SET
      grade_tag_id = coalesce(grade_tag_id, v_standard_grade_tag_id),
      sell_price_amount = coalesce(p_sell_price_amount, sell_price_amount),
      sell_price_currency_id = coalesce(p_sell_price_currency_id, sell_price_currency_id),
      minimum_sell_price_amount = p_minimum_sell_price_amount,
      minimum_sell_price_currency_id = p_minimum_sell_price_currency_id,
      show_quantity = coalesce(p_show_quantity, show_quantity),
      display_quantity_override = p_display_quantity_override,
      is_active = coalesce(p_is_active, is_active),
      is_price_locked = v_price_locked,
      is_quantity_locked = v_qty_locked,
      quantity_override_type = v_override_type,
      updated_at = now()
    WHERE id = v_existing.id
    RETURNING *;
    RETURN;
  END IF;

  RETURN QUERY
  INSERT INTO public.shop_product_listings (
    tenant_id, shop_id, global_stock_allocation_id, global_stock_id, product_id,
    grade_tag_id, sell_price_amount, sell_price_currency_id,
    minimum_sell_price_amount, minimum_sell_price_currency_id,
    show_quantity, display_quantity_override, is_active,
    is_price_locked, is_quantity_locked, quantity_override_type
  ) VALUES (
    p_tenant_id, p_shop_id, NULL, NULL, v_product_id,
    v_standard_grade_tag_id, coalesce(p_sell_price_amount, v_default_sell_amount, 0), p_sell_price_currency_id,
    p_minimum_sell_price_amount, p_minimum_sell_price_currency_id,
    coalesce(p_show_quantity, true), p_display_quantity_override, coalesce(p_is_active, false),
    v_price_locked, v_qty_locked, v_override_type
  )
  RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_shop_product_listing(
  bigint, bigint, bigint, numeric, bigint, numeric, bigint, boolean, integer, boolean, bigint, boolean, boolean, text, bigint, bigint
) TO authenticated;
