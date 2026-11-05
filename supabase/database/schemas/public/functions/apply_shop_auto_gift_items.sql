CREATE FUNCTION public.apply_shop_auto_gift_items (
  p_order_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders%rowtype;
  v_cfg public.shop_auto_gift_items%rowtype;
  v_result jsonb;
  v_applied integer := 0;
  v_skipped jsonb := '[]'::jsonb;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.auto_gifts_applied_at is not null then
    return jsonb_build_object('success', true, 'already_applied', true, 'applied', 0, 'skipped', coalesce(v_order.auto_gifts_apply_result->'skipped', '[]'::jsonb));
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'not dropship');
  end if;

  for v_cfg in
    select *
    from public.shop_auto_gift_items
    where shop_id = v_order.shop_id
      and is_active = true
    order by id
  loop
    v_result := public.add_dropship_order_gift_item(
      p_order_id,
      v_cfg.product_id,
      v_cfg.quantity,
      v_cfg.gift_source,
      v_cfg.gift_cost_amount,
      v_cfg.gift_cost_charged_to,
      'auto'
    );

    if coalesce(v_result->>'success', 'false') = 'true' then
      v_applied := v_applied + 1;
    else
      v_skipped := v_skipped || jsonb_build_array(jsonb_build_object(
        'auto_gift_id', v_cfg.id,
        'product_id', v_cfg.product_id,
        'error', coalesce(v_result->>'error', 'failed')
      ));
    end if;
  end loop;

  update public.shop_orders
  set
    auto_gifts_applied_at = now(),
    auto_gifts_apply_result = jsonb_build_object('skipped', v_skipped, 'applied_count', v_applied),
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object('success', true, 'applied', v_applied, 'skipped', v_skipped);
end;
$function$;

GRANT ALL ON FUNCTION public.apply_shop_auto_gift_items(bigint) TO anon;

GRANT ALL ON FUNCTION public.apply_shop_auto_gift_items(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.apply_shop_auto_gift_items(bigint) TO service_role;