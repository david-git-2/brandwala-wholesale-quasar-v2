CREATE FUNCTION public.delete_shipment_item_quantity (
  p_id       bigint,
  p_quantity integer
)
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_item public.shipment_items;
  v_next_qty integer;
begin
  select * into v_item
  from public.shipment_items
  where id = p_id;

  if v_item.id is null then
    return false;
  end if;

  if not public.can_manage_shipment_by_id(v_item.shipment_id) then
    raise exception 'not allowed';
  end if;

  if coalesce(p_quantity, 0) <= 0 then
    raise exception 'quantity must be greater than 0';
  end if;

  v_next_qty := v_item.quantity - p_quantity;

  if v_next_qty <= 0 then
    delete from public.shipment_items where id = p_id;
    return true;
  end if;

  update public.shipment_items
  set quantity = v_next_qty
  where id = p_id;

  return true;
end;
$function$;

GRANT ALL ON FUNCTION public.delete_shipment_item_quantity(bigint, integer) TO anon;

GRANT ALL ON FUNCTION public.delete_shipment_item_quantity(bigint, integer) TO authenticated;

GRANT ALL ON FUNCTION public.delete_shipment_item_quantity(bigint, integer) TO service_role;