-- AFTER DELETE on product_based_costing_items called upsert_pbc_backlog_from_item(OLD.id).
-- That function re-selects the row, which is already gone, so DELETE raised
-- "costing item N not found" (P0001) and rolled back.
-- On DELETE, use OLD to refresh backlog from a remaining line or remove it.

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
  v_price_gbp numeric;
BEGIN
  SELECT * INTO v_item
  FROM public.product_based_costing_items
  WHERE id = p_costing_item_id;

  IF v_item.id IS NULL THEN
    RETURN NULL;
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

  IF v_tenant_id IS NOT NULL AND NOT (
    public.can_admin_manage_costing_file(v_tenant_id)
    OR public.can_staff_access_costing_file(v_tenant_id)
  ) THEN
    RAISE EXCEPTION 'access denied for tenant %', v_tenant_id;
  END IF;

  IF v_tenant_id IS NULL OR v_file.billing_profile_id IS NULL OR v_item.product_id IS NULL THEN
    RETURN NULL;
  END IF;

  v_confirmed_qty := coalesce(v_item.confirmed_quantity, v_item.quantity, 0);
  v_ordered_qty := coalesce(v_item.ordered_quantity, 0);
  v_open_qty := v_confirmed_qty - v_ordered_qty;

  IF v_confirmed_qty <= 0 OR v_open_qty <= 0 THEN
    DELETE FROM public.product_based_costing_backlog_items
    WHERE tenant_id = v_tenant_id
      AND billing_profile_id = v_file.billing_profile_id
      AND product_id = v_item.product_id;
    RETURN NULL;
  END IF;

  SELECT
    p.name,
    p.image_url,
    p.list_price_amount,
    p.product_weight,
    p.package_weight,
    p.barcode,
    p.product_code,
    p.brand,
    gc.code AS list_price_currency_code
  INTO v_prod
  FROM public.products p
  LEFT JOIN public.global_currencies gc ON gc.id = p.list_price_currency_id
  WHERE p.id = v_item.product_id;

  v_price_gbp := coalesce(
    v_item.price_gbp,
    CASE
      WHEN v_prod.list_price_currency_code IS NULL OR v_prod.list_price_currency_code = 'GBP'
        THEN v_prod.list_price_amount
      ELSE NULL
    END
  );

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
    coalesce(v_item.name, v_prod.name),
    coalesce(v_item.image_url, v_prod.image_url),
    coalesce(v_item.barcode, v_prod.barcode),
    coalesce(v_item.product_code, v_prod.product_code),
    v_price_gbp,
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
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_pbc_backlog_from_item(bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.trg_fn_auto_upsert_pbc_backlog()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_file public.product_based_costing_files%ROWTYPE;
  v_tenant_id bigint;
  v_other_id bigint;
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.product_id IS NOT NULL AND OLD.product_based_costing_file_id IS NOT NULL THEN
      SELECT * INTO v_file
      FROM public.product_based_costing_files
      WHERE id = OLD.product_based_costing_file_id;

      IF v_file.id IS NOT NULL THEN
        v_tenant_id := v_file.tenant_id;
        IF v_tenant_id IS NULL AND v_file.billing_profile_id IS NOT NULL THEN
          SELECT tenant_id INTO v_tenant_id
          FROM public.billing_profiles
          WHERE id = v_file.billing_profile_id;
        END IF;

        SELECT pci.id INTO v_other_id
        FROM public.product_based_costing_items pci
        INNER JOIN public.product_based_costing_files pcf
          ON pcf.id = pci.product_based_costing_file_id
        WHERE pci.product_id = OLD.product_id
          AND pcf.billing_profile_id IS NOT DISTINCT FROM v_file.billing_profile_id
        ORDER BY pci.updated_at DESC NULLS LAST, pci.id DESC
        LIMIT 1;

        IF v_other_id IS NOT NULL THEN
          PERFORM public.upsert_pbc_backlog_from_item(v_other_id);
        ELSIF v_tenant_id IS NOT NULL AND v_file.billing_profile_id IS NOT NULL THEN
          DELETE FROM public.product_based_costing_backlog_items
          WHERE tenant_id = v_tenant_id
            AND billing_profile_id = v_file.billing_profile_id
            AND product_id = OLD.product_id;
        END IF;
      END IF;
    END IF;

    RETURN OLD;
  END IF;

  PERFORM public.upsert_pbc_backlog_from_item(NEW.id);
  RETURN NEW;
END;
$$;
