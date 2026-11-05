CREATE FUNCTION public.trg_shipments_recalc_transaction_rate()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  perform public.recalculate_shipment_transaction_rate(new.id);
  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_shipments_recalc_transaction_rate() TO anon;

GRANT ALL ON FUNCTION public.trg_shipments_recalc_transaction_rate() TO authenticated;

GRANT ALL ON FUNCTION public.trg_shipments_recalc_transaction_rate() TO service_role;