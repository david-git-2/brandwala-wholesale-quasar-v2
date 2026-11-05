CREATE FUNCTION public.shops_derive_is_negotiable()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if new.shop_type = 'vendor_catalog' then
    new.is_negotiable := true;
  else
    new.is_negotiable := false;
  end if;
  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.shops_derive_is_negotiable() TO anon;

GRANT ALL ON FUNCTION public.shops_derive_is_negotiable() TO authenticated;

GRANT ALL ON FUNCTION public.shops_derive_is_negotiable() TO service_role;