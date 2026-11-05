CREATE FUNCTION public.upsert_shop_auto_gift_item (
  p_shop_id bigint,
  p_payload jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_shop public.shops%rowtype;
  v_id bigint;
  v_row public.shop_auto_gift_items%rowtype;
  v_source text;
  v_cost numeric(12,4);
  v_charged_to text;
begin
  select * into v_shop from public.shops where id = p_shop_id;
  if v_shop.id is null then
    return jsonb_build_object('success', false, 'error', 'shop not found');
  end if;
  if not public.is_tenant_staff(v_shop.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  v_source := p_payload->>'gift_source';
  if v_source not in ('stock', 'customer_stock') then
    return jsonb_build_object('success', false, 'error', 'invalid gift_source');
  end if;

  v_cost := coalesce((p_payload->>'gift_cost_amount')::numeric, 0);
  v_charged_to := p_payload->>'gift_cost_charged_to';

  if v_source = 'customer_stock' then
    v_cost := 0;
    v_charged_to := null;
  elsif v_cost > 0 and v_charged_to is null then
    return jsonb_build_object('success', false, 'error', 'gift_cost_charged_to required when cost > 0');
  elsif v_cost <= 0 then
    v_charged_to := null;
  end if;

  v_id := (p_payload->>'id')::bigint;

  if v_id is not null then
    update public.shop_auto_gift_items
    set
      product_id = coalesce((p_payload->>'product_id')::bigint, product_id),
      quantity = greatest(1, coalesce((p_payload->>'quantity')::integer, quantity)),
      gift_source = v_source,
      gift_cost_amount = v_cost,
      gift_cost_charged_to = v_charged_to,
      is_active = coalesce((p_payload->>'is_active')::boolean, is_active),
      updated_at = now()
    where id = v_id and shop_id = p_shop_id
    returning * into v_row;
  else
    insert into public.shop_auto_gift_items (
      tenant_id, shop_id, product_id, quantity, gift_source,
      gift_cost_amount, gift_cost_charged_to, is_active
    )
    values (
      v_shop.tenant_id,
      p_shop_id,
      (p_payload->>'product_id')::bigint,
      greatest(1, coalesce((p_payload->>'quantity')::integer, 1)),
      v_source,
      v_cost,
      v_charged_to,
      coalesce((p_payload->>'is_active')::boolean, true)
    )
    returning * into v_row;
  end if;

  if v_row.id is null then
    return jsonb_build_object('success', false, 'error', 'failed to save auto gift');
  end if;

  return jsonb_build_object('success', true, 'row', to_jsonb(v_row));
end;
$function$;

GRANT ALL ON FUNCTION public.upsert_shop_auto_gift_item(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.upsert_shop_auto_gift_item(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_shop_auto_gift_item(bigint, jsonb) TO service_role;