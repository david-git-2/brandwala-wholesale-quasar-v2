CREATE FUNCTION public.add_demand_bucket_item_internal (
  p_tenant_id   bigint,
  p_profile_id  bigint,
  p_product_id  bigint,
  p_source_type public.demand_bucket_source_type,
  p_source_id   bigint                           DEFAULT NULL::bigint,
  p_snapshot    jsonb                            DEFAULT '{}'::jsonb,
  p_quantity    integer                          DEFAULT 1
)
  RETURNS public.customer_demand_bucket_items
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_row public.customer_demand_bucket_items;
  v_name text;
  v_image_url text;
  v_barcode text;
  v_product_code text;
  v_note text;
  v_quantity integer;
BEGIN
  IF p_tenant_id IS NULL OR p_profile_id IS NULL OR p_product_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id, profile_id, and product_id are required';
  END IF;

  v_quantity := greatest(coalesce(p_quantity, 1), 1);

  v_name := nullif(trim(coalesce(p_snapshot->>'name', '')), '');
  v_image_url := nullif(trim(coalesce(p_snapshot->>'image_url', '')), '');
  v_barcode := nullif(trim(coalesce(p_snapshot->>'barcode', '')), '');
  v_product_code := nullif(trim(coalesce(p_snapshot->>'product_code', '')), '');
  v_note := nullif(trim(coalesce(p_snapshot->>'note', '')), '');

  IF v_name IS NULL THEN
    SELECT
      coalesce(p.name, 'Item'),
      p.image_url,
      p.barcode,
      p.product_code
    INTO v_name, v_image_url, v_barcode, v_product_code
    FROM public.products p
    WHERE p.id = p_product_id;
  END IF;

  INSERT INTO public.customer_demand_bucket_items (
    tenant_id,
    profile_id,
    product_id,
    source_type,
    source_id,
    name,
    image_url,
    barcode,
    product_code,
    note,
    quantity,
    status
  ) VALUES (
    p_tenant_id,
    p_profile_id,
    p_product_id,
    p_source_type,
    p_source_id,
    coalesce(v_name, 'Item'),
    v_image_url,
    v_barcode,
    v_product_code,
    v_note,
    v_quantity,
    'open'
  )
  RETURNING * INTO v_row;

  RETURN v_row;
END;
$function$;

GRANT ALL ON FUNCTION public.add_demand_bucket_item_internal(bigint, bigint, bigint, public.demand_bucket_source_type, bigint, jsonb, integer) TO anon;

GRANT ALL ON FUNCTION public.add_demand_bucket_item_internal(bigint, bigint, bigint, public.demand_bucket_source_type, bigint, jsonb, integer) TO authenticated;

GRANT ALL ON FUNCTION public.add_demand_bucket_item_internal(bigint, bigint, bigint, public.demand_bucket_source_type, bigint, jsonb, integer) TO service_role;