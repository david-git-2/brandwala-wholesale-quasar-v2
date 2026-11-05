CREATE FUNCTION public.bulk_delete_shipment_items_by_product_id (
  p_shipment_id bigint,
  p_items       jsonb
)
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_entry jsonb;
  v_product_id bigint;
  v_quantity integer;
  v_item_id bigint;
  v_deleted_count integer := 0;
begin
  if not public.can_manage_shipment_by_id(p_shipment_id) then
    raise exception 'not allowed';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'p_items must be a json array';
  end if;

  for v_entry in
    select value
    from jsonb_array_elements(p_items)
  loop
    v_product_id := nullif(trim(coalesce(v_entry ->> 'product_id', '')), '')::bigint;
    v_quantity := coalesce(nullif(trim(coalesce(v_entry ->> 'quantity', '')), '')::integer, 0);

    if v_product_id is null or v_quantity <= 0 then
      continue;
    end if;

    select id into v_item_id
    from public.shipment_items
    where shipment_id = p_shipment_id
      and product_id = v_product_id;

    if v_item_id is null then
      continue;
    end if;

    perform public.delete_shipment_item_quantity(v_item_id, v_quantity);
    v_deleted_count := v_deleted_count + 1;
  end loop;

  return v_deleted_count;
end;
$function$;

GRANT ALL ON FUNCTION public.bulk_delete_shipment_items_by_product_id(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.bulk_delete_shipment_items_by_product_id(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.bulk_delete_shipment_items_by_product_id(bigint, jsonb) TO service_role;