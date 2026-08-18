-- add_pbc_backlog_to_costing_file still inserts legacy costing_file_items columns
-- (price_in_web_gbp, status, created_by_email). product_based_costing_items uses
-- price_gbp and never had price_in_web_gbp; status was dropped in 20260729170800.
-- Align INSERT with add_pbc_backlog_to_file. Keep SETOF bigint for the existing UI RPC.

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
  v_file public.product_based_costing_files%ROWTYPE;
  v_backlog public.product_based_costing_backlog_items%ROWTYPE;
  v_new_item_id bigint;
BEGIN
  SELECT * INTO v_file
  FROM public.product_based_costing_files
  WHERE id = p_file_id;

  IF v_file.id IS NULL THEN
    RAISE EXCEPTION 'costing file % not found', p_file_id;
  END IF;

  IF NOT (
    public.can_admin_manage_costing_file(v_file.tenant_id)
    OR public.can_staff_access_costing_file(v_file.tenant_id)
  ) THEN
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
      confirmed_quantity,
      delivered_quantity,
      price_gbp,
      product_weight,
      package_weight,
      barcode,
      product_code
    )
    VALUES (
      v_file.id,
      v_backlog.product_id,
      v_backlog.name,
      v_backlog.image_url,
      v_backlog.open_quantity,
      v_backlog.open_quantity,
      NULL,
      v_backlog.price_gbp,
      v_backlog.product_weight::integer,
      v_backlog.package_weight::integer,
      v_backlog.barcode,
      v_backlog.product_code
    )
    RETURNING id INTO v_new_item_id;

    DELETE FROM public.product_based_costing_backlog_items
    WHERE id = v_backlog.id;

    RETURN NEXT v_new_item_id;
  END LOOP;

  RETURN;
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_pbc_backlog_to_costing_file(bigint, bigint[]) TO authenticated;
