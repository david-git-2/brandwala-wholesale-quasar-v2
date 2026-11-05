CREATE FUNCTION public.staff_price_shop_order (
  p_order_id     bigint,
  p_items        jsonb,
  p_profit_basis text    DEFAULT NULL::text,
  p_fx_rate      numeric DEFAULT NULL::numeric,
  p_cargo_rate   numeric DEFAULT NULL::numeric,
  p_profit_pct   numeric DEFAULT NULL::numeric
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
  v_offer_amount numeric;
  v_offer_currency_id bigint;
  v_weight_kg numeric;
  v_is_manual boolean;
  v_product_id bigint;
  v_product_weight_gm numeric;
  v_package_weight_gm numeric;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog' then
    raise exception 'staff_price_shop_order is only valid for vendor_catalog orders.';
  end if;

  if v_order.status not in ('submitted'::public.shop_order_status, 'costing_pending'::public.shop_order_status) then
    raise exception 'Order % cannot send first offer from status %', p_order_id, v_order.status;
  end if;

  update public.shop_orders
  set
    profit_basis = coalesce(p_profit_basis, profit_basis),
    conversion_rate = coalesce(p_fx_rate, conversion_rate),
    cargo_rate = coalesce(p_cargo_rate, cargo_rate),
    first_offer_rate = coalesce(p_profit_pct, first_offer_rate),
    profit_rate = coalesce(p_profit_pct, profit_rate),
    status = 'priced'::public.shop_order_status,
    updated_at = now()
  where id = p_order_id;

  for v_elem in select * from jsonb_array_elements(p_items) loop
    v_item_id := (v_elem->>'id')::bigint;
    v_offer_amount := (v_elem->>'staff_offer_amount')::numeric;
    v_offer_currency_id := (v_elem->>'staff_offer_currency_id')::bigint;
    v_weight_kg := coalesce(
      nullif(v_elem->>'weight_kg', '')::numeric,
      nullif(v_elem->>'gross_weight_kg', '')::numeric,
      null
    );
    v_is_manual := coalesce((v_elem->>'is_first_offer_manual')::boolean, false);
    v_product_weight_gm := nullif(v_elem->>'product_weight_gm', '')::numeric;
    v_package_weight_gm := nullif(v_elem->>'package_weight_gm', '')::numeric;

    update public.shop_order_items
    set
      staff_offer_amount = v_offer_amount,
      staff_offer_currency_id = v_offer_currency_id,
      weight_kg = coalesce(v_weight_kg, weight_kg),
      is_first_offer_manual = v_is_manual,
      negotiation_status = 'priced',
      staff_offer_at = now(),
      updated_at = now()
    where id = v_item_id and order_id = p_order_id;

    select soi.product_id
    into v_product_id
    from public.shop_order_items soi
    where soi.id = v_item_id and soi.order_id = p_order_id;

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

  perform public.notify_catalog_shop_order(
    p_order_id := p_order_id,
    p_notify_staff := false,
    p_notify_customer := true,
    p_event_type := 'catalog.offer.sent',
    p_title := format('Offer ready for %s', v_order.order_no),
    p_body := 'Open the order to review prices.'
  );

  return public.get_shop_order_for_staff(v_order.tenant_id, p_order_id);
end;
$function$;

GRANT ALL ON FUNCTION public.staff_price_shop_order(bigint, jsonb, text, numeric, numeric, numeric) TO anon;

GRANT ALL ON FUNCTION public.staff_price_shop_order(bigint, jsonb, text, numeric, numeric, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.staff_price_shop_order(bigint, jsonb, text, numeric, numeric, numeric) TO service_role;