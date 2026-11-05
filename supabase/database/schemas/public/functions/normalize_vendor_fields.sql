CREATE FUNCTION public.normalize_vendor_fields()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  new.name = trim(new.name);
  new.code = upper(trim(new.code));
  new.market_code = upper(trim(new.market_code));

  if new.email is not null then
    new.email = nullif(lower(trim(new.email)), '');
  end if;

  if new.phone is not null then
    new.phone = nullif(trim(new.phone), '');
  end if;

  if new.address is not null then
    new.address = nullif(trim(new.address), '');
  end if;

  if new.website is not null then
    new.website = nullif(trim(new.website), '');
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.normalize_vendor_fields() TO anon;

GRANT ALL ON FUNCTION public.normalize_vendor_fields() TO authenticated;

GRANT ALL ON FUNCTION public.normalize_vendor_fields() TO service_role;