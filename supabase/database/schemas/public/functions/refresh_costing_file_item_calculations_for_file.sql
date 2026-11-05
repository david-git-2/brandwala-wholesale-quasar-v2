CREATE FUNCTION public.refresh_costing_file_item_calculations_for_file()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if
    new.cargo_rate_1kg is distinct from old.cargo_rate_1kg
    or new.cargo_rate_2kg is distinct from old.cargo_rate_2kg
    or new.conversion_rate is distinct from old.conversion_rate
    or new.admin_profit_rate is distinct from old.admin_profit_rate
  then
    update public.costing_file_items cfi
    set updated_at = now()
    where cfi.costing_file_id = new.id;
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.refresh_costing_file_item_calculations_for_file() TO anon;

GRANT ALL ON FUNCTION public.refresh_costing_file_item_calculations_for_file() TO authenticated;

GRANT ALL ON FUNCTION public.refresh_costing_file_item_calculations_for_file() TO service_role;