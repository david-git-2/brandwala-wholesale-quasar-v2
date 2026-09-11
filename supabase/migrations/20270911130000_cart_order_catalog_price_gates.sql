-- Cart and customer order RPCs: vendor catalog list prices follow can_see_buy_price (not sell).
begin;

CREATE OR REPLACE FUNCTION public.get_or_create_shop_cart(p_shop_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_tenant_id bigint;
  v_customer_group_id bigint;
  v_can_see_buy_price_snapshot boolean;
  v_can_see_sell_price_snapshot boolean;
  v_cart_id bigint;
  v_result jsonb;
  v_perm record;
begin
  select tenant_id into v_tenant_id
  from public.shops
  where id = p_shop_id
    and is_active = true;

  if v_tenant_id is null then
    raise exception 'shop not found or inactive';
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

  if not public.can_customer_access_shop(p_shop_id) then
    raise exception 'access denied';
  end if;

  select *
  into v_perm
  from public.get_shop_permissions_for_customer(p_shop_id)
  limit 1;

  v_can_see_buy_price_snapshot := coalesce(v_perm.can_see_buy_price, false);
  v_can_see_sell_price_snapshot := coalesce(v_perm.can_see_sell_price, false);

  select id into v_cart_id
  from public.shop_carts
  where tenant_id = v_tenant_id
    and shop_id = p_shop_id
    and customer_group_id = v_customer_group_id
    and status = 'active'
  order by id desc
  limit 1;

  if v_cart_id is null then
    insert into public.shop_carts (
      tenant_id, shop_id, customer_group_id,
      can_see_buy_price_snapshot, can_see_sell_price_snapshot, status,
      deduct_charges_from_margin, deduct_print_from_margin, deduct_packing_from_margin
    )
    values (
      v_tenant_id, p_shop_id, v_customer_group_id,
      v_can_see_buy_price_snapshot, v_can_see_sell_price_snapshot, 'active',
      (select deduct_charges_from_margin from public.shops where id = p_shop_id),
      (select deduct_print_from_margin from public.shops where id = p_shop_id),
      (select deduct_packing_from_margin from public.shops where id = p_shop_id)
    )
    returning id into v_cart_id;
  else
    update public.shop_carts
    set
      deduct_charges_from_margin = (select deduct_charges_from_margin from public.shops where id = p_shop_id),
      deduct_print_from_margin = (select deduct_print_from_margin from public.shops where id = p_shop_id),
      deduct_packing_from_margin = (select deduct_packing_from_margin from public.shops where id = p_shop_id),
      can_see_buy_price_snapshot = v_can_see_buy_price_snapshot,
      can_see_sell_price_snapshot = v_can_see_sell_price_snapshot
    where id = v_cart_id;
  end if;

  select jsonb_build_object(
    'cart', jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'shop_id', c.shop_id,
      'customer_group_id', c.customer_group_id,
      'can_see_buy_price_snapshot', v_can_see_buy_price_snapshot,
      'can_see_sell_price_snapshot', v_can_see_sell_price_snapshot,
      'status', c.status,
      'created_at', c.created_at,
      'updated_at', c.updated_at,
      'shop_type', s.shop_type,
      'allow_delivery', s.allow_delivery,
      'default_print_charge_amount', s.default_print_charge_amount,
      'default_packing_charge_amount', s.default_packing_charge_amount,
      'deduct_charges_from_margin', s.deduct_charges_from_margin,
      'deduct_print_from_margin', s.deduct_print_from_margin,
      'deduct_packing_from_margin', s.deduct_packing_from_margin
    ),
    'items', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', ci.id,
            'cart_id', ci.cart_id,
            'product_id', ci.product_id,
            'listing_id', ci.listing_id,
            'grade_tag_id', ci.grade_tag_id,
            'global_stock_id', ci.global_stock_id,
            'global_stock_allocation_id', ci.global_stock_allocation_id,
            'quantity', ci.quantity,
            'minimum_quantity', ci.minimum_quantity,
            'minimum_order_quantity', p.minimum_order_quantity,
            'unit_list_price_amount', case when v_can_see_buy_price_snapshot then ci.unit_list_price_amount else null end,
            'unit_list_price_currency_id', case when v_can_see_buy_price_snapshot then ci.unit_list_price_currency_id else null end,
            'unit_sell_price_amount', case when v_can_see_sell_price_snapshot then ci.unit_sell_price_amount else null end,
            'unit_sell_price_currency_id', case when v_can_see_sell_price_snapshot then ci.unit_sell_price_currency_id else null end,
            'unit_minimum_sell_price_amount', case when v_can_see_sell_price_snapshot then ci.unit_minimum_sell_price_amount else null end,
            'unit_minimum_sell_price_currency_id', case when v_can_see_sell_price_snapshot then ci.unit_minimum_sell_price_currency_id else null end,
            'customer_sell_price_amount', case when v_can_see_sell_price_snapshot then ci.customer_sell_price_amount else null end,
            'customer_sell_price_currency_id', case when v_can_see_sell_price_snapshot then ci.customer_sell_price_currency_id else null end,
            'name', ci.name,
            'image_url', ci.image_url
          )
        )
        from public.shop_cart_items ci
        left join public.products p on p.id = ci.product_id
        where ci.cart_id = c.id
      ),
      '[]'::jsonb
    ),
    'permissions', jsonb_build_object(
      'can_browse', coalesce(v_perm.can_browse, false),
      'can_see_buy_price', coalesce(v_perm.can_see_buy_price, false),
      'can_see_sell_price', coalesce(v_perm.can_see_sell_price, false),
      'can_see_resell_minimum_price', coalesce(v_perm.can_see_resell_minimum_price, false),
      'can_add_to_cart', coalesce(v_perm.can_add_to_cart, false),
      'can_place_order', coalesce(v_perm.can_place_order, false),
      'can_negotiate', coalesce(v_perm.can_negotiate, false),
      'can_view_quantity', coalesce(v_perm.can_view_quantity, false),
      'can_set_dropship_price', coalesce(v_perm.can_set_dropship_price, false)
    ),
    'currency', case
      when gc.id is not null then jsonb_build_object(
        'id', gc.id,
        'code', gc.code,
        'symbol', gc.symbol
      )
      else null
    end
  )
  into v_result
  from public.shop_carts c
  join public.shops s on s.id = c.shop_id
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  where c.id = v_cart_id;

  return v_result;
