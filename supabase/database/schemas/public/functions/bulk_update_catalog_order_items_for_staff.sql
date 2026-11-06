CREATE FUNCTION public.bulk_update_catalog_order_items_for_staff (
  p_tenant_id bigint,
  p_order_id  bigint,
  p_updates   jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order record;
  v_elem jsonb;
  v_item_id bigint;
  v_payload jsonb;
  v_product_id bigint;
  v_product_weight_gm numeric;
  v_package_weight_gm numeric;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant and order required';
  end if;

  if p_updates is null or jsonb_typeof(p_updates) <> 'array' then
    raise exception 'p_updates must be a json array';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if not found or v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'order not found';
  end if;

  for v_elem in select * from jsonb_array_elements(p_updates)
  loop
    v_item_id := nullif(v_elem->>'item_id', '')::bigint;
    v_payload := coalesce(v_elem->'payload', '{}'::jsonb);

    if v_item_id is null then
      continue;
    end if;

    if not exists (
      select 1
      from public.shop_order_items soi
      where soi.id = v_item_id and soi.order_id = p_order_id
    ) then
      raise exception 'order item % not found on order %', v_item_id, p_order_id;
    end if;

    update public.shop_order_items soi
    set
      weight_kg = case when v_payload ? 'weight_kg' then (v_payload->>'weight_kg')::numeric else soi.weight_kg end,
      cost_price_amount = case when v_payload ? 'cost_price_amount' then (v_payload->>'cost_price_amount')::numeric else soi.cost_price_amount end,
      staff_offer_amount = case when v_payload ? 'staff_offer_amount' then (v_payload->>'staff_offer_amount')::numeric else soi.staff_offer_amount end,
      is_first_offer_manual = case when v_payload ? 'is_first_offer_manual' then coalesce((v_payload->>'is_first_offer_manual')::boolean, false) else soi.is_first_offer_manual end,
      customer_offer_amount = case when v_payload ? 'customer_offer_amount' then (v_payload->>'customer_offer_amount')::numeric else soi.customer_offer_amount end,
      customer_offer_currency_id = case when v_payload ? 'customer_offer_currency_id' then nullif(v_payload->>'customer_offer_currency_id', '')::bigint else soi.customer_offer_currency_id end,
      final_price_amount = case when v_payload ? 'final_price_amount' then (v_payload->>'final_price_amount')::numeric else soi.final_price_amount end,
      is_final_offer_manual = case when v_payload ? 'is_final_offer_manual' then coalesce((v_payload->>'is_final_offer_manual')::boolean, false) else soi.is_final_offer_manual end,
      confirmed_quantity = case when v_payload ? 'confirmed_quantity' then (v_payload->>'confirmed_quantity')::integer else soi.confirmed_quantity end,
      quantity = case when v_payload ? 'quantity' then (v_payload->>'quantity')::integer else soi.quantity end,
      updated_at = now()
    where soi.id = v_item_id and soi.order_id = p_order_id;

    select soi.product_id into v_product_id
    from public.shop_order_items soi
    where soi.id = v_item_id and soi.order_id = p_order_id;

    v_product_weight_gm := nullif(v_payload->>'product_weight_gm', '')::numeric;
    v_package_weight_gm := nullif(v_payload->>'package_weight_gm', '')::numeric;

    if v_product_id is not null
       and (
         (v_product_weight_gm is not null and v_product_weight_gm > 0)
         or (v_package_weight_gm is not null and v_package_weight_gm > 0)
       ) then
      update public.products p
      set
        product_weight = case
          when v_product_weight_gm is not null and v_product_weight_gm > 0 then v_product_weight_gm
          else p.product_weight
        end,
        package_weight = case
          when v_package_weight_gm is not null and v_package_weight_gm > 0 then v_package_weight_gm
          else p.package_weight
        end,
        updated_at = now()
      where p.id = v_product_id;
    end if;
  end loop;

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$function$;

GRANT ALL ON FUNCTION public.bulk_update_catalog_order_items_for_staff(bigint, bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.bulk_update_catalog_order_items_for_staff(bigint, bigint, jsonb) TO service_role;