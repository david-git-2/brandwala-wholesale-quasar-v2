CREATE FUNCTION public.mark_shop_order_item_shortfall (
  p_order_item_id        bigint,
  p_shortfall_qty        integer,
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
  v_picked integer := 0;
  v_profile_id bigint;
begin
  if p_shortfall_qty is null or p_shortfall_qty <= 0 then
    raise exception 'shortfall quantity must be positive';
  end if;

  select * into v_item from public.shop_order_items where id = p_order_item_id for update;
  select * into v_order from public.shop_orders where id = v_item.order_id for update;

  if not public.is_tenant_staff(v_order.tenant_id) then raise exception 'access denied'; end if;
  if v_order.status <> 'processing'::public.shop_order_status then
    raise exception 'shortfall only allowed while processing';
  end if;
  if coalesce(v_item.is_fulfillment_unavailable, false) then
    raise exception 'line is fully unavailable';
  end if;

  select coalesce(sum(sp.quantity), 0) into v_picked
  from public.shop_order_item_stock_picks sp where sp.order_item_id = p_order_item_id;

  if v_picked + p_shortfall_qty > v_item.quantity then
    raise exception 'shortfall exceeds remaining qty';
  end if;

  update public.shop_order_items
  set shortfall_quantity = p_shortfall_qty, updated_at = now()
  where id = p_order_item_id;

  if coalesce(p_add_to_demand_bucket, true) then
    v_profile_id := coalesce(
      v_order.profile_id,
      public.resolve_customer_profile_for_group(v_order.tenant_id, v_order.customer_group_id)
    );
    if v_profile_id is not null then
      perform public.add_demand_bucket_item(
        v_order.tenant_id, v_profile_id, v_item.product_id,
        'shop_order'::public.demand_bucket_source_type, v_order.id,
        jsonb_build_object('order_item_id', v_item.id, 'reason', coalesce(p_reason, 'partial_shortfall')),
        p_shortfall_qty
      );
    end if;
  end if;

  perform public.recompute_dropship_cod_collect_amount(v_order.id);
  return jsonb_build_object('success', true);
end;
$function$;

GRANT ALL ON FUNCTION public.mark_shop_order_item_shortfall(bigint, integer, text, boolean) TO anon;

GRANT ALL ON FUNCTION public.mark_shop_order_item_shortfall(bigint, integer, text, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.mark_shop_order_item_shortfall(bigint, integer, text, boolean) TO service_role;