CREATE FUNCTION public.sync_global_shipment_header_aliases()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if tg_op = 'INSERT' then
    if new.total_weight_kg is null and new.received_weight is not null then
      new.total_weight_kg := new.received_weight;
    elsif new.received_weight is null and new.total_weight_kg is not null then
      new.received_weight := new.total_weight_kg;
    elsif new.total_weight_kg is distinct from new.received_weight then
      -- Prefer plan name when both provided
      if new.total_weight_kg is not null then
        new.received_weight := new.total_weight_kg;
      else
        new.total_weight_kg := new.received_weight;
      end if;
    end if;

    if new.inventory_added is null then
      new.inventory_added := coalesce(new.stock_ready, false);
    end if;
    new.stock_ready := new.inventory_added;
    return new;
  end if;

  -- UPDATE: whichever side changed wins
  if new.total_weight_kg is distinct from old.total_weight_kg then
    new.received_weight := new.total_weight_kg;
  elsif new.received_weight is distinct from old.received_weight then
    new.total_weight_kg := new.received_weight;
  end if;

  if new.inventory_added is distinct from old.inventory_added then
    new.stock_ready := new.inventory_added;
  elsif new.stock_ready is distinct from old.stock_ready then
    new.inventory_added := new.stock_ready;
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.sync_global_shipment_header_aliases() TO anon;

GRANT ALL ON FUNCTION public.sync_global_shipment_header_aliases() TO authenticated;

GRANT ALL ON FUNCTION public.sync_global_shipment_header_aliases() TO service_role;