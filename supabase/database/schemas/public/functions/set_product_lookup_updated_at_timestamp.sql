CREATE FUNCTION public.set_product_lookup_updated_at_timestamp()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  new.updated_at := now();
  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.set_product_lookup_updated_at_timestamp() TO anon;

GRANT ALL ON FUNCTION public.set_product_lookup_updated_at_timestamp() TO authenticated;

GRANT ALL ON FUNCTION public.set_product_lookup_updated_at_timestamp() TO service_role;