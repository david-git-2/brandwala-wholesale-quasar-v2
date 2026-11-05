CREATE FUNCTION public.prevent_system_market_mutation()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if tg_op = 'DELETE' then
    if old.is_system then
      raise exception 'System markets cannot be deleted.';
    end if;

    return old;
  end if;

  if tg_op = 'UPDATE' then
    if old.is_system and (
      row(new.name, new.code, new.is_active, new.is_system, new.region)
      is distinct from
      row(old.name, old.code, old.is_active, old.is_system, old.region)
    ) then
      raise exception 'System markets cannot be edited.';
    end if;

    return new;
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.prevent_system_market_mutation() TO anon;

GRANT ALL ON FUNCTION public.prevent_system_market_mutation() TO authenticated;

GRANT ALL ON FUNCTION public.prevent_system_market_mutation() TO service_role;