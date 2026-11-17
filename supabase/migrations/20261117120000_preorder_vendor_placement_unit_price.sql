-- Demand buy: optional unit_price on vendor_placements jsonb elements.

CREATE OR REPLACE FUNCTION public.validate_preorder_vendor_placements (
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
  v_unit_price numeric;
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
    IF v_elem ? 'unit_price' THEN
      BEGIN
        v_unit_price := (v_elem->>'unit_price')::numeric;
      EXCEPTION
        WHEN others THEN
          RETURN false;
      END;
      IF v_unit_price IS NULL OR v_unit_price < 0 THEN
        RETURN false;
      END IF;
    END IF;
  END LOOP;
  RETURN true;
END;
$function$;