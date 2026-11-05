CREATE FUNCTION public.normalize_bd_mobile (
  p_phone text
)
  RETURNS text
  LANGUAGE plpgsql
  IMMUTABLE
  AS $function$
declare
  v text;
begin
  v := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
  if left(v, 4) = '8801' then
    v := substring(v from 3);
  elsif left(v, 3) = '880' and length(v) = 13 then
    v := substring(v from 3);
  end if;
  if v !~ '^01[0-9]{9}$' then
    raise exception 'Invalid BD mobile phone: %', p_phone;
  end if;
  return v;
end;
$function$;

GRANT ALL ON FUNCTION public.normalize_bd_mobile(text) TO anon;

GRANT ALL ON FUNCTION public.normalize_bd_mobile(text) TO authenticated;

GRANT ALL ON FUNCTION public.normalize_bd_mobile(text) TO service_role;