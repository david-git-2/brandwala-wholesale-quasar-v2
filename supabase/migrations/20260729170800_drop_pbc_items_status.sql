-- Migration: Drop stored status column from product_based_costing_items table
-- 1. Re-define upsert_pbc_backlog_from_item without referencing v_item.status
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
  v_tenant_id bigint;
BEGIN
  SELECT * INTO v_item
  FROM public.product_based_costing_items
  WHERE id = p_costing_item_id;

  IF v_item.id IS NULL THEN
    RAISE EXCEPTION 'costing item % not found', p_costing_item_id;
  END IF;

  SELECT * INTO v_file
  FROM public.product_based_costing_files
  WHERE id = v_item.product_based_costing_file_id;

  IF v_file.id IS NULL THEN
    RAISE EXCEPTION 'costing file % not found', v_item.product_based_costing_file_id;
  END IF;

  v_tenant_id := v_file.tenant_id;
  IF v_tenant_id IS NULL AND v_file.billing_profile_id IS NOT NULL THEN
    SELECT tenant_id INTO v_tenant_id
    FROM public.billing_profiles
    WHERE id = v_file.billing_profile_id;
  END IF;

  IF v_tenant_id IS NOT NULL AND NOT (public.can_admin_manage_costing_file(v_tenant_id) OR public.can_staff_access_costing_file(v_tenant_id)) THEN
    RAISE EXCEPTION 'access denied for tenant %', v_tenant_id;
  END IF;

  IF v_tenant_id IS NULL OR v_file.billing_profile_id IS NULL OR v_item.product_id IS NULL THEN
    RETURN NULL;
  END IF;

  v_confirmed_qty := coalesce(v_item.confirmed_quantity, v_item.quantity, 0);
  v_ordered_qty := coalesce(v_item.ordered_quantity, 0);
  v_open_qty := v_confirmed_qty - v_ordered_qty;

  -- Delete from backlog if confirmed_qty <= 0 OR open_qty <= 0
  IF v_confirmed_qty <= 0 OR v_open_qty <= 0 THEN
    DELETE FROM public.product_based_costing_backlog_items
    WHERE tenant_id = v_tenant_id
      AND billing_profile_id = v_file.billing_profile_id
      AND product_id = v_item.product_id;

    RETURN NULL;
  END IF;

  -- Fetch product details
  SELECT name, image_url, price_gbp, product_weight, package_weight, barcode, product_code, brand
  INTO v_prod
  FROM public.products
  WHERE id = v_item.product_id;

  -- Upsert backlog entry
  INSERT INTO public.product_based_costing_backlog_items (
    tenant_id,
    billing_profile_id,
    product_id,
    name,
    image_url,
    price_gbp,
    product_weight,
    package_weight,
    barcode,
    product_code,
    brand,
    quantity,
    status
  )
  VALUES (
    v_tenant_id,
    v_file.billing_profile_id,
    v_item.product_id,
    coalesce(v_item.name, v_prod.name),
    coalesce(v_item.image_url, v_prod.image_url),
    coalesce(v_item.price_gbp, v_prod.price_gbp),
    coalesce(v_item.product_weight, v_prod.product_weight),
    coalesce(v_item.package_weight, v_prod.package_weight),
    coalesce(v_item.barcode, v_prod.barcode),
    coalesce(v_item.product_code, v_prod.product_code),
    coalesce(v_item.brand, v_prod.brand),
    v_open_qty,
    'backlog'
  )
  ON CONFLICT (tenant_id, billing_profile_id, product_id)
  DO UPDATE SET
    name = excluded.name,
    image_url = excluded.image_url,
    price_gbp = excluded.price_gbp,
    product_weight = excluded.product_weight,
    package_weight = excluded.package_weight,
    barcode = excluded.barcode,
    product_code = excluded.product_code,
    brand = excluded.brand,
    quantity = excluded.quantity,
    status = 'backlog',
    updated_at = now()
  RETURNING * INTO v_backlog_row;

  RETURN v_backlog_row;
END;
$$;

-- 2. Drop and recreate trigger without column 'status'
DROP TRIGGER IF EXISTS trg_pbc_items_auto_backlog ON public.product_based_costing_items;

CREATE TRIGGER trg_pbc_items_auto_backlog
AFTER INSERT OR UPDATE OF quantity, confirmed_quantity, ordered_quantity, product_id OR DELETE
ON public.product_based_costing_items
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_auto_upsert_pbc_backlog();

-- 3. Drop column status
ALTER TABLE public.product_based_costing_items
  DROP COLUMN IF EXISTS status;

