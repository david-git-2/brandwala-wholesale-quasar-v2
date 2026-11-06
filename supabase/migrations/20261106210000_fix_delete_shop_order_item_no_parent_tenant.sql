-- shop_orders.parent_tenant_id removed (tenant_id cutover); access = is_tenant_staff(tenant_id) only

CREATE OR REPLACE FUNCTION "public"."delete_shop_order_item"("p_order_item_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_item public.shop_order_items%rowtype;
  v_order public.shop_orders%rowtype;
  v_allocation_id bigint;
  v_stock_id bigint;
  v_line_count integer;
begin
  select * into v_item from public.shop_order_items where id = p_order_item_id for update;
  if v_item.id is null then
    raise exception 'Order item not found';
  end if;

  select count(*)::integer into v_line_count from public.shop_order_items where order_id = v_item.order_id;
  if v_line_count <= 1 then
    raise exception 'Cannot remove the last line from an order';
  end if;

  select * into v_order from public.shop_orders where id = v_item.order_id for update;
  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'Access denied';
  end if;

  if v_order.status not in (
    'draft'::public.shop_order_status,
    'submitted'::public.shop_order_status,
    'costing_pending'::public.shop_order_status,
    'negotiating'::public.shop_order_status,
    'priced'::public.shop_order_status,
    'countered'::public.shop_order_status,
    'final_offered'::public.shop_order_status,
    'confirmed'::public.shop_order_status,
    'placed'::public.shop_order_status,
    'procuring'::public.shop_order_status,
    'processing'::public.shop_order_status
  ) then
    raise exception 'Cannot remove order lines at this order status';
  end if;

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
  delete from public.shop_order_item_stock_picks where order_item_id = p_order_item_id;
  delete from public.shop_order_items where id = p_order_item_id;
end;
$$;


CREATE OR REPLACE FUNCTION public.delete_shop_order_items_for_staff(
  p_order_id bigint,
  p_order_item_ids bigint[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
declare
  v_order public.shop_orders%rowtype;
  v_item public.shop_order_items%rowtype;
  v_ids bigint[];
  v_delete_count integer;
  v_line_count integer;
  v_item_id bigint;
  v_allocation_id bigint;
  v_stock_id bigint;
begin
  if p_order_item_ids is null or cardinality(p_order_item_ids) = 0 then
    raise exception 'No order items specified';
  end if;

  select coalesce(array_agg(x order by x), '{}'::bigint[]) into v_ids
  from (select distinct unnest(coalesce(p_order_item_ids, array[]::bigint[])) as x) s
  where x is not null;

  if v_ids is null or cardinality(v_ids) = 0 then
    raise exception 'No order items specified';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'Access denied';
  end if;

  if v_order.status not in (
    'draft'::public.shop_order_status,
    'submitted'::public.shop_order_status,
    'costing_pending'::public.shop_order_status,
    'negotiating'::public.shop_order_status,
    'priced'::public.shop_order_status,
    'countered'::public.shop_order_status,
    'final_offered'::public.shop_order_status,
    'confirmed'::public.shop_order_status,
    'placed'::public.shop_order_status,
    'procuring'::public.shop_order_status,
    'processing'::public.shop_order_status
  ) then
    raise exception 'Cannot remove order lines at this order status';
  end if;

  select count(*)::integer into v_line_count
  from public.shop_order_items
  where order_id = p_order_id;

  v_delete_count := cardinality(v_ids);

  if v_line_count - v_delete_count < 1 then
    raise exception 'Cannot remove the last line from an order';
  end if;

  if exists (
    select 1
    from unnest(v_ids) as wanted(id)
    left join public.shop_order_items soi
      on soi.id = wanted.id and soi.order_id = p_order_id
    where soi.id is null
  ) then
    raise exception 'One or more items not found on this order';
  end if;

  foreach v_item_id in array v_ids
  loop
    select * into v_item from public.shop_order_items where id = v_item_id for update;
    if v_item.order_id is distinct from p_order_id then
      raise exception 'Order item does not belong to this order';
    end if;

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
    delete from public.shop_order_item_stock_picks where order_item_id = v_item_id;
    delete from public.shop_order_items where id = v_item_id;
  end loop;
end;
$$;
