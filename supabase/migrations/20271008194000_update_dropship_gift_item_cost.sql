create or replace function public.update_dropship_order_gift_item_cost(
  p_order_item_id bigint,
  p_gift_cost_amount numeric,
  p_gift_cost_charged_to text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.shop_order_items%rowtype;
  v_order public.shop_orders%rowtype;
  v_cost numeric(12,4);
  v_charged_to text;
begin
  select soi.* into v_item
  from public.shop_order_items soi
  where soi.id = p_order_item_id
  for update;

  if v_item.id is null then
    return jsonb_build_object('success', false, 'error', 'order item not found');
  end if;

  if coalesce(v_item.is_gift, false) is not true or v_item.gift_source is distinct from 'stock' then
    return jsonb_build_object('success', false, 'error', 'not a warehouse gift line');
  end if;

  select * into v_order from public.shop_orders where id = v_item.order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.status <> 'processing'::public.shop_order_status then
    return jsonb_build_object('success', false, 'error', 'gift cost can only be edited while processing');
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  v_cost := coalesce(p_gift_cost_amount, 0);
  v_charged_to := p_gift_cost_charged_to;

  if v_cost > 0 and v_charged_to is null then
    return jsonb_build_object('success', false, 'error', 'gift_cost_charged_to required when cost > 0');
  end if;

  if v_cost <= 0 then
    v_charged_to := null;
  elsif v_charged_to not in ('reseller', 'tenant') then
    return jsonb_build_object('success', false, 'error', 'invalid gift_cost_charged_to');
  end if;

  update public.shop_order_items
  set
    gift_cost_amount = v_cost,
    gift_cost_charged_to = v_charged_to,
    updated_at = now()
  where id = v_item.id;

  return jsonb_build_object('success', true, 'order_item_id', v_item.id);
end;
$$;

grant execute on function public.update_dropship_order_gift_item_cost(bigint, numeric, text) to authenticated;
