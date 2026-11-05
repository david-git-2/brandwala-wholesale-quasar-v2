CREATE FUNCTION public.trg_global_shipment_items_guard_landed_cost()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if tg_op = 'UPDATE'
     and new.landed_cost_bdt is distinct from old.landed_cost_bdt
     and coalesce(current_setting('app.allow_landed_cost_stamp', true), '') is distinct from '1'
  then
    raise exception 'landed_cost_bdt is stamp-only; use finalize/revise RPCs';
  end if;
  if tg_op = 'INSERT'
     and new.landed_cost_bdt is not null
     and coalesce(current_setting('app.allow_landed_cost_stamp', true), '') is distinct from '1'
  then
    raise exception 'landed_cost_bdt is stamp-only; use finalize/revise RPCs';
  end if;
  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_global_shipment_items_guard_landed_cost() TO anon;

GRANT ALL ON FUNCTION public.trg_global_shipment_items_guard_landed_cost() TO authenticated;

GRANT ALL ON FUNCTION public.trg_global_shipment_items_guard_landed_cost() TO service_role;