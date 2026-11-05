CREATE FUNCTION public.trg_shipment_items_recalc_transaction_rate()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
begin
  if tg_op = 'DELETE' then
    perform public.recalculate_shipment_transaction_rate(old.shipment_id);
    return old;
  else
    perform public.recalculate_shipment_transaction_rate(new.shipment_id);
    return new;
  end if;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_shipment_items_recalc_transaction_rate() TO anon;

GRANT ALL ON FUNCTION public.trg_shipment_items_recalc_transaction_rate() TO authenticated;

GRANT ALL ON FUNCTION public.trg_shipment_items_recalc_transaction_rate() TO service_role;