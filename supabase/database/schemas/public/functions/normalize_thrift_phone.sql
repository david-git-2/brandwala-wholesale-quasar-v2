CREATE FUNCTION public.normalize_thrift_phone (
  p_phone text
)
  RETURNS text
  LANGUAGE sql
  IMMUTABLE
  PARALLEL SAFE
  AS $function$
  SELECT regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
$function$;

COMMENT ON FUNCTION public.normalize_thrift_phone(text) IS 'Digits-only thrift customer phone key; empty/null input → empty string.';

GRANT ALL ON FUNCTION public.normalize_thrift_phone(text) TO anon;

GRANT ALL ON FUNCTION public.normalize_thrift_phone(text) TO authenticated;

GRANT ALL ON FUNCTION public.normalize_thrift_phone(text) TO service_role;