CREATE FUNCTION public.update_product_based_costing_items_order (
  p_items jsonb
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  item_row record;
begin
  for item_row in select * from jsonb_to_recordset(p_items) as x(id bigint, sort_order int) loop
    update public.product_based_costing_items
    set sort_order = item_row.sort_order
    where id = item_row.id;
  end loop;
end;
$function$;

GRANT ALL ON FUNCTION public.update_product_based_costing_items_order(jsonb) TO anon;

GRANT ALL ON FUNCTION public.update_product_based_costing_items_order(jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.update_product_based_costing_items_order(jsonb) TO service_role;