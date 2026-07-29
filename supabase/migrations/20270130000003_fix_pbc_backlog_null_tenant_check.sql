-- Fix null tenant_id constraint error on product_based_costing_backlog_items

-- 1. Auto-backfill tenant_id on product_based_costing_files where tenant_id IS NULL using billing_profile_id
UPDATE public.product_based_costing_files f
SET tenant_id = bp.tenant_id
FROM public.billing_profiles bp
WHERE f.billing_profile_id = bp.id
  AND f.tenant_id IS NULL;

-- 2. Trigger function to auto-populate tenant_id on product_based_costing_files from billing_profiles if tenant_id is missing
CREATE OR REPLACE FUNCTION public.trg_fn_pbc_files_auto_tenant_id()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.tenant_id IS NULL AND NEW.billing_profile_id IS NOT NULL THEN
    SELECT tenant_id INTO NEW.tenant_id
    FROM public.billing_profiles
    WHERE id = NEW.billing_profile_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pbc_files_auto_tenant_id ON public.product_based_costing_files;

CREATE TRIGGER trg_pbc_files_auto_tenant_id
BEFORE INSERT OR UPDATE OF billing_profile_id
ON public.product_based_costing_files
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_pbc_files_auto_tenant_id();

-- 3. Update upsert_pbc_backlog_from_item to safely check for NULL tenant_id
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

  -- Derive tenant_id: fallback to billing_profiles.tenant_id if file.tenant_id IS NULL
  v_tenant_id := v_file.tenant_id;
  IF v_tenant_id IS NULL AND v_file.billing_profile_id IS NOT NULL THEN
    SELECT tenant_id INTO v_tenant_id
    FROM public.billing_profiles
    WHERE id = v_file.billing_profile_id;
  END IF;

  -- Check permissions (if tenant_id exists)
  IF v_tenant_id IS NOT NULL AND NOT (public.can_admin_manage_costing_file(v_tenant_id) OR public.can_staff_access_costing_file(v_tenant_id)) THEN
    RAISE EXCEPTION 'access denied for tenant %', v_tenant_id;
  END IF;

  -- If required fields for backlog are missing, safely skip backlog upsert
  IF v_tenant_id IS NULL OR v_file.billing_profile_id IS NULL OR v_item.product_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- Open quantity calculation: confirmed_quantity - ordered_quantity
  v_confirmed_qty := coalesce(v_item.confirmed_quantity, v_item.quantity, 0);
  v_ordered_qty := coalesce(v_item.ordered_quantity, 0);
  v_open_qty := v_confirmed_qty - v_ordered_qty;

  -- Delete from backlog if status is rejected OR open_qty <= 0
  IF v_item.status = 'rejected' OR v_open_qty <= 0 THEN
    DELETE FROM public.product_based_costing_backlog_items
    WHERE tenant_id = v_tenant_id
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
      v_tenant_id,
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
