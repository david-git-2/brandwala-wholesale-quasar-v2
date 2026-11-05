CREATE FUNCTION public.normalize_customer_national_phone (
  p_phone text
)
  RETURNS text
  LANGUAGE sql
  IMMUTABLE
  SET search_path TO 'public'
  AS $function$
  select nullif(
    regexp_replace(
      regexp_replace(trim(coalesce(p_phone, '')), '[^0-9]', '', 'g'),
      '^0+',
      ''
    ),
    ''
  );
$function$;

GRANT ALL ON FUNCTION public.normalize_customer_national_phone(text) TO anon;

GRANT ALL ON FUNCTION public.normalize_customer_national_phone(text) TO authenticated;

GRANT ALL ON FUNCTION public.normalize_customer_national_phone(text) TO service_role;