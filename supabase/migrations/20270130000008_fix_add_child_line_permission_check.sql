-- Fix permission check in add_child_line_to_parent_shipment to use user_can_manage_parent_tenant

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

  IF NOT public.user_can_manage_parent_tenant(v_shipment.parent_tenant_id) THEN
    RAISE EXCEPTION 'access denied for parent shipment tenant %', v_shipment.parent_tenant_id;
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

    IF coalesce(v_costing_item.ordered_quantity, 0) <= 0 THEN
      RAISE EXCEPTION 'costing item ordered_quantity must be greater than 0';
    END IF;

    IF v_costing_item.assigned_shipment_id IS NOT NULL THEN
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
    SET assigned_shipment_id = p_parent_shipment_id
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

    UPDATE public.shop_order_items
    SET procurement_pulled = true
    WHERE id = p_source_id;
  ELSE
    RAISE EXCEPTION 'invalid source_type %', p_source_type;
  END IF;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_child_line_to_parent_shipment(bigint, text, bigint) TO authenticated;

NOTIFY pgrst, 'reload schema';
