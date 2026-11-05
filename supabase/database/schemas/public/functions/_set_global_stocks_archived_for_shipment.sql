CREATE FUNCTION public._set_global_stocks_archived_for_shipment (
  p_shipment_id bigint,
  p_archive     boolean
)
  RETURNS void
  LANGUAGE plpgsql
  SET search_path TO 'public'
  AS $function$
begin
  update public.global_stocks gs
  set
    is_archived = p_archive,
    archived_at = case when p_archive then now() else null end,
    updated_at = now()
  from public.global_shipment_items gsi
  where gsi.id = gs.shipment_item_id
    and gsi.shipment_id = p_shipment_id;
end;
$function$;

GRANT ALL ON FUNCTION public._set_global_stocks_archived_for_shipment(bigint, boolean) TO anon;

GRANT ALL ON FUNCTION public._set_global_stocks_archived_for_shipment(bigint, boolean) TO authenticated;

GRANT ALL ON FUNCTION public._set_global_stocks_archived_for_shipment(bigint, boolean) TO service_role;