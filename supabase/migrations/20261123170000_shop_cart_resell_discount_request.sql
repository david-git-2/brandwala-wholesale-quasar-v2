-- Dropship cart line: store resell discount request (does not change active resell price).

alter table public.shop_cart_items
  add column if not exists requested_resell_discount_price_amount numeric(12, 4),
  add column if not exists requested_resell_discount_price_currency_id bigint references public.global_currencies (id),
  add column if not exists resell_discount_request_reason text,
  add column if not exists resell_discount_requested_at timestamp with time zone;

create or replace function public.submit_shop_cart_item_resell_discount_request(
  p_cart_item_id bigint,
  p_requested_price numeric,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path to public
as $$
declare
  v_cart_id bigint;
  v_shop_id bigint;
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_currency_id bigint;
  v_reason text;
begin
  select
    ci.cart_id,
    c.shop_id,
    c.tenant_id,
    s.shop_type,
  coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id)
  into v_cart_id, v_shop_id, v_tenant_id, v_shop_type, v_currency_id
  from public.shop_cart_items ci
  join public.shop_carts c on c.id = ci.cart_id
  join public.shops s on s.id = c.shop_id
  where ci.id = p_cart_item_id;

  if v_cart_id is null then
    raise exception 'cart item not found';
  end if;

  if not public.is_cart_owner(
    (select customer_group_id from public.shop_carts where id = v_cart_id),
    v_tenant_id
  ) then
    raise exception 'access denied';
  end if;

  if v_shop_type <> 'dropship' then
    raise exception 'resell discount requests only allowed for dropship shops';
  end if;

  if p_requested_price is null or p_requested_price < 0 then
    raise exception 'requested price cannot be negative';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'reason is required';
  end if;

  update public.shop_cart_items
  set
    requested_resell_discount_price_amount = p_requested_price,
    requested_resell_discount_price_currency_id = v_currency_id,
    resell_discount_request_reason = v_reason,
    resell_discount_requested_at = now(),
    updated_at = now()
  where id = p_cart_item_id;

  return public.get_dropship_review_cart(v_shop_id);
end;
$$;

alter function public.submit_shop_cart_item_resell_discount_request(bigint, numeric, text) owner to postgres;
grant execute on function public.submit_shop_cart_item_resell_discount_request(bigint, numeric, text) to authenticated;

-- extend dropship cart item payloads

-- get_dropship_review_cart

