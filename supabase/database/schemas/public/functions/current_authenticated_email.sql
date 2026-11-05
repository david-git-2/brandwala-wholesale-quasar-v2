CREATE FUNCTION public.current_authenticated_email()
  RETURNS text
  LANGUAGE sql
  STABLE
  AS $function$
  select lower(trim(coalesce(auth.jwt() ->> 'email', '')))
$function$;

GRANT ALL ON FUNCTION public.current_authenticated_email() TO anon;

GRANT ALL ON FUNCTION public.current_authenticated_email() TO authenticated;

GRANT ALL ON FUNCTION public.current_authenticated_email() TO service_role;