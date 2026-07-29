-- Phase 2 RPCs for Product Based Costing Backlog and Shipment

-- 1. RPC: upsert_pbc_backlog_from_item
CREATE OR REPLACE FUNCTION public.upsert_pbc_backlog_from_item(p_costing_item_id bigint)
RETURNS public.product_based_costing_backlog_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item record;
  v_file record;
  v_prod record;
  v_open_qty integer;
  v_backlog_row public.product_based_costing_backlog_items;
BEGIN
  -- Fetch item details
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

  -- Check permissions: user must be able to manage or access costing file for tenant
  IF NOT (public.can_admin_manage_costing_file(v_file.tenant_id) OR public.can_staff_access_costing_file(v_file.tenant_id)) THEN
    RAISE EXCEPTION 'access denied for tenant %', v_file.tenant_id;
  END IF;

  -- If billing_profile_id is missing or product_id is missing, cannot track backlog
  IF v_file.billing_profile_id IS NULL OR v_item.product_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Calculate open quantity
  v_open_qty := coalesce(v_item.quantity, 0) - coalesce(v_item.delivered_quantity, 0);

  -- If status is rejected OR open_quantity <= 0: delete any existing open backlog item
  IF v_item.status = 'rejected' OR v_open_qty <= 0 THEN
    DELETE FROM public.product_based_costing_backlog_items
    WHERE tenant_id = v_file.tenant_id
      AND billing_profile_id = v_file.billing_profile_id
      AND product_id = v_item.product_id;

    RETURN NULL;
  END IF;

  -- If status IN ('accepted', 'unavailable') AND v_open_qty > 0: upsert backlog item
  IF v_item.status IN ('accepted', 'unavailable') AND v_open_qty > 0 THEN
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
      v_item.price_in_web_gbp,
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


