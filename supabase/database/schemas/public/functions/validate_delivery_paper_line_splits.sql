CREATE FUNCTION public.validate_delivery_paper_line_splits (
  p_splits jsonb
)
  RETURNS boolean
  LANGUAGE plpgsql
  IMMUTABLE
  AS $function$
DECLARE
  v_elem jsonb;
  v_qty integer;
  v_status text;
BEGIN
  IF p_splits IS NULL OR jsonb_typeof(p_splits) <> 'array' THEN
    RETURN false;
  END IF;
  FOR v_elem IN SELECT value FROM jsonb_array_elements(p_splits)
  LOOP
    v_qty := coalesce((v_elem->>'quantity')::integer, 0);
    v_status := lower(trim(coalesce(v_elem->>'status', '')));
    IF v_qty <= 0 THEN
      RETURN false;
    END IF;
    IF v_status NOT IN ('packed', 'accepted', 'conditioned', 'rejected') THEN
      RETURN false;
    END IF;
  END LOOP;
  RETURN true;
END;
$function$;

GRANT ALL ON FUNCTION public.validate_delivery_paper_line_splits(jsonb) TO anon;

GRANT ALL ON FUNCTION public.validate_delivery_paper_line_splits(jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.validate_delivery_paper_line_splits(jsonb) TO service_role;