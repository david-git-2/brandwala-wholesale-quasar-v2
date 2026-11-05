CREATE FUNCTION public.process_dropship_shop_order (
  p_order_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
declare
  v_order public.shop_orders%rowtype;
begin
  -- Fetch order
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'Only dropship orders can be handed off to the dropship desk');
  end if;

  if v_order.status <> 'confirmed' then
    return jsonb_build_object('success', false, 'error', 'Only confirmed orders can be handed off to the dropship desk');
  end if;

  -- Update status to processing (merchant details will be added later)
  update public.shop_orders
  set
    status = 'processing',
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'new_status', 'processing'
  );
end;
$function$;

GRANT ALL ON FUNCTION public.process_dropship_shop_order(bigint) TO anon;

GRANT ALL ON FUNCTION public.process_dropship_shop_order(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.process_dropship_shop_order(bigint) TO service_role;