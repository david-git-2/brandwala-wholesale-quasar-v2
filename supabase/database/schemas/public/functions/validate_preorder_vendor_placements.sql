CREATE FUNCTION public.validate_preorder_vendor_placements (
  p_placements jsonb
)
  RETURNS boolean
  LANGUAGE plpgsql
  IMMUTABLE
  AS $function$
DECLARE
  v_elem jsonb;
  v_qty integer;
  v_code text;
BEGIN
  IF p_placements IS NULL THEN
    RETURN true;
  END IF;
  IF jsonb_typeof(p_placements) <> 'array' THEN
    RETURN false;
  END IF;
  FOR v_elem IN SELECT value FROM jsonb_array_elements(p_placements)
  LOOP
    v_code := nullif(trim(coalesce(v_elem->>'vendor_code', '')), '');
    v_qty := coalesce((v_elem->>'quantity')::integer, 0);
    IF v_code IS NULL OR v_qty <= 0 THEN
      RETURN false;
    END IF;
  END LOOP;
  RETURN true;
END;
$function$;

GRANT ALL ON FUNCTION public.validate_preorder_vendor_placements(jsonb) TO anon;

GRANT ALL ON FUNCTION public.validate_preorder_vendor_placements(jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.validate_preorder_vendor_placements(jsonb) TO service_role;