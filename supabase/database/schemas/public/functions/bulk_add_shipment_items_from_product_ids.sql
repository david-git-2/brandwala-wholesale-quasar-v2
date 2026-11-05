CREATE FUNCTION public.bulk_add_shipment_items_from_product_ids (
  p_shipment_id bigint,
  p_items       jsonb
)
  RETURNS SETOF public.shipment_items
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_entry jsonb;
  v_product_id bigint;
  v_quantity integer;
  v_row public.shipment_items;
begin
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

    select * into v_row
    from public.add_shipment_item_from_product(
      p_shipment_id,
      v_product_id,
      v_quantity
    );

    return next v_row;
  end loop;

  return;
end;
$function$;

GRANT ALL ON FUNCTION public.bulk_add_shipment_items_from_product_ids(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.bulk_add_shipment_items_from_product_ids(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.bulk_add_shipment_items_from_product_ids(bigint, jsonb) TO service_role;