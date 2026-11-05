CREATE FUNCTION public.prevent_system_payment_method_mutation()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if tg_op = 'DELETE' then
    if old.is_system then
      raise exception 'System payment methods cannot be deleted.';
    end if;
    return old;
  end if;

  if tg_op = 'UPDATE' and old.is_system and (
    row(new.code, new.name, new.category, new.scope, new.sort_order, new.is_active, new.is_system)
    is distinct from
    row(old.code, old.name, old.category, old.scope, old.sort_order, old.is_active, old.is_system)
  ) then
    raise exception 'System payment methods cannot be edited.';
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.prevent_system_payment_method_mutation() TO anon;

GRANT ALL ON FUNCTION public.prevent_system_payment_method_mutation() TO authenticated;

GRANT ALL ON FUNCTION public.prevent_system_payment_method_mutation() TO service_role;