end;
$$;

create or replace function public.list_customer_active_carts(p_tenant_id bigint)
returns table(
  cart_id bigint,
  shop_id bigint,
  shop_name text,
  shop_slug text,
  shop_logo_url text,
  shop_type text,
  can_see_buy_price boolean,
  can_see_sell_price boolean,
  currency_id bigint,
  currency_code text,
  currency_symbol text,
  item_count bigint,
  cart_total numeric,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.id as cart_id,
    s.id as shop_id,
    s.name as shop_name,
    s.slug as shop_slug,
    null::text as shop_logo_url,
    s.shop_type::text as shop_type,
    coalesce(perm.can_see_buy_price, false) as can_see_buy_price,
    coalesce(perm.can_see_sell_price, false) as can_see_sell_price,
    s.sell_currency_id as currency_id,
    gc.code as currency_code,
    gc.symbol as currency_symbol,
    coalesce(sum(ci.quantity), 0)::bigint as item_count,
    case
      when s.shop_type = 'vendor_catalog'::public.shop_type_enum
        and coalesce(perm.can_see_buy_price, false) then
        sum(ci.quantity * coalesce(ci.unit_list_price_amount, 0))::numeric
      when coalesce(perm.can_see_sell_price, false) then
        sum(
          ci.quantity * coalesce(
            ci.customer_sell_price_amount,
            ci.unit_sell_price_amount,
            case
              when s.shop_type = 'vendor_catalog'::public.shop_type_enum then null
              else ci.unit_list_price_amount
            end,
            0
          )
        )::numeric
      else null
    end as cart_total,
    c.updated_at
  from public.shop_carts c
  join public.shops s on s.id = c.shop_id
  join public.shop_cart_items ci on ci.cart_id = c.id
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  left join lateral (
    select p.can_see_buy_price, p.can_see_sell_price
    from public.get_shop_permissions_for_customer(s.id) p
    limit 1
  ) perm on true
  where p_tenant_id is not null
    and c.status = 'active'
    and c.tenant_id = p_tenant_id
    and c.customer_group_id = public.current_customer_group_id(p_tenant_id)
  group by c.id, s.id, s.shop_type, gc.code, gc.symbol, perm.can_see_buy_price, perm.can_see_sell_price
  order by c.updated_at desc;
$$;


create or replace function public.get_customer_shop_order(
  p_tenant_id bigint,
  p_order_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_group_id bigint;
  v_order public.shop_orders%rowtype;
  v_shop_name text;
  v_shop_slug text;
  v_sell_currency_id bigint;
  v_buy_currency_id bigint;
  v_sell_symbol text;
  v_buy_symbol text;
  v_item_count bigint;
  v_total_amount numeric;
  v_items jsonb;
  v_order_json jsonb;
  v_can_see_buy_price boolean;
  v_can_see_sell_price boolean;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant required';
  end if;

  v_group_id := public.current_customer_group_id(p_tenant_id);
  if v_group_id is null then
    raise exception 'access denied';
  end if;

  select *
  into v_order
  from public.shop_orders o
  where o.id = p_order_id;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  if v_order.customer_group_id is distinct from v_group_id then
    raise exception 'order not found';
  end if;

  select
    s.name,
    s.slug,
    s.sell_currency_id,
    s.buy_currency_id,
    sell_gc.symbol,
    buy_gc.symbol
  into
    v_shop_name,
    v_shop_slug,
    v_sell_currency_id,
    v_buy_currency_id,
    v_sell_symbol,
    v_buy_symbol
  from public.shops s
  left join public.global_currencies sell_gc on sell_gc.id = s.sell_currency_id
  left join public.global_currencies buy_gc on buy_gc.id = s.buy_currency_id
  where s.id = v_order.shop_id;

  select
    case
      when v_order.cart_id is not null then coalesce(c.can_see_buy_price_snapshot, perm.can_see_buy_price, false)
      else coalesce(perm.can_see_buy_price, false)
    end,
    case
      when v_order.cart_id is not null then coalesce(c.can_see_sell_price_snapshot, perm.can_see_sell_price, false)
      else coalesce(perm.can_see_sell_price, false)
    end
  into v_can_see_buy_price, v_can_see_sell_price
  from public.get_shop_permissions_for_customer(v_order.shop_id) perm
  left join public.shop_carts c on c.id = v_order.cart_id;

  select count(*)::bigint
  into v_item_count
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  select coalesce(
    sum(
      coalesce(
        soi.final_price_amount,
        soi.customer_offer_amount,
        soi.unit_sell_price_amount,
        case
          when v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum and not v_can_see_buy_price then null
          else soi.unit_list_price_amount
        end
      ) * soi.quantity
    ),
    0
  )
  into v_total_amount
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', soi.id,
        'order_id', soi.order_id,
        'product_id', soi.product_id,
        'global_stock_id', soi.global_stock_id,
        'global_stock_allocation_id', soi.global_stock_allocation_id,
        'name', soi.name,
        'image_url', soi.image_url,
        'quantity', soi.quantity,
        'unit_list_price_amount', case when v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum and not v_can_see_buy_price then null else soi.unit_list_price_amount end,
        'unit_list_price_currency_id', case when v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum and not v_can_see_buy_price then null else soi.unit_list_price_currency_id end,
        'unit_sell_price_amount', soi.unit_sell_price_amount,
        'unit_sell_price_currency_id', soi.unit_sell_price_currency_id,
        'unit_minimum_sell_price_amount', soi.unit_minimum_sell_price_amount,
        'unit_minimum_sell_price_currency_id', soi.unit_minimum_sell_price_currency_id,
        'customer_sell_price_amount', soi.customer_sell_price_amount,
        'customer_sell_price_currency_id', soi.customer_sell_price_currency_id,
        'customer_offer_amount', soi.customer_offer_amount,
        'customer_offer_currency_id', soi.customer_offer_currency_id,
        'staff_offer_amount', soi.staff_offer_amount,
        'staff_offer_currency_id', soi.staff_offer_currency_id,
        'is_first_offer_manual', soi.is_first_offer_manual,
        'final_price_amount', soi.final_price_amount,
        'final_price_currency_id', soi.final_price_currency_id,
        'is_final_offer_manual', soi.is_final_offer_manual,
        'confirmed_quantity', soi.confirmed_quantity,
        'weight_kg', soi.weight_kg,
        'customer_decision_status', soi.customer_decision_status,
        'customer_decision_at', soi.customer_decision_at,
        'negotiation_status', soi.negotiation_status,
        'staff_offer_at', soi.staff_offer_at,
        'customer_counter_at', soi.customer_counter_at,
        'final_offer_at', soi.final_offer_at,
        'returned_quantity', soi.returned_quantity,
        'sku', p.product_code,
        'brand', p.brand,
        'barcode', p.barcode,
        'minimum_order_quantity', p.minimum_order_quantity,
        'created_at', soi.created_at,
        'updated_at', soi.updated_at
      )
      order by soi.created_at, soi.id
    ),
    '[]'::jsonb
  )
  into v_items
  from public.shop_order_items soi
  left join public.products p on p.id = soi.product_id
  where soi.order_id = v_order.id;

  v_order_json :=
    jsonb_build_object(
      'id', v_order.id,
      'tenant_id', v_order.tenant_id,
      'shop_id', v_order.shop_id,
      'shop_name', v_shop_name,
      'shop_slug', v_shop_slug,
      'customer_group_id', v_order.customer_group_id,
      'cart_id', v_order.cart_id,
      'order_no', v_order.order_no,
      'name', v_order.name,
      'shop_type_snapshot', v_order.shop_type_snapshot,
      'order_mode_snapshot', v_order.order_mode_snapshot,
      'is_negotiable_snapshot', v_order.is_negotiable_snapshot,
      'status', v_order.status,
      'negotiate_round', v_order.negotiate_round,
      'cargo_rate', v_order.cargo_rate,
      'conversion_rate', v_order.conversion_rate,
      'profit_rate', v_order.profit_rate,
      'first_offer_rate', v_order.first_offer_rate,
      'final_offer_rate', v_order.final_offer_rate,
      'profit_basis', v_order.profit_basis,
      'package_weight_kg', v_order.package_weight_kg,
      'recipient_name', v_order.recipient_name,
      'recipient_phone', v_order.recipient_phone,
      'recipient_phone_secondary', v_order.recipient_phone_secondary,
      'shipping_address', v_order.shipping_address,
      'shipping_district', v_order.shipping_district,
      'shipping_thana', v_order.shipping_thana,
      'recipient_profile_id', v_order.recipient_profile_id,
      'billing_profile_id', v_order.billing_profile_id,
      'placed_at', v_order.placed_at,
      'fulfilled_at', v_order.fulfilled_at,
      'shop_sell_currency_id', v_sell_currency_id,
      'shop_buy_currency_id', v_buy_currency_id,
      'shop_sell_currency_symbol', v_sell_symbol,
      'shop_buy_currency_symbol', v_buy_symbol,
      'can_see_buy_price', v_can_see_buy_price,
      'can_see_sell_price', v_can_see_sell_price
    )
    || jsonb_build_object(
      'created_at', v_order.created_at,
      'updated_at', v_order.updated_at,
      'cod_charge_amount', v_order.cod_charge_amount,
      'delivery_charge_amount', v_order.delivery_charge_amount,
      'print_charge_amount', v_order.print_charge_amount,
      'packing_charge_amount', v_order.packing_charge_amount,
      'discount_amount', v_order.discount_amount,
      'is_prepaid_snapshot', v_order.is_prepaid_snapshot,
      'delivery_instructions', v_order.delivery_instructions,
      'deduct_charges_from_margin', v_order.deduct_charges_from_margin,
      'deduct_cod_from_margin', v_order.deduct_cod_from_margin,
      'deduct_delivery_from_margin', v_order.deduct_delivery_from_margin,
      'deduct_print_from_margin', v_order.deduct_print_from_margin,
      'deduct_packing_from_margin', v_order.deduct_packing_from_margin,
      'item_count', v_item_count,
      'total_amount', case
        when v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum
          and not v_can_see_buy_price
          and not v_can_see_sell_price then null
        when v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum
          and not v_can_see_buy_price
          and v_total_amount = 0 then null
        else v_total_amount
      end,
      'cod_collect_amount', v_order.cod_collect_amount,
      'courier_name', v_order.courier_name,
      'courier_awb_number', v_order.courier_awb_number,
      'tracking_url', v_order.tracking_url,
      'payout_settlement_status', v_order.payout_settlement_status
    );

  return jsonb_build_object(
    'order', v_order_json,
    'items', v_items
  );
