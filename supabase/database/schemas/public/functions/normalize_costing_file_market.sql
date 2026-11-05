CREATE FUNCTION public.normalize_costing_file_market()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO 'public'
  AS $function$
begin
  if new.market is null then
    return new;
  end if;

  new.market := nullif(upper(trim(new.market)), '');
  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.normalize_costing_file_market() TO anon;

GRANT ALL ON FUNCTION public.normalize_costing_file_market() TO authenticated;

GRANT ALL ON FUNCTION public.normalize_costing_file_market() TO service_role;