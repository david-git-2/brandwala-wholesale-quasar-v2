CREATE FUNCTION public.update_global_shipment_items_order (
  p_items jsonb
)
  RETURNS void
  LANGUAGE plpgsql
  AS $function$
declare
  item_row record;
begin
  for item_row in select * from jsonb_to_recordset(p_items) as x(id bigint, sort_order int) loop
    update public.global_shipment_items
    set sort_order = item_row.sort_order
    where id = item_row.id;
  end loop;
end;
$function$;

GRANT ALL ON FUNCTION public.update_global_shipment_items_order(jsonb) TO anon;

GRANT ALL ON FUNCTION public.update_global_shipment_items_order(jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.update_global_shipment_items_order(jsonb) TO service_role;