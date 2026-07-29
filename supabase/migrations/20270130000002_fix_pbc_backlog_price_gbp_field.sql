-- Migration to fix field reference price_in_web_gbp -> price_gbp on product_based_costing_items

-- 1. Fix upsert_pbc_backlog_from_item
CREATE OR REPLACE FUNCTION public.upsert_pbc_backlog_from_item(p_costing_item_id bigint)
RETURNS public.product_based_costing_backlog_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item public.product_based_costing_items%ROWTYPE;
  v_file public.product_based_costing_files%ROWTYPE;
  v_prod RECORD;
  v_confirmed_qty numeric;
  v_ordered_qty numeric;
  v_open_qty numeric;
  v_backlog_row public.product_based_costing_backlog_items;
BEGIN
  -- Fetch costing item details
  SELECT * INTO v_item
  FROM public.product_based_costing_items
  WHERE id = p_costing_item_id;

  IF v_item.id IS NULL THEN
    RAISE EXCEPTION 'costing item % not found', p_costing_item_id;
  END IF;

  -- Fetch parent file details
  SELECT * INTO v_file
  FROM public.product_based_costing_files
  WHERE id = v_item.product_based_costing_file_id;

  IF v_file.id IS NULL THEN
    RAISE EXCEPTION 'costing file % not found', v_item.product_based_costing_file_id;
  END IF;

  -- Check permissions
  IF NOT (public.can_admin_manage_costing_file(v_file.tenant_id) OR public.can_staff_access_costing_file(v_file.tenant_id)) THEN
    RAISE EXCEPTION 'access denied for tenant %', v_file.tenant_id;
  END IF;

  IF v_file.billing_profile_id IS NULL OR v_item.product_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Open quantity calculation: confirmed_quantity - ordered_quantity
  v_confirmed_qty := coalesce(v_item.confirmed_quantity, v_item.quantity, 0);
  v_ordered_qty := coalesce(v_item.ordered_quantity, 0);
  v_open_qty := v_confirmed_qty - v_ordered_qty;

  -- Delete from backlog if status is rejected OR open_qty <= 0
  IF v_item.status = 'rejected' OR v_open_qty <= 0 THEN
    DELETE FROM public.product_based_costing_backlog_items
    WHERE tenant_id = v_file.tenant_id
      AND billing_profile_id = v_file.billing_profile_id
      AND product_id = v_item.product_id;

    RETURN NULL;
  END IF;

  -- Upsert backlog if status != 'rejected' AND open_qty > 0
  IF v_open_qty > 0 THEN
    SELECT product_weight, package_weight INTO v_prod
    FROM public.products
    WHERE id = v_item.product_id;

    INSERT INTO public.product_based_costing_backlog_items (
      tenant_id,
      billing_profile_id,
      product_id,
      open_quantity,
      name,
      image_url,
      barcode,
      product_code,
      price_gbp,
      product_weight,
      package_weight,
      last_costing_file_id,
      last_costing_item_id,
      updated_at
    )
    VALUES (
      v_file.tenant_id,
      v_file.billing_profile_id,
      v_item.product_id,
      v_open_qty,
      v_item.name,
      v_item.image_url,
      v_item.barcode,
      v_item.product_code,
      v_item.price_gbp,
      coalesce(v_item.product_weight::numeric, v_prod.product_weight),
      coalesce(v_item.package_weight::numeric, v_prod.package_weight),
      v_file.id,
      v_item.id,
      now()
    )
    ON CONFLICT (tenant_id, billing_profile_id, product_id)
    DO UPDATE SET
      open_quantity = EXCLUDED.open_quantity,
      name = EXCLUDED.name,
      image_url = EXCLUDED.image_url,
      barcode = EXCLUDED.barcode,
      product_code = EXCLUDED.product_code,
      price_gbp = EXCLUDED.price_gbp,
      product_weight = EXCLUDED.product_weight,
      package_weight = EXCLUDED.package_weight,
      last_costing_file_id = EXCLUDED.last_costing_file_id,
      last_costing_item_id = EXCLUDED.last_costing_item_id,
      updated_at = now()
    RETURNING * INTO v_backlog_row;

    RETURN v_backlog_row;
  END IF;

  RETURN NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_pbc_backlog_from_item(bigint) TO authenticated;

