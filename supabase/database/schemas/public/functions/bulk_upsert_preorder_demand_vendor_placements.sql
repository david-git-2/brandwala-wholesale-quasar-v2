CREATE OR REPLACE FUNCTION public.bulk_upsert_preorder_demand_vendor_placements (
  p_tenant_id bigint,
  p_lines     jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_elem jsonb;
  v_source_type public.preorder_demand_source_type;
  v_source_id bigint;
  v_placements jsonb;
  v_updated integer := 0;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;
  IF p_lines IS NULL OR jsonb_typeof(p_lines) <> 'array' OR jsonb_array_length(p_lines) = 0 THEN
    RAISE EXCEPTION 'p_lines must be a non-empty json array';
  END IF;

  FOR v_elem IN SELECT value FROM jsonb_array_elements(p_lines)
  LOOP
    v_source_type := (v_elem->>'source_type')::public.preorder_demand_source_type;
    v_source_id := (v_elem->>'source_id')::bigint;
    v_placements := coalesce(v_elem->'vendor_placements', '[]'::jsonb);

    IF v_source_id IS NULL OR v_source_type IS NULL THEN
      RAISE EXCEPTION 'each line requires source_type and source_id';
    END IF;

    PERFORM public.upsert_preorder_demand(
      p_tenant_id,
      v_source_type,
      v_source_id,
      NULL,
      NULL,
      NULL,
      NULL,
      v_placements
    );
    v_updated := v_updated + 1;
  END LOOP;

  RETURN jsonb_build_object('updated_count', v_updated);
END;
$function$;

GRANT ALL ON FUNCTION public.bulk_upsert_preorder_demand_vendor_placements(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.bulk_upsert_preorder_demand_vendor_placements(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.bulk_upsert_preorder_demand_vendor_placements(bigint, jsonb) TO service_role;