-- 2. RPC: list_pbc_backlog_items
CREATE OR REPLACE FUNCTION public.list_pbc_backlog_items(
  p_tenant_id bigint,
  p_billing_profile_id bigint
)
RETURNS TABLE (
  id bigint,
  tenant_id bigint,
  billing_profile_id bigint,
  product_id bigint,
  open_quantity integer,
  name text,
  image_url text,
  barcode text,
  product_code text,
  price_gbp numeric,
  product_weight numeric,
  package_weight numeric,
  note text,
  last_costing_file_id bigint,
  last_costing_item_id bigint,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  IF NOT (public.can_admin_manage_costing_file(p_tenant_id) OR public.can_staff_access_costing_file(p_tenant_id)) THEN
    RAISE EXCEPTION 'access denied for tenant %', p_tenant_id;
  END IF;

  RETURN QUERY
  SELECT
    bi.id,
    bi.tenant_id,
    bi.billing_profile_id,
    bi.product_id,
    bi.open_quantity,
    bi.name,
    bi.image_url,
    bi.barcode,
    bi.product_code,
    bi.price_gbp,
    bi.product_weight,
    bi.package_weight,
    bi.note,
    bi.last_costing_file_id,
    bi.last_costing_item_id,
    bi.created_at,
    bi.updated_at
  FROM public.product_based_costing_backlog_items bi
  WHERE bi.tenant_id = p_tenant_id
    AND bi.billing_profile_id = p_billing_profile_id
  ORDER BY bi.updated_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_pbc_backlog_items(bigint, bigint) TO authenticated;


-- 3. RPC: add_pbc_backlog_to_costing_file
CREATE OR REPLACE FUNCTION public.add_pbc_backlog_to_costing_file(
  p_file_id bigint,
  p_backlog_ids bigint[]
)
RETURNS SETOF bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_file record;
  v_backlog record;
  v_new_item_id bigint;
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
    RETURN;
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
      price_in_web_gbp,
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

    -- Delete consumed backlog item
    DELETE FROM public.product_based_costing_backlog_items
    WHERE id = v_backlog.id;

    RETURN NEXT v_new_item_id;
  END LOOP;

  RETURN;
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_pbc_backlog_to_costing_file(bigint, bigint[]) TO authenticated;


-- 4. Harden list_child_procurement_lines to include costing union eligibility check (accepted + delivered_quantity > 0)
DROP FUNCTION IF EXISTS public.list_child_procurement_lines(bigint, bigint, text, integer, integer) CASCADE;

CREATE OR REPLACE FUNCTION public.list_child_procurement_lines(
  p_parent_tenant_id bigint,
  p_child_tenant_id bigint DEFAULT NULL,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 100,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  source_type text,
  source_id bigint,
  child_tenant_id bigint,
  child_tenant_name text,
  name text,
  product_id bigint,
  quantity integer,
  cost_bdt numeric,
  price_gbp numeric,
  image_url text,
  barcode text,
  product_code text,
  reference_label text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  IF NOT public.user_can_manage_parent_tenant(p_parent_tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  RETURN QUERY
  (
    SELECT
      'order_item'::text AS source_type,
      oi.id AS source_id,
      o.tenant_id AS child_tenant_id,
      t.name AS child_tenant_name,
      oi.name,
      oi.product_id,
      greatest(coalesce(oi.ordered_quantity, 0), 0)::integer AS quantity,
      oi.cost_bdt,
      oi.price_gbp,
      oi.image_url,
      NULL::text AS barcode,
      NULL::text AS product_code,
      ('Order #' || o.id::text || ' — ' || o.name) AS reference_label
    FROM public.order_items oi
    INNER JOIN public.orders o ON o.id = oi.order_id
    INNER JOIN public.tenants t ON t.id = o.tenant_id
    WHERE o.parent_tenant_id = p_parent_tenant_id
      AND t.parent_id = p_parent_tenant_id
      AND (p_child_tenant_id IS NULL OR o.tenant_id = p_child_tenant_id)
      AND oi.shipment_id IS NULL
      AND coalesce(oi.ordered_quantity, 0) > 0
      AND (
        p_search IS NULL OR trim(p_search) = ''
        OR oi.name ILIKE '%' || trim(p_search) || '%'
        OR o.name ILIKE '%' || trim(p_search) || '%'
      )
  )
  UNION ALL
  (
    SELECT
      'costing_item'::text AS source_type,
      pci.id AS source_id,
      pcf.tenant_id AS child_tenant_id,
      t.name AS child_tenant_name,
      pci.name,
      pci.product_id,
      greatest(coalesce(pci.delivered_quantity, 0), 0)::integer AS quantity,
      pci.offer_price AS cost_bdt,
      pci.price_in_web_gbp AS price_gbp,
      pci.image_url,
      pci.barcode,
      pci.product_code,
      ('Costing #' || pcf.id::text || ' — ' || coalesce(pcf.name, 'Untitled')) AS reference_label
    FROM public.product_based_costing_items pci
    INNER JOIN public.product_based_costing_files pcf ON pcf.id = pci.product_based_costing_file_id
    INNER JOIN public.tenants t ON t.id = pcf.tenant_id
    WHERE t.parent_id = p_parent_tenant_id
      AND (p_child_tenant_id IS NULL OR pcf.tenant_id = p_child_tenant_id)
      AND pci.assigned_shipment_id IS NULL
      AND pci.status = 'accepted'
      AND coalesce(pci.delivered_quantity, 0) > 0
      AND (
        p_search IS NULL OR trim(p_search) = ''
        OR pci.name ILIKE '%' || trim(p_search) || '%'
        OR pcf.name ILIKE '%' || trim(p_search) || '%'
      )
  )
  UNION ALL
  (
    SELECT
      'shop_order_item'::text AS source_type,
      oi.id AS source_id,
      o.tenant_id AS child_tenant_id,
      t.name AS child_tenant_name,
      oi.name,
      oi.product_id,
      greatest(coalesce(oi.ordered_quantity, 0), 0)::integer AS quantity,
      CASE WHEN gc.code = 'BDT' THEN oi.final_price_amount ELSE NULL::numeric END AS cost_bdt,
      CASE WHEN gc.code = 'GBP' THEN oi.final_price_amount ELSE NULL::numeric END AS price_gbp,
      oi.image_url,
      p.barcode,
      p.product_code,
      ('Shop Order #' || o.order_no || ' — ' || o.name) AS reference_label
    FROM public.shop_order_items oi
    INNER JOIN public.shop_orders o ON o.id = oi.order_id
    INNER JOIN public.tenants t ON t.id = o.tenant_id
    LEFT JOIN public.products p ON p.id = oi.product_id
    LEFT JOIN public.global_currencies gc ON gc.id = oi.final_price_currency_id
    WHERE o.status = 'placed'
      AND oi.procurement_pulled = false
      AND o.shop_type_snapshot = 'vendor_catalog'
      AND t.parent_id = p_parent_tenant_id
      AND (p_child_tenant_id IS NULL OR o.tenant_id = p_child_tenant_id)
      AND (
        p_search IS NULL OR trim(p_search) = ''
        OR oi.name ILIKE '%' || trim(p_search) || '%'
        OR o.name ILIKE '%' || trim(p_search) || '%'
      )
  )
  ORDER BY child_tenant_name, source_type, source_id
  LIMIT greatest(coalesce(p_limit, 100), 1)
  OFFSET greatest(coalesce(p_offset, 0), 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_child_procurement_lines(bigint, bigint, text, integer, integer) TO authenticated;


-- 5. Harden add_child_line_to_parent_shipment for costing_item (require status = accepted, delivered_quantity > 0, set ordered_quantity = delivered_quantity)
DROP FUNCTION IF EXISTS public.add_child_line_to_parent_shipment(bigint, text, bigint) CASCADE;

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
  v_shipment public.global_shipments;
  v_row public.global_shipment_items;
  v_source_type text;
  v_child_tenant_id bigint;
  v_prod record;
  v_vendor_id bigint;
  v_costing_item public.product_based_costing_items;
BEGIN
  v_source_type := lower(trim(coalesce(p_source_type, '')));

  IF v_source_type NOT IN ('order_item', 'costing_item', 'shop_order_item') THEN
    RAISE EXCEPTION 'invalid source_type: %', p_source_type;
  END IF;

  SELECT * INTO v_shipment
  FROM public.global_shipments
  WHERE id = p_parent_shipment_id;

  IF v_shipment.id IS NULL THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.user_can_manage_parent_tenant(v_shipment.parent_tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF v_source_type = 'order_item' THEN
    -- Legacy Order Pull
    SELECT o.tenant_id INTO v_child_tenant_id
    FROM public.order_items oi
    INNER JOIN public.orders o ON o.id = oi.order_id
    WHERE oi.id = p_source_id
      AND o.parent_tenant_id = v_shipment.parent_tenant_id
      AND oi.shipment_id IS NULL;

    IF v_child_tenant_id IS NULL THEN
      RAISE EXCEPTION 'order item not available for procurement';
    END IF;

    SELECT barcode, product_code, product_weight, package_weight INTO v_prod
    FROM public.products
    WHERE id = (SELECT product_id FROM public.order_items WHERE id = p_source_id);

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
    SELECT
      p_parent_shipment_id,
      oi.product_id,
      oi.name,
      greatest(coalesce(oi.ordered_quantity, 0), 0),
      oi.image_url,
      'order'::public.global_shipment_item_add_method,
      coalesce(oi.price_gbp, 0.00),
      coalesce(v_prod.product_weight, 0.00),
      coalesce(v_prod.package_weight, 0.00),
      v_prod.barcode,
      v_prod.product_code,
      v_child_tenant_id,
      'order_item',
      oi.id
    FROM public.order_items oi
    WHERE oi.id = p_source_id
    RETURNING * INTO v_row;

    UPDATE public.order_items
    SET shipment_id = p_parent_shipment_id
    WHERE id = p_source_id;

  ELSIF v_source_type = 'costing_item' THEN
    -- Costing Pull with hardened validation
    SELECT pci.* INTO v_costing_item
    FROM public.product_based_costing_items pci
    INNER JOIN public.product_based_costing_files pcf ON pcf.id = pci.product_based_costing_file_id
    INNER JOIN public.tenants t ON t.id = pcf.tenant_id
    WHERE pci.id = p_source_id
      AND t.parent_id = v_shipment.parent_tenant_id
      AND pci.assigned_shipment_id IS NULL;

    IF v_costing_item.id IS NULL THEN
      RAISE EXCEPTION 'costing item not available for procurement';
    END IF;

    IF v_costing_item.status <> 'accepted' THEN
      RAISE EXCEPTION 'only accepted costing items can be added to a shipment';
    END IF;

    IF coalesce(v_costing_item.delivered_quantity, 0) <= 0 THEN
      RAISE EXCEPTION 'costing item delivered_quantity must be greater than 0 to add to shipment';
    END IF;

    IF v_costing_item.product_id IS NULL THEN
      RAISE EXCEPTION 'costing item must have a product_id to add to shipment';
    END IF;

    SELECT pcf.tenant_id INTO v_child_tenant_id
    FROM public.product_based_costing_files pcf
    WHERE pcf.id = v_costing_item.product_based_costing_file_id;

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
      v_costing_item.delivered_quantity,
      v_costing_item.image_url,
      'costing'::public.global_shipment_item_add_method,
      coalesce(v_costing_item.price_in_web_gbp, 0.00),
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

  ELSIF v_source_type = 'shop_order_item' THEN
    -- Shop Order Pull
    SELECT o.tenant_id INTO v_child_tenant_id
    FROM public.shop_order_items oi
    INNER JOIN public.shop_orders o ON o.id = oi.order_id
    INNER JOIN public.tenants t ON t.id = o.tenant_id
    WHERE oi.id = p_source_id
      AND t.parent_id = v_shipment.parent_tenant_id
      AND oi.procurement_pulled = false
      AND o.status = 'placed';

    IF v_child_tenant_id IS NULL THEN
      RAISE EXCEPTION 'shop order item not available for procurement';
    END IF;

    SELECT barcode, product_code, product_weight, package_weight INTO v_prod
    FROM public.products
    WHERE id = (SELECT product_id FROM public.shop_order_items WHERE id = p_source_id);

    -- Try to match vendor by vendor_code of the shop
    SELECT v.id INTO v_vendor_id
    FROM public.shop_order_items oi
    JOIN public.shop_orders o ON o.id = oi.order_id
    JOIN public.shops s ON s.id = o.shop_id
    JOIN public.vendors v ON v.code = s.vendor_code AND v.tenant_id = o.tenant_id
    WHERE oi.id = p_source_id
    LIMIT 1;

    INSERT INTO public.global_shipment_items (
      shipment_id,
      product_id,
      vendor_id,
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
    SELECT
      p_parent_shipment_id,
      oi.product_id,
      v_vendor_id,
      oi.name,
      greatest(coalesce(oi.quantity, 0), 0),
      oi.image_url,
      'order'::public.global_shipment_item_add_method,
      coalesce(oi.final_price_amount, 0.00),
      coalesce(v_prod.product_weight, 0.00),
      coalesce(v_prod.package_weight, 0.00),
      v_prod.barcode,
      v_prod.product_code,
      v_child_tenant_id,
      'shop_order_item',
      oi.id
    FROM public.shop_order_items oi
    WHERE oi.id = p_source_id
    RETURNING * INTO v_row;

    UPDATE public.shop_order_items
    SET procurement_pulled = true
    WHERE id = p_source_id;

  END IF;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_child_line_to_parent_shipment(bigint, text, bigint) TO authenticated;
