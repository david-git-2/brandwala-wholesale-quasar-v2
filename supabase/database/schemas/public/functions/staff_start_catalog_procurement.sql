CREATE FUNCTION public.staff_start_catalog_procurement (
  p_order_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order record;
  v_desk_tenant_id bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  v_desk_tenant_id := coalesce(v_order.parent_tenant_id, v_order.tenant_id);

  if not public.is_tenant_staff(v_desk_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog' then
    raise exception 'staff_start_catalog_procurement is only valid for vendor_catalog orders.';
  end if;

  if v_order.status <> 'confirmed' then
    raise exception 'Order % cannot start procurement from status %', p_order_id, v_order.status;
  end if;

  update public.shop_order_items
  set
    confirmed_quantity = coalesce(confirmed_quantity, quantity),
    updated_at = now()
  where order_id = p_order_id;

  update public.shop_orders
  set
    status = 'procuring'::public.shop_order_status,
    updated_at = now()
  where id = p_order_id;

  return public.get_shop_order_for_staff(v_desk_tenant_id, p_order_id);
end;
$function$;

GRANT ALL ON FUNCTION public.staff_start_catalog_procurement(bigint) TO anon;

GRANT ALL ON FUNCTION public.staff_start_catalog_procurement(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.staff_start_catalog_procurement(bigint) TO service_role;