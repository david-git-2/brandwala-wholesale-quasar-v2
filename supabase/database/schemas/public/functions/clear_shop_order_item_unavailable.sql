CREATE FUNCTION public.clear_shop_order_item_unavailable (
  p_order_item_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_item public.shop_order_items%rowtype;
  v_order public.shop_orders%rowtype;
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
    raise exception 'clear unavailable is only allowed while order is processing';
  end if;

  update public.shop_order_items
  set
    is_fulfillment_unavailable = false,
    unavailable_reason = null,
    unavailable_at = null,
    unavailable_by_email = null,
    updated_at = now()
  where id = p_order_item_id;

  perform public._recompute_shop_order_item_fulfillment(p_order_item_id);
  perform public.recompute_dropship_cod_collect_amount(v_order.id);

  return jsonb_build_object('success', true);
end;
$function$;

GRANT ALL ON FUNCTION public.clear_shop_order_item_unavailable(bigint) TO anon;

GRANT ALL ON FUNCTION public.clear_shop_order_item_unavailable(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.clear_shop_order_item_unavailable(bigint) TO service_role;