CREATE FUNCTION public.apply_dropship_fulfillment_draft (
  p_order_id bigint,
  p_lines    jsonb
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_line jsonb;
  v_pick jsonb;
  v_item_id bigint;
  v_unavailable boolean;
  v_pick_id bigint;
begin
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' then
    return;
  end if;

  for v_line in select value from jsonb_array_elements(p_lines)
  loop
    v_item_id := (v_line->>'order_item_id')::bigint;
    v_unavailable := coalesce((v_line->>'unavailable')::boolean, false);

    for v_pick_id in
      select sp.id
      from public.shop_order_item_stock_picks sp
      where sp.order_item_id = v_item_id
    loop
      perform public.remove_shop_order_item_stock_pick(v_pick_id, null, 1, 0);
    end loop;

    if v_unavailable then
      perform public.mark_shop_order_item_unavailable(v_item_id, null, true);
      continue;
    end if;

    if exists (
      select 1 from public.shop_order_items soi
      where soi.id = v_item_id and coalesce(soi.is_fulfillment_unavailable, false)
    ) then
      perform public.clear_shop_order_item_unavailable(v_item_id);
    end if;

    for v_pick in select value from jsonb_array_elements(coalesce(v_line->'picks', '[]'::jsonb))
    loop
      perform public.add_shop_order_item_stock_pick(
        v_item_id,
        (v_pick->>'global_stock_id')::bigint,
        (v_pick->>'quantity')::integer,
        null,
        1,
        0
      );
    end loop;
  end loop;
end;
$function$;

GRANT ALL ON FUNCTION public.apply_dropship_fulfillment_draft(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.apply_dropship_fulfillment_draft(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.apply_dropship_fulfillment_draft(bigint, jsonb) TO service_role;