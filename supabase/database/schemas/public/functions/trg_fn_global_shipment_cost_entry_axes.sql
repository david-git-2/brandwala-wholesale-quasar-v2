CREATE FUNCTION public.trg_fn_global_shipment_cost_entry_axes()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if new.cost_bucket is null then
    raise exception 'cost_bucket is required';
  end if;

  if new.cost_component is null then
    raise exception 'cost_component is required';
  end if;

  if new.description is null and new.metadata ? 'description' then
    new.description := nullif(trim(new.metadata->>'description'), '');
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_fn_global_shipment_cost_entry_axes() TO anon;

GRANT ALL ON FUNCTION public.trg_fn_global_shipment_cost_entry_axes() TO authenticated;

GRANT ALL ON FUNCTION public.trg_fn_global_shipment_cost_entry_axes() TO service_role;