CREATE OR REPLACE FUNCTION "public"."get_dropship_review_cart"("p_shop_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop_type public.shop_type_enum;
  v_tenant_id bigint;
  v_customer_group_id bigint;
  v_cart_id bigint;
  v_result jsonb;
  v_resell_subtotal numeric := 0;
  v_has_floor_violation boolean := false;
  v_delivery_min numeric := 60;
  v_delivery_max numeric := 130;
  v_cod_percent_min numeric := 1;
  v_cod_percent_max numeric := 1;
  v_delivery_mid numeric;
  v_cod_charge_preview numeric;
  v_recipient_grand_total numeric;
begin
  select tenant_id, shop_type into v_tenant_id, v_shop_type
  from public.shops
  where id = p_shop_id
    and is_active = true;

  if v_tenant_id is null then
    raise exception 'shop not found or inactive';
  end if;

  if v_shop_type <> 'dropship' then
    raise exception 'shop is not dropship';
  end if;

  if not public.can_customer_access_shop(p_shop_id) then
    raise exception 'access denied';
  end if;

  select access.customer_group_id into v_customer_group_id
  from public.shop_customer_group_access access
  join public.customer_groups cg on cg.id = access.customer_group_id
  join public.customer_group_members cgm on cgm.customer_group_id = cg.id
  where access.shop_id = p_shop_id
    and access.status = true
    and cg.is_active = true
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email()
  order by access.created_at asc
  limit 1;

  if v_customer_group_id is null then
    raise exception 'no customer group access found';
  end if;

  select c.id into v_cart_id
  from public.shop_carts c
  where c.tenant_id = v_tenant_id
    and c.shop_id = p_shop_id
    and c.customer_group_id = v_customer_group_id
    and c.status = 'active'
  order by c.id desc
  limit 1;

  if v_cart_id is null then
    raise exception 'cart not found';
  end if;

  select jsonb_build_object(
    'cart', jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'shop_id', c.shop_id,
      'shop_name', s.name,
      'shop_slug', s.slug,
      'customer_group_id', c.customer_group_id,
      'status', c.status,
      'allow_delivery', s.allow_delivery,
      'currency', jsonb_build_object(
        'id', s.sell_currency_id,
        'code', gc.code,
        'symbol', gc.symbol
      ),
      'charges', jsonb_build_object(
        'cod_charge_amount', c.cod_charge_amount,
        'delivery_charge_amount', c.delivery_charge_amount,
        'print_charge_amount', coalesce(nullif(c.print_charge_amount, 0), s.default_print_charge_amount),
        'packing_charge_amount', coalesce(nullif(c.packing_charge_amount, 0), s.default_packing_charge_amount),
        'discount_amount', c.discount_amount,
        'is_prepaid', c.is_prepaid,
        'delivery_instructions', c.delivery_instructions
      ),
      'margin_deductions', jsonb_build_object(
        'deduct_charges_from_margin', c.deduct_charges_from_margin,
        'deduct_print_from_margin', c.deduct_print_from_margin,
        'deduct_packing_from_margin', c.deduct_packing_from_margin
      ),
      'created_at', c.created_at,
      'updated_at', c.updated_at
    ),
    'permissions', (
      select jsonb_build_object(
        'can_browse', p.can_browse,
        'can_see_buy_price', p.can_see_buy_price,
        'can_see_sell_price', p.can_see_sell_price,
        'can_see_resell_minimum_price', p.can_see_resell_minimum_price,
        'can_add_to_cart', p.can_add_to_cart,
        'can_place_order', p.can_place_order,
        'can_negotiate', p.can_negotiate,
        'can_view_quantity', p.can_view_quantity,
        'can_set_dropship_price', p.can_set_dropship_price
      )
      from public.get_shop_permissions_for_customer(p_shop_id) p
      limit 1
    ),
    'items', coalesce(items.items, '[]'::jsonb),
    'totals', coalesce(items.totals, jsonb_build_object(
      'item_count', 0,
      'line_count', 0,
      'purchase_subtotal', 0,
      'resell_subtotal', 0,
      'estimated_profit', 0
    ))
  )
  into v_result
  from public.shop_carts c
  join public.shops s on s.id = c.shop_id
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  left join lateral (
    select
      jsonb_agg(
        jsonb_build_object(
          'id', ci.id,
          'product_id', ci.product_id,
          'global_stock_id', ci.global_stock_id,
          'name', ci.name,
          'image_url', ci.image_url,
          'quantity', ci.quantity,
          'minimum_quantity', ci.minimum_quantity,
          'minimum_order_quantity', p.minimum_order_quantity,
          'purchase_price', jsonb_build_object(
            'amount', ci.unit_sell_price_amount,
            'currency_id', ci.unit_sell_price_currency_id,
            'code', sell_gc.code,
            'symbol', sell_gc.symbol
          ),
          'listing_sell_price', jsonb_build_object(
            'amount', ci.unit_sell_price_amount,
            'currency_id', ci.unit_sell_price_currency_id,
            'code', sell_gc.code,
            'symbol', sell_gc.symbol
          ),
          'resell_price', jsonb_build_object(
            'amount', coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount),
            'currency_id', coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id),
            'code', coalesce(cust_gc.code, sell_gc.code),
            'symbol', coalesce(cust_gc.symbol, sell_gc.symbol)
          ),
          'min_resell_price', jsonb_build_object(
            'amount', ci.unit_minimum_sell_price_amount,
            'currency_id', ci.unit_minimum_sell_price_currency_id,
            'code', min_gc.code,
            'symbol', min_gc.symbol
          ),
          'line_totals', jsonb_build_object(
            'purchase_subtotal', ci.quantity * coalesce(ci.unit_sell_price_amount, 0),
            'resell_subtotal', ci.quantity * coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
          ),
          'is_resell_below_floor', (
            coalesce(ci.unit_minimum_sell_price_amount, 0) > 0
            and coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
              < ci.unit_minimum_sell_price_amount
          ),
          'requested_resell_discount_price', case
            when ci.requested_resell_discount_price_amount is not null then
              jsonb_build_object(
                'amount', ci.requested_resell_discount_price_amount,
                'currency_id', ci.requested_resell_discount_price_currency_id,
                'code', req_gc.code,
                'symbol', req_gc.symbol
              )
            else null
          end,
          'resell_discount_request_reason', ci.resell_discount_request_reason,
          'resell_discount_requested_at', ci.resell_discount_requested_at
        )
        order by ci.id
      ) as items,
      jsonb_build_object(
        'item_count', coalesce(sum(ci.quantity), 0),
        'line_count', count(ci.id),
        'purchase_subtotal', coalesce(sum(ci.quantity * coalesce(ci.unit_sell_price_amount, 0)), 0),
        'resell_subtotal', coalesce(sum(
          ci.quantity * coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
        ), 0),
        'estimated_profit', coalesce(sum(
          ci.quantity * (
            coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
            - coalesce(ci.unit_sell_price_amount, 0)
          )
        ), 0)
      ) as totals
    from public.shop_cart_items ci
    left join public.products p on p.id = ci.product_id
    left join public.global_currencies sell_gc on sell_gc.id = ci.unit_sell_price_currency_id
    left join public.global_currencies cust_gc on cust_gc.id = ci.customer_sell_price_currency_id
    left join public.global_currencies min_gc on min_gc.id = ci.unit_minimum_sell_price_currency_id
    left join public.global_currencies req_gc on req_gc.id = ci.requested_resell_discount_price_currency_id
    where ci.cart_id = c.id
  ) items on true
  where c.id = v_cart_id;

  if coalesce(jsonb_array_length(v_result->'items'), 0) = 0 then
    raise exception 'cart is empty';
  end if;

  v_resell_subtotal := coalesce((v_result->'totals'->>'resell_subtotal')::numeric, 0);

  select bool_or((item->>'is_resell_below_floor')::boolean)
  into v_has_floor_violation
  from jsonb_array_elements(v_result->'items') item;

  select
    coalesce(min(least(cs.inside_dhaka_fee, cs.outside_dhaka_fee)), 60),
    coalesce(max(greatest(cs.inside_dhaka_fee, cs.outside_dhaka_fee)), 130),
    coalesce(min(cs.cod_fee_percent) filter (where cs.cod_fee_mode = 'percent_of_collect'), 1),
    coalesce(max(cs.cod_fee_percent) filter (where cs.cod_fee_mode = 'percent_of_collect'), 1)
  into v_delivery_min, v_delivery_max, v_cod_percent_min, v_cod_percent_max
  from public.courier_services cs
  where cs.tenant_id = v_tenant_id
    and cs.is_active = true;

  v_delivery_mid := (v_delivery_min + v_delivery_max) / 2;
  v_cod_charge_preview := round(v_resell_subtotal * coalesce(v_cod_percent_min, 1) / 100, 2);
  v_recipient_grand_total := v_resell_subtotal + v_delivery_mid + v_cod_charge_preview;

  return v_result || jsonb_build_object(
    'charge_estimates', jsonb_build_object(
      'delivery_min', v_delivery_min,
      'delivery_max', v_delivery_max,
      'delivery_mid', v_delivery_mid,
      'cod_percent_min', v_cod_percent_min,
      'cod_percent_max', v_cod_percent_max,
      'cod_charge_preview', v_cod_charge_preview
    ),
    'review_summary', jsonb_build_object(
      'total_units', coalesce((v_result->'totals'->>'item_count')::int, 0),
      'has_floor_violation', coalesce(v_has_floor_violation, false),
      'recipient_grand_total', v_recipient_grand_total,
      'can_continue', not coalesce(v_has_floor_violation, false)
    )
  );
