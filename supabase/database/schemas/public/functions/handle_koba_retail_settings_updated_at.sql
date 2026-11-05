CREATE FUNCTION public.handle_koba_retail_settings_updated_at()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.handle_koba_retail_settings_updated_at() TO anon;

GRANT ALL ON FUNCTION public.handle_koba_retail_settings_updated_at() TO authenticated;

GRANT ALL ON FUNCTION public.handle_koba_retail_settings_updated_at() TO service_role;