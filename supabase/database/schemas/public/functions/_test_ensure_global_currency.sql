CREATE FUNCTION public._test_ensure_global_currency (
  p_code   text,
  p_name   text DEFAULT NULL::text,
  p_symbol text DEFAULT NULL::text
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_id bigint;
  v_code text := upper(trim(p_code));
BEGIN
  SELECT gc.id INTO v_id FROM public.global_currencies gc WHERE gc.code = v_code LIMIT 1;
  IF v_id IS NOT NULL THEN
    RETURN v_id;
  END IF;

  INSERT INTO public.global_currencies (name, country, code, symbol, is_active, is_system)
  VALUES (
    coalesce(nullif(trim(p_name), ''), v_code),
    v_code,
    v_code,
    coalesce(nullif(trim(p_symbol), ''), v_code),
    true,
    true
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$function$;

GRANT ALL ON FUNCTION public._test_ensure_global_currency(text, text, text) TO anon;

GRANT ALL ON FUNCTION public._test_ensure_global_currency(text, text, text) TO authenticated;

GRANT ALL ON FUNCTION public._test_ensure_global_currency(text, text, text) TO service_role;