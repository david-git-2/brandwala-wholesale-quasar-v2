-- Create RPC to bulk update sort_order of global shipment items
create or replace function public.update_global_shipment_items_order(
  p_items jsonb
) returns void as $$
declare
  item_row record;
begin
  for item_row in select * from jsonb_to_recordset(p_items) as x(id bigint, sort_order int) loop
    update public.global_shipment_items
    set sort_order = item_row.sort_order
    where id = item_row.id;
  end loop;
end;
$$ language plpgsql security invoker;

grant execute on function public.update_global_shipment_items_order(jsonb) to authenticated;

-- Notify PostgREST to reload schema cache to discover the new RPC
notify pgrst, 'reload schema';
