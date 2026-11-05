CREATE FUNCTION public.mark_shop_order_item_unavailable (
  p_order_item_id        bigint,
  p_reason               text    DEFAULT NULL::text,
  p_add_to_demand_bucket boolean DEFAULT true
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_item public.shop_order_items%rowtype;
  v_order public.shop_orders%rowtype;
  v_pick_count integer := 0;
  v_profile_id bigint;
begin
  select * into v_item from public.shop_order_items where id = p_order_item_id for update;
  if v_item.id is null then
    raise exception 'order item not found';
  end if;

  select * into v_order from public.shop_orders where id = v_item.order_id for update;
  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status <> 'processing'::public.shop_order_status then
    raise exception 'unavailable is only allowed while order is processing';
  end if;

  select count(*) into v_pick_count
  from public.shop_order_item_stock_picks sp
  where sp.order_item_id = p_order_item_id;

  if v_pick_count > 0 then
    raise exception 'cannot mark unavailable while picks exist — remove picks first';
  end if;

  update public.shop_order_items
  set
    is_fulfillment_unavailable = true,
    unavailable_reason = nullif(trim(p_reason), ''),
    unavailable_at = now(),
    unavailable_by_email = public.current_user_email(),
    confirmed_quantity = 0,
    global_stock_id = null,
    updated_at = now()
  where id = p_order_item_id;

  if coalesce(p_add_to_demand_bucket, true) then
    v_profile_id := coalesce(
      v_order.profile_id,
      public.resolve_customer_profile_for_group(v_order.tenant_id, v_order.customer_group_id)
    );
    if v_profile_id is not null then
      perform public.add_demand_bucket_item(
        v_order.tenant_id,
        v_profile_id,
        v_item.product_id,
        'shop_order'::public.demand_bucket_source_type,
        v_order.id,
        jsonb_build_object(
          'order_item_id', v_item.id,
          'name', v_item.name,
          'reason', coalesce(nullif(trim(p_reason), ''), 'fulfillment_unavailable')
        ),
        v_item.quantity
      );
    end if;
  end if;

  perform public.recompute_dropship_cod_collect_amount(v_order.id);

  return jsonb_build_object('success', true);
end;
$function$;

GRANT ALL ON FUNCTION public.mark_shop_order_item_unavailable(bigint, text, boolean) TO anon;

GRANT ALL ON FUNCTION public.mark_shop_order_item_unavailable(bigint, text, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.mark_shop_order_item_unavailable(bigint, text, boolean) TO service_role;