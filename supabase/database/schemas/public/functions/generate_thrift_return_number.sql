CREATE FUNCTION public.generate_thrift_return_number (
  p_tenant_id bigint,
  p_date      timestamp with time zone DEFAULT now()
)
  RETURNS text
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_year_month TEXT;
  v_next BIGINT;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;

  v_year_month := to_char(COALESCE(p_date, NOW()), 'YYYY-MM');

  INSERT INTO public.thrift_return_counters (tenant_id, year_month, last_value)
  VALUES (p_tenant_id, v_year_month, 1)
  ON CONFLICT (tenant_id, year_month)
  DO UPDATE
    SET last_value = public.thrift_return_counters.last_value + 1
  RETURNING last_value INTO v_next;

  RETURN 'RET-' || v_year_month || '-' || lpad(v_next::TEXT, 5, '0');
END;
$function$;

GRANT ALL ON FUNCTION public.generate_thrift_return_number(bigint, timestamp WITH time zone) TO anon;

GRANT ALL ON FUNCTION public.generate_thrift_return_number(bigint, timestamp WITH time zone) TO authenticated;

GRANT ALL ON FUNCTION public.generate_thrift_return_number(bigint, timestamp WITH time zone) TO service_role;