CREATE FUNCTION public.delete_shop_order (
  p_order_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders;
  v_item record;
  v_allocation_id bigint;
  v_stock_id bigint;
begin
  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) and not (v_order.parent_tenant_id is not null and public.is_tenant_staff(v_order.parent_tenant_id)) then
    raise exception 'Access denied';
  end if;

  if v_order.status = 'fulfilled' then
    raise exception 'Cannot delete a fulfilled order';
  end if;

  if exists (
    select 1
    from public.shop_orders o
    where o.replacement_of_order_id = p_order_id
  ) then
    raise exception 'Cannot delete order: a replacement order references it';
  end if;

  perform public.purge_shop_order_financial_artifacts(p_order_id);

  for v_item in select * from public.shop_order_items where order_id = p_order_id loop
    v_allocation_id := v_item.global_stock_allocation_id;
    v_stock_id := v_item.global_stock_id;

    if v_allocation_id is not null then
      update public.global_stock_allocations
      set
        allocated_quantity = greatest(0, allocated_quantity - v_item.quantity),
        updated_at = now()
      where id = v_allocation_id;
    end if;

    if v_stock_id is not null then
      update public.global_stocks
      set
        allocated_quantity = greatest(0, allocated_quantity - v_item.quantity),
        updated_at = now()
      where id = v_stock_id;
    end if;

    delete from public.shop_stock_reservations where cart_item_id = v_item.id;
  end loop;

  delete from public.shop_order_item_stock_picks where order_id = p_order_id;
  delete from public.shop_order_items where order_id = p_order_id;
  delete from public.shop_orders where id = p_order_id;
end;
$function$;

GRANT ALL ON FUNCTION public.delete_shop_order(bigint) TO anon;

GRANT ALL ON FUNCTION public.delete_shop_order(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.delete_shop_order(bigint) TO service_role;