-- 2. Fix add_pbc_backlog_to_file
CREATE OR REPLACE FUNCTION public.add_pbc_backlog_to_file(
  p_file_id bigint,
  p_backlog_ids bigint[]
)
RETURNS bigint[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_file public.product_based_costing_files%ROWTYPE;
  v_backlog public.product_based_costing_backlog_items%ROWTYPE;
  v_new_item_id bigint;
  v_added_ids bigint[] := ARRAY[]::bigint[];
BEGIN
  SELECT * INTO v_file
  FROM public.product_based_costing_files
  WHERE id = p_file_id;

  IF v_file.id IS NULL THEN
    RAISE EXCEPTION 'costing file % not found', p_file_id;
  END IF;

  IF NOT (public.can_admin_manage_costing_file(v_file.tenant_id) OR public.can_staff_access_costing_file(v_file.tenant_id)) THEN
    RAISE EXCEPTION 'access denied for tenant %', v_file.tenant_id;
  END IF;

  IF v_file.billing_profile_id IS NULL THEN
    RAISE EXCEPTION 'costing file % must have a billing_profile_id assigned before consuming backlog', p_file_id;
  END IF;

  IF p_backlog_ids IS NULL OR array_length(p_backlog_ids, 1) IS NULL THEN
    RETURN v_added_ids;
  END IF;

  FOR v_backlog IN
    SELECT *
    FROM public.product_based_costing_backlog_items
    WHERE id = ANY(p_backlog_ids)
      AND tenant_id = v_file.tenant_id
      AND billing_profile_id = v_file.billing_profile_id
  LOOP
    INSERT INTO public.product_based_costing_items (
      product_based_costing_file_id,
      product_id,
      name,
      image_url,
      quantity,
      delivered_quantity,
      price_gbp,
      product_weight,
      package_weight,
      barcode,
      product_code,
      status,
      created_by_email
    )
    VALUES (
      v_file.id,
      v_backlog.product_id,
      v_backlog.name,
      v_backlog.image_url,
      v_backlog.open_quantity,
      NULL,
      v_backlog.price_gbp,
      v_backlog.product_weight::integer,
      v_backlog.package_weight::integer,
      v_backlog.barcode,
      v_backlog.product_code,
      'pending',
      auth.email()
    )
    RETURNING id INTO v_new_item_id;

    DELETE FROM public.product_based_costing_backlog_items
    WHERE id = v_backlog.id;

    v_added_ids := array_append(v_added_ids, v_new_item_id);
  END LOOP;

  RETURN v_added_ids;
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_pbc_backlog_to_file(bigint, bigint[]) TO authenticated;

-- 3. Fix add_child_line_to_parent_shipment
CREATE OR REPLACE FUNCTION public.add_child_line_to_parent_shipment(
  p_parent_shipment_id bigint,
  p_source_type text,
  p_source_id bigint
)
RETURNS public.global_shipment_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_shipment public.global_shipments%ROWTYPE;
  v_costing_item public.product_based_costing_items%ROWTYPE;
  v_costing_file public.product_based_costing_files%ROWTYPE;
  v_shop_order_item public.shop_order_items%ROWTYPE;
  v_shop_order public.shop_orders%ROWTYPE;
  v_prod RECORD;
  v_child_tenant_id bigint;
  v_row public.global_shipment_items%ROWTYPE;
BEGIN
  SELECT * INTO v_shipment
  FROM public.global_shipments
  WHERE id = p_parent_shipment_id;

  IF v_shipment.id IS NULL THEN
    RAISE EXCEPTION 'parent shipment % not found', p_parent_shipment_id;
  END IF;

  IF NOT (public.can_admin_manage_shipment(v_shipment.tenant_id) OR public.can_staff_access_shipment(v_shipment.tenant_id)) THEN
    RAISE EXCEPTION 'access denied for parent shipment tenant %', v_shipment.tenant_id;
  END IF;

  IF p_source_type = 'costing_item' THEN
    SELECT * INTO v_costing_item
    FROM public.product_based_costing_items
    WHERE id = p_source_id;

    IF v_costing_item.id IS NULL THEN
      RAISE EXCEPTION 'costing item % not found', p_source_id;
    END IF;

    SELECT * INTO v_costing_file
    FROM public.product_based_costing_files
    WHERE id = v_costing_item.product_based_costing_file_id;

    IF v_costing_file.id IS NULL THEN
      RAISE EXCEPTION 'costing file % not found', v_costing_item.product_based_costing_file_id;
    END IF;

    IF v_costing_file.status <> 'ready_for_shipment' THEN
      RAISE EXCEPTION 'costing file must be in ready_for_shipment status to pull items';
    END IF;

    IF v_costing_item.status NOT IN ('accepted', 'partial') THEN
      RAISE EXCEPTION 'costing item must be accepted or partial to pull to shipment';
    END IF;

    IF coalesce(v_costing_item.ordered_quantity, 0) <= 0 THEN
      RAISE EXCEPTION 'costing item ordered_quantity must be greater than 0';
    END IF;

    IF v_costing_item.assigned_shipment_id IS NOT NULL OR v_costing_item.status = 'on_shipment' THEN
      RAISE EXCEPTION 'costing item is already assigned to a shipment';
    END IF;

    IF v_costing_item.product_id IS NULL THEN
      RAISE EXCEPTION 'costing item must have a product_id to add to shipment';
    END IF;

    v_child_tenant_id := v_costing_file.tenant_id;

    SELECT product_weight, package_weight INTO v_prod
    FROM public.products
    WHERE id = v_costing_item.product_id;

    INSERT INTO public.global_shipment_items (
      shipment_id,
      product_id,
      name,
      ordered_quantity,
      image_url,
      add_method,
      purchase_price,
      product_weight,
      package_weight,
      barcode,
      product_code,
      source_child_tenant_id,
      source_type,
      source_id
    )
    VALUES (
      p_parent_shipment_id,
      v_costing_item.product_id,
      v_costing_item.name,
      v_costing_item.ordered_quantity,
      v_costing_item.image_url,
      'costing'::public.global_shipment_item_add_method,
      coalesce(v_costing_item.price_gbp, 0.00),
      coalesce(v_costing_item.product_weight::numeric, v_prod.product_weight, 0.00),
      coalesce(v_costing_item.package_weight::numeric, v_prod.package_weight, 0.00),
      v_costing_item.barcode,
      v_costing_item.product_code,
      v_child_tenant_id,
      'costing_item',
      v_costing_item.id
    )
    RETURNING * INTO v_row;

    UPDATE public.product_based_costing_items
    SET assigned_shipment_id = p_parent_shipment_id,
        status = 'on_shipment'
    WHERE id = p_source_id;

  ELSIF p_source_type = 'shop_order_item' THEN
    SELECT o.tenant_id INTO v_child_tenant_id
    FROM public.shop_order_items oi
    INNER JOIN public.shop_orders o ON o.id = oi.order_id
    WHERE oi.id = p_source_id;

    SELECT * INTO v_shop_order_item
    FROM public.shop_order_items
    WHERE id = p_source_id;

    IF v_shop_order_item.id IS NULL THEN
      RAISE EXCEPTION 'shop order item % not found', p_source_id;
    END IF;

    IF v_shop_order_item.product_id IS NULL THEN
      RAISE EXCEPTION 'shop order item must have a product_id to add to shipment';
    END IF;

    SELECT product_weight, package_weight INTO v_prod
    FROM public.products
    WHERE id = v_shop_order_item.product_id;

    INSERT INTO public.global_shipment_items (
      shipment_id,
      product_id,
      name,
      ordered_quantity,
      image_url,
      add_method,
      purchase_price,
      product_weight,
      package_weight,
      barcode,
      product_code,
      source_child_tenant_id,
      source_type,
      source_id
    )
    VALUES (
      p_parent_shipment_id,
      v_shop_order_item.product_id,
      v_shop_order_item.title,
      v_shop_order_item.quantity,
      v_shop_order_item.image_url,
      'order'::public.global_shipment_item_add_method,
      v_shop_order_item.unit_price,
      coalesce(v_shop_order_item.product_weight::numeric, v_prod.product_weight, 0.00),
      coalesce(v_shop_order_item.package_weight::numeric, v_prod.package_weight, 0.00),
      v_shop_order_item.sku,
      v_shop_order_item.sku,
      v_child_tenant_id,
      'shop_order_item',
      v_shop_order_item.id
    )
    RETURNING * INTO v_row;
  ELSE
    RAISE EXCEPTION 'invalid source_type %', p_source_type;
  END IF;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_child_line_to_parent_shipment(bigint, text, bigint) TO authenticated;
