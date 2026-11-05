CREATE FUNCTION public._kernel_sync_pot_on_cashbook_entry()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_delta numeric(12, 2);
begin
  if NEW.cashbook_point_pot_id is null then
    return NEW;
  end if;

  v_delta := case when NEW.type = 'credit' then NEW.amount else -NEW.amount end;

  update public.cashbook_point_pots
  set amount = amount + v_delta
  where id = NEW.cashbook_point_pot_id;

  return NEW;
end;
$function$;

GRANT ALL ON FUNCTION public._kernel_sync_pot_on_cashbook_entry() TO anon;

GRANT ALL ON FUNCTION public._kernel_sync_pot_on_cashbook_entry() TO authenticated;

GRANT ALL ON FUNCTION public._kernel_sync_pot_on_cashbook_entry() TO service_role;