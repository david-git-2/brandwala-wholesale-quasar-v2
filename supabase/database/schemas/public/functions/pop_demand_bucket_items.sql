CREATE FUNCTION public.pop_demand_bucket_items (
  p_bucket_item_ids  bigint[],
  p_popped_into_type text,
  p_popped_into_id   bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_id bigint;
  v_row public.customer_demand_bucket_items;
  v_items jsonb := '[]'::jsonb;
begin
  if p_bucket_item_ids is null or cardinality(p_bucket_item_ids) = 0 then
    return jsonb_build_object('items', '[]'::jsonb, 'count', 0);
  end if;

  foreach v_id in array p_bucket_item_ids loop
    v_row := public.pop_demand_bucket_item(v_id, p_popped_into_type, p_popped_into_id);
    v_items := v_items || jsonb_build_array(to_jsonb(v_row));
  end loop;

  return jsonb_build_object(
    'items', v_items,
    'count', jsonb_array_length(v_items)
  );
end;
$function$;

GRANT ALL ON FUNCTION public.pop_demand_bucket_items(bigint[], text, bigint) TO anon;

GRANT ALL ON FUNCTION public.pop_demand_bucket_items(bigint[], text, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.pop_demand_bucket_items(bigint[], text, bigint) TO service_role;