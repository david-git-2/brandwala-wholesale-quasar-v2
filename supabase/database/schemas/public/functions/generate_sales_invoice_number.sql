CREATE FUNCTION public.generate_sales_invoice_number (
  p_tenant_id    bigint,
  p_invoice_type public.global_invoice_type,
  p_date         date                       DEFAULT CURRENT_DATE
)
  RETURNS text
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_type_code text;
  v_date_key text;
  v_next bigint;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;

  IF p_invoice_type IS NULL THEN
    RAISE EXCEPTION 'invoice_type is required';
  END IF;

  v_type_code := CASE p_invoice_type
    WHEN 'wholesale'::public.global_invoice_type THEN 'WS'
    WHEN 'retail'::public.global_invoice_type THEN 'RT'
    WHEN 'dropship'::public.global_invoice_type THEN 'DS'
    ELSE 'INV'
  END;

  v_date_key := to_char(COALESCE(p_date, CURRENT_DATE), 'YYYYMMDD');

  INSERT INTO public.sales_invoice_counters (tenant_id, invoice_type, date_key, last_value)
  VALUES (p_tenant_id, p_invoice_type, v_date_key, 1)
  ON CONFLICT (tenant_id, invoice_type, date_key)
  DO UPDATE
    SET last_value = public.sales_invoice_counters.last_value + 1,
        updated_at = now()
  RETURNING last_value INTO v_next;

  RETURN 'INV-' || v_type_code || '-' || v_date_key || '-' || lpad(v_next::text, 4, '0');
END;
$function$;

GRANT ALL ON FUNCTION public.generate_sales_invoice_number(bigint, public.global_invoice_type, date) TO anon;

GRANT ALL ON FUNCTION public.generate_sales_invoice_number(bigint, public.global_invoice_type, date) TO authenticated;

GRANT ALL ON FUNCTION public.generate_sales_invoice_number(bigint, public.global_invoice_type, date) TO service_role;