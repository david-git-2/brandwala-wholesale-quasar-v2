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


ALTER FUNCTION "public"."delete_shop_order_item"("p_order_item_id" bigint) OWNER TO "postgres";

GRANT ALL ON FUNCTION "public"."delete_shop_order_item"("p_order_item_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."delete_shop_order_item"("p_order_item_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_shop_order_item"("p_order_item_id" bigint) TO "service_role";