end;
$$;


create or replace function public.list_customer_shop_orders(
  p_tenant_id bigint,
  p_limit integer default 20,
  p_offset integer default 0,
  p_status_bucket text default null
)
returns table(
  id bigint,
  shop_id bigint,
  shop_name text,
  shop_slug text,
  shop_type_snapshot public.shop_type_enum,
  order_no text,
  status public.shop_order_status,
  item_count bigint,
  can_see_buy_price boolean,
  can_see_sell_price boolean,
  sell_currency_id bigint,
  currency_symbol text,
  total_amount numeric,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_group_id bigint;
  v_limit integer;
  v_offset integer;
begin
  if p_tenant_id is null then
    return;
  end if;

  if p_status_bucket is not null
     and p_status_bucket not in ('needs_you', 'in_progress', 'done') then
    return;
  end if;

  v_group_id := public.current_customer_group_id(p_tenant_id);
  if v_group_id is null then
    return;
  end if;

  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  return query
  select
    o.id,
    o.shop_id,
    s.name as shop_name,
    s.slug as shop_slug,
    o.shop_type_snapshot,
    o.order_no,
    o.status,
    (
      select count(*)::bigint
      from public.shop_order_items soi
      where soi.order_id = o.id
    ) as item_count,
    case
      when o.shop_type_snapshot = 'dropship'::public.shop_type_enum then true
      when o.cart_id is not null then coalesce(c.can_see_buy_price_snapshot, false)
      else coalesce(live_perm.can_see_buy_price, false)
    end as can_see_buy_price,
    case
      when o.shop_type_snapshot = 'dropship'::public.shop_type_enum then true
      when o.cart_id is not null then coalesce(c.can_see_sell_price_snapshot, false)
      else coalesce(live_perm.can_see_sell_price, false)
    end as can_see_sell_price,
    s.sell_currency_id,
    gc.symbol as currency_symbol,
    case
      when (
        case
          when o.shop_type_snapshot = 'dropship'::public.shop_type_enum then true
          when o.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum then
            case
              when o.cart_id is not null then coalesce(c.can_see_buy_price_snapshot, false)
              else coalesce(live_perm.can_see_buy_price, false)
            end
            or (
              case
                when o.cart_id is not null then coalesce(c.can_see_sell_price_snapshot, false)
                else coalesce(live_perm.can_see_sell_price, false)
              end
              and exists (
                select 1
                from public.shop_order_items soi2
                where soi2.order_id = o.id
                  and coalesce(soi2.staff_offer_amount, soi2.final_price_amount, soi2.customer_offer_amount) is not null
              )
            )
          when o.cart_id is not null then coalesce(c.can_see_sell_price_snapshot, false)
          else coalesce(live_perm.can_see_sell_price, false)
        end
      ) then
        coalesce(
          (
            select sum(
              coalesce(
                soi.final_price_amount,
                soi.staff_offer_amount,
                soi.customer_offer_amount,
                soi.unit_sell_price_amount,
                case
                  when o.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum
                    and not (
                      case
                        when o.cart_id is not null then coalesce(c.can_see_buy_price_snapshot, false)
                        else coalesce(live_perm.can_see_buy_price, false)
                      end
                    ) then null
                  else soi.unit_list_price_amount
                end
              ) * soi.quantity
            )
            from public.shop_order_items soi
            where soi.order_id = o.id
          ),
          0
        )::numeric
      else null
    end as total_amount,
    o.created_at
  from public.shop_orders o
  join public.shops s on s.id = o.shop_id
  left join public.shop_carts c on c.id = o.cart_id
  left join lateral (
    select p.can_see_buy_price, p.can_see_sell_price
    from public.get_shop_permissions_for_customer(o.shop_id) p
    limit 1
  ) live_perm on true
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  where o.tenant_id = p_tenant_id
    and o.customer_group_id = v_group_id
    and o.status is distinct from 'draft'
    and (
      p_status_bucket is null
      or public.customer_shop_order_glance_bucket(o.status) = p_status_bucket
    )
  order by o.created_at desc
  limit v_limit
  offset v_offset;
end;
$$;

commit;
