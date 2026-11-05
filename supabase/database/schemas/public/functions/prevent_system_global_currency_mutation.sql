CREATE FUNCTION public.prevent_system_global_currency_mutation()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if tg_op = 'DELETE' then
    if old.is_system then
      raise exception 'System currencies cannot be deleted.';
    end if;
    return old;
  end if;

  if tg_op = 'UPDATE' and old.is_system and (
    row(new.name, new.country, new.code, new.symbol, new.is_active, new.is_system)
    is distinct from
    row(old.name, old.country, old.code, old.symbol, old.is_active, old.is_system)
  ) then
    raise exception 'System currencies cannot be edited.';
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.prevent_system_global_currency_mutation() TO anon;

GRANT ALL ON FUNCTION public.prevent_system_global_currency_mutation() TO authenticated;

GRANT ALL ON FUNCTION public.prevent_system_global_currency_mutation() TO service_role;