end;
$$;




-- get_dropship_shop_cart

CREATE OR REPLACE FUNCTION "public"."get_dropship_shop_cart"("p_shop_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop_type public.shop_type_enum;
  v_cart_id bigint;
  v_result jsonb;
begin
  select shop_type into v_shop_type
  from public.shops
  where id = p_shop_id
    and is_active = true;

  if v_shop_type is null then
    raise exception 'shop not found or inactive';
  end if;

  if v_shop_type <> 'dropship' then
    raise exception 'shop is not dropship';
  end if;

  v_cart_id := (public.get_or_create_shop_cart(p_shop_id)->'cart'->>'id')::bigint;

  select jsonb_build_object(
    'cart', jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'shop_id', c.shop_id,
      'shop_name', s.name,
      'shop_slug', s.slug,
      'customer_group_id', c.customer_group_id,
      'status', c.status,
      'allow_delivery', s.allow_delivery,
      'currency', jsonb_build_object(
        'id', s.sell_currency_id,
        'code', gc.code,
        'symbol', gc.symbol
      ),
      'charges', jsonb_build_object(
        'cod_charge_amount', c.cod_charge_amount,
        'delivery_charge_amount', c.delivery_charge_amount,
        'print_charge_amount', coalesce(nullif(c.print_charge_amount, 0), s.default_print_charge_amount),
        'packing_charge_amount', coalesce(nullif(c.packing_charge_amount, 0), s.default_packing_charge_amount),
        'discount_amount', c.discount_amount,
        'is_prepaid', c.is_prepaid,
        'delivery_instructions', c.delivery_instructions
      ),
      'margin_deductions', jsonb_build_object(
        'deduct_charges_from_margin', c.deduct_charges_from_margin,
        'deduct_print_from_margin', c.deduct_print_from_margin,
        'deduct_packing_from_margin', c.deduct_packing_from_margin
      ),
      'created_at', c.created_at,
      'updated_at', c.updated_at
    ),
    'permissions', (
      select jsonb_build_object(
        'can_browse', p.can_browse,
        'can_see_buy_price', p.can_see_buy_price,
        'can_see_sell_price', p.can_see_sell_price,
        'can_see_resell_minimum_price', p.can_see_resell_minimum_price,
        'can_add_to_cart', p.can_add_to_cart,
        'can_place_order', p.can_place_order,
        'can_negotiate', p.can_negotiate,
        'can_view_quantity', p.can_view_quantity,
        'can_set_dropship_price', p.can_set_dropship_price
      )
      from public.get_shop_permissions_for_customer(p_shop_id) p
      limit 1
    ),
    'items', coalesce(items.items, '[]'::jsonb),
    'totals', coalesce(items.totals, jsonb_build_object(
      'item_count', 0,
      'line_count', 0,
      'purchase_subtotal', 0,
      'resell_subtotal', 0,
      'estimated_profit', 0
    ))
  )
  into v_result
  from public.shop_carts c
  join public.shops s on s.id = c.shop_id
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  left join lateral (
    select
      jsonb_agg(
        jsonb_build_object(
          'id', ci.id,
          'product_id', ci.product_id,
          'global_stock_id', ci.global_stock_id,
          'name', ci.name,
          'image_url', ci.image_url,
          'quantity', ci.quantity,
          'minimum_quantity', ci.minimum_quantity,
          'minimum_order_quantity', p.minimum_order_quantity,
          'purchase_price', jsonb_build_object(
            'amount', ci.unit_sell_price_amount,
            'currency_id', ci.unit_sell_price_currency_id,
            'code', sell_gc.code,
            'symbol', sell_gc.symbol
          ),
          'listing_sell_price', jsonb_build_object(
            'amount', ci.unit_sell_price_amount,
            'currency_id', ci.unit_sell_price_currency_id,
            'code', sell_gc.code,
            'symbol', sell_gc.symbol
          ),
          'resell_price', jsonb_build_object(
            'amount', coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount),
            'currency_id', coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id),
            'code', coalesce(cust_gc.code, sell_gc.code),
            'symbol', coalesce(cust_gc.symbol, sell_gc.symbol)
          ),
          'min_resell_price', jsonb_build_object(
            'amount', ci.unit_minimum_sell_price_amount,
            'currency_id', ci.unit_minimum_sell_price_currency_id,
            'code', min_gc.code,
            'symbol', min_gc.symbol
          ),
          'line_totals', jsonb_build_object(
            'purchase_subtotal', ci.quantity * coalesce(ci.unit_sell_price_amount, 0),
            'resell_subtotal', ci.quantity * coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
          ),
          'is_resell_below_floor', (
            coalesce(ci.unit_minimum_sell_price_amount, 0) > 0
            and coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
              < ci.unit_minimum_sell_price_amount
          ),
          'requested_resell_discount_price', case
            when ci.requested_resell_discount_price_amount is not null then
              jsonb_build_object(
                'amount', ci.requested_resell_discount_price_amount,
                'currency_id', ci.requested_resell_discount_price_currency_id,
                'code', req_gc.code,
                'symbol', req_gc.symbol
              )
            else null
          end,
          'resell_discount_request_reason', ci.resell_discount_request_reason,
          'resell_discount_requested_at', ci.resell_discount_requested_at
        )
        order by ci.id
      ) as items,
      jsonb_build_object(
        'item_count', coalesce(sum(ci.quantity), 0),
        'line_count', count(ci.id),
        'purchase_subtotal', coalesce(sum(ci.quantity * coalesce(ci.unit_sell_price_amount, 0)), 0),
        'resell_subtotal', coalesce(sum(
          ci.quantity * coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
        ), 0),
        'estimated_profit', coalesce(sum(
          ci.quantity * (
            coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
            - coalesce(ci.unit_sell_price_amount, 0)
          )
        ), 0)
      ) as totals
    from public.shop_cart_items ci
    left join public.products p on p.id = ci.product_id
    left join public.global_currencies sell_gc on sell_gc.id = ci.unit_sell_price_currency_id
    left join public.global_currencies cust_gc on cust_gc.id = ci.customer_sell_price_currency_id
    left join public.global_currencies min_gc on min_gc.id = ci.unit_minimum_sell_price_currency_id
    left join public.global_currencies req_gc on req_gc.id = ci.requested_resell_discount_price_currency_id
    where ci.cart_id = c.id
  ) items on true
  where c.id = v_cart_id;

  return v_result;
end;
$$;



