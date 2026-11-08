CREATE FUNCTION public.format_assigned_document_number (
  p_tenant_id bigint,
  p_doc_type  text,
  p_seq       bigint,
  p_at        timestamp with time zone DEFAULT now()
)
  RETURNS text
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  cfg public.document_number_configs%ROWTYPE;
  v_tz text;
  v_local timestamp;
  v_period text;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;

  IF p_doc_type IS NULL OR btrim(p_doc_type) = '' THEN
    RAISE EXCEPTION 'doc_type is required';
  END IF;

  IF p_seq IS NULL OR p_seq < 1 THEN
    RETURN NULL;
  END IF;

  cfg := public._resolve_document_number_config(p_tenant_id, p_doc_type);
  v_tz := public._document_number_tenant_timezone(p_tenant_id, cfg.timezone);
  v_local := coalesce(p_at, now()) AT TIME ZONE v_tz;

  v_period := CASE cfg.period
    WHEN 'day'::text THEN to_char(v_local, 'YYMMDD')
    WHEN 'month'::text THEN to_char(v_local, 'YYMM')
    WHEN 'year'::text THEN to_char(v_local, 'YYYY')
    ELSE ''
  END;

  RETURN public._document_number_format(cfg, NULL::text, v_period, p_seq);
END;
$function$;

GRANT ALL ON FUNCTION public.format_assigned_document_number(bigint, text, bigint, timestamp with time zone) TO anon;

GRANT ALL ON FUNCTION public.format_assigned_document_number(bigint, text, bigint, timestamp with time zone) TO authenticated;

GRANT ALL ON FUNCTION public.format_assigned_document_number(bigint, text, bigint, timestamp with time zone) TO service_role;
