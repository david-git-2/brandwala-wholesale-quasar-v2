CREATE FUNCTION public._restamp_global_shipment_on_weight_change()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if coalesce(current_setting('app.skip_shipment_landed_restamp', true), '') = '1' then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and not public.global_shipment_costs_are_locked(new)
     and (
       new.received_weight is distinct from old.received_weight
       or new.total_weight_kg is distinct from old.total_weight_kg
     )
     and exists (select 1 from public.global_shipment_items where shipment_id = new.id) then
    perform public.stamp_global_shipment_landed_costs(new.id);
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public._restamp_global_shipment_on_weight_change() TO anon;

GRANT ALL ON FUNCTION public._restamp_global_shipment_on_weight_change() TO authenticated;

GRANT ALL ON FUNCTION public._restamp_global_shipment_on_weight_change() TO service_role;