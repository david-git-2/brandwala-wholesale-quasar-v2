CREATE OR REPLACE FUNCTION public.delete_shop_order(p_order_id bigint)
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

  if v_order.status <> 'cancelled'::public.shop_order_status then
    raise exception 'Only cancelled orders can be deleted';
  end if;

  if exists (
    select 1
    from public.shop_orders o
    where o.replacement_of_order_id = p_order_id
  ) then
    raise exception 'Cannot delete order: a replacement order references it';
  end if;

  perform public.purge_shop_order_financial_artifacts(p_order_id);

  delete from public.preorder_demand
  where source_type = 'shop_order_item'::public.preorder_demand_source_type
    and source_id in (
      select i.id
      from public.shop_order_items i
      where i.order_id = p_order_id
    );

  delete from public.customer_order_backlog_items
  where order_id = p_order_id;

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

CREATE OR REPLACE FUNCTION public.delete_shop_orders_for_staff(
  p_tenant_id bigint,
  p_order_ids bigint[]
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ids bigint[];
  v_id bigint;
  v_deleted bigint[] := '{}'::bigint[];
  v_max_batch constant integer := 100;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'Access denied';
  end if;

  if p_order_ids is null or cardinality(p_order_ids) = 0 then
    raise exception 'No orders specified';
  end if;

  select coalesce(array_agg(x order by x), '{}'::bigint[])
  into v_ids
  from (
    select distinct unnest(coalesce(p_order_ids, array[]::bigint[])) as x
  ) s
  where x is not null;

  if v_ids is null or cardinality(v_ids) = 0 then
    raise exception 'No orders specified';
  end if;

  if cardinality(v_ids) > v_max_batch then
    raise exception 'Cannot delete more than % orders at once', v_max_batch;
  end if;

  foreach v_id in array v_ids loop
    if not exists (
      select 1
      from public.shop_orders o
      where o.id = v_id
        and o.status = 'cancelled'::public.shop_order_status
    ) then
      raise exception 'Order % is not cancelled or does not exist', v_id;
    end if;
  end loop;

  foreach v_id in array v_ids loop
    perform public.delete_shop_order(v_id);
    v_deleted := array_append(v_deleted, v_id);
  end loop;

  return jsonb_build_object(
    'deleted_count', cardinality(v_deleted),
    'deleted_ids', to_jsonb(v_deleted)
  );
end;
$function$;

ALTER FUNCTION public.delete_shop_orders_for_staff(bigint, bigint[]) OWNER TO postgres;

GRANT ALL ON FUNCTION public.delete_shop_orders_for_staff(bigint, bigint[]) TO anon;
GRANT ALL ON FUNCTION public.delete_shop_orders_for_staff(bigint, bigint[]) TO authenticated;
GRANT ALL ON FUNCTION public.delete_shop_orders_for_staff(bigint, bigint[]) TO service_role;
