CREATE FUNCTION public.prevent_system_unit_of_measure_mutation()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if tg_op = 'DELETE' then
    if old.is_system then
      raise exception 'System units of measure cannot be deleted.';
    end if;
    return old;
  end if;

  if tg_op = 'UPDATE' and old.is_system and (
    row(new.code, new.name, new.unit_type, new.symbol, new.sort_order, new.is_active, new.is_system)
    is distinct from
    row(old.code, old.name, old.unit_type, old.symbol, old.sort_order, old.is_active, old.is_system)
  ) then
    raise exception 'System units of measure cannot be edited.';
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.prevent_system_unit_of_measure_mutation() TO anon;

GRANT ALL ON FUNCTION public.prevent_system_unit_of_measure_mutation() TO authenticated;

GRANT ALL ON FUNCTION public.prevent_system_unit_of_measure_mutation() TO service_role;