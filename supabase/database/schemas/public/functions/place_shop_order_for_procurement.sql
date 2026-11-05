CREATE FUNCTION public.place_shop_order_for_procurement (
  p_order_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
  v_status public.shop_order_status;
  v_type public.shop_type_enum;
begin
  select tenant_id, status, shop_type_snapshot
  into v_tenant_id, v_status, v_type
  from public.shop_orders
  where id = p_order_id;

  if v_tenant_id is null then
    raise exception 'order not found';
  end if;

  if not public.is_tenant_staff(v_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_type <> 'vendor_catalog' then
    raise exception 'only vendor catalog orders can be placed for procurement';
  end if;

  if v_status <> 'confirmed' then
    raise exception 'order must be confirmed before placing';
  end if;

  update public.shop_orders
  set status = 'placed',
      placed_at = now(),
      updated_at = now()
  where id = p_order_id;
end;
$function$;

GRANT ALL ON FUNCTION public.place_shop_order_for_procurement(bigint) TO anon;

GRANT ALL ON FUNCTION public.place_shop_order_for_procurement(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.place_shop_order_for_procurement(bigint) TO service_role;