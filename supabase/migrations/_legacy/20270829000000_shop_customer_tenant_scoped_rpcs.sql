-- T1: additive tenant-scoped customer RPCs.
-- Null p_tenant_id never means "all tenants". Shop identity is (tenant_id, slug).

-- =========================================================
-- 1. Single group resolver for (email, tenant)
-- =========================================================
create or replace function public.current_customer_group_id(p_tenant_id bigint)
returns bigint
language sql
security definer
set search_path = public
stable
as $$
  select cg.id
  from public.customer_groups cg
  join public.customer_group_members cgm on cgm.customer_group_id = cg.id
  where p_tenant_id is not null
    and cg.tenant_id = p_tenant_id
    and cg.is_active = true
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email()
  order by cg.id
  limit 1;
$$;

revoke all on function public.current_customer_group_id(bigint) from public;
revoke all on function public.current_customer_group_id(bigint) from anon;
grant execute on function public.current_customer_group_id(bigint) to authenticated;

create or replace function public.is_cart_owner(p_customer_group_id bigint, p_tenant_id bigint)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select
    p_customer_group_id is not null
    and public.current_customer_group_id(p_tenant_id) = p_customer_group_id;
$$;

-- =========================================================
-- 2. list_customer_shops
-- =========================================================
create or replace function public.list_customer_shops(p_tenant_id bigint)
returns table (
  id            bigint,
  tenant_id     bigint,
  name          text,
  slug          text,
  shop_type     public.shop_type_enum,
  order_mode    public.shop_order_mode_enum,
  is_negotiable boolean,
  see_price     boolean,
  description   text,
  category_ids  bigint[],
  categories    jsonb,
  sell_currency_id bigint,
  sell_currency_code text,
  sell_currency_symbol text
)
language sql
security definer
set search_path = public
stable
as $$
  select
    s.id,
    s.tenant_id,
    s.name,
    s.slug,
    s.shop_type,
    s.order_mode,
    s.is_negotiable,
    bool_or(
      case
        when access.status = false or coalesce(profile.is_active, true) = false then false
        else coalesce(access.see_price, profile.default_see_price, false)
      end
    ) as see_price,
    s.description,
    s.category_ids,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', c.id,
            'name', c.name,
            'slug', c.slug,
            'icon', c.icon
          )
        )
        from public.shop_categories c
        where c.id = any(s.category_ids)
          and c.is_active = true
      ),
      '[]'::jsonb
    ) as categories,
    s.sell_currency_id,
    gc.code as sell_currency_code,
    gc.symbol as sell_currency_symbol
  from public.shops s
  join public.shop_customer_group_access access on access.shop_id = s.id
  join public.customer_groups cg on cg.id = access.customer_group_id
  left join public.customer_group_shop_profiles profile
    on profile.customer_group_id = cg.id and profile.tenant_id = s.tenant_id
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  where p_tenant_id is not null
    and s.is_active = true
    and s.deleted_at is null
    and s.tenant_id = p_tenant_id
    and cg.id = public.current_customer_group_id(p_tenant_id)
    and cg.is_active = true
    and access.status = true
    and coalesce(profile.is_active, true) = true
    and coalesce(access.can_browse, profile.default_can_browse, false) = true
  group by
    s.id,
    s.tenant_id,
    s.name,
    s.slug,
    s.shop_type,
    s.order_mode,
    s.is_negotiable,
    s.description,
    s.category_ids,
    s.sell_currency_id,
    gc.code,
    gc.symbol
  order by s.name asc;
$$;

revoke all on function public.list_customer_shops(bigint) from public;
revoke all on function public.list_customer_shops(bigint) from anon;
grant execute on function public.list_customer_shops(bigint) to authenticated;

-- =========================================================
-- 3. list_customer_active_carts
-- =========================================================
create or replace function public.list_customer_active_carts(p_tenant_id bigint)
returns table (
  cart_id bigint,
  shop_id bigint,
  shop_name text,
  shop_slug text,
  shop_logo_url text,
  shop_type text,
  see_price boolean,
  currency_id bigint,
  currency_code text,
  currency_symbol text,
  item_count bigint,
  cart_total numeric,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    c.id as cart_id,
    s.id as shop_id,
    s.name as shop_name,
    s.slug as shop_slug,
    null::text as shop_logo_url,
    s.shop_type::text as shop_type,
    c.see_price_snapshot as see_price,
    s.sell_currency_id as currency_id,
    gc.code as currency_code,
    gc.symbol as currency_symbol,
    coalesce(sum(ci.quantity), 0)::bigint as item_count,
    case
      when c.see_price_snapshot then
        sum(
          ci.quantity * coalesce(
            ci.customer_sell_price_amount,
            ci.unit_sell_price_amount,
            ci.unit_list_price_amount,
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
  where p_tenant_id is not null
    and c.status = 'active'
    and c.tenant_id = p_tenant_id
    and c.customer_group_id = public.current_customer_group_id(p_tenant_id)
  group by c.id, s.id, gc.code, gc.symbol
  order by c.updated_at desc;
$$;

revoke all on function public.list_customer_active_carts(bigint) from public;
revoke all on function public.list_customer_active_carts(bigint) from anon;
grant execute on function public.list_customer_active_carts(bigint) to authenticated;

-- =========================================================
-- 4. list_customer_shop_orders — one call for all shops
-- =========================================================
create or replace function public.list_customer_shop_orders(
  p_tenant_id bigint,
  p_limit integer default 20,
  p_offset integer default 0,
  p_status_bucket text default null
)
returns table (
  id bigint,
  shop_id bigint,
  shop_name text,
  shop_slug text,
  shop_type_snapshot public.shop_type_enum,
  order_no text,
  status public.shop_order_status,
  item_count bigint,
  total_amount numeric,
  currency_symbol text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
stable
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
    coalesce(
      (
        select sum(
          coalesce(
            soi.final_price_amount,
            soi.customer_offer_amount,
            soi.unit_sell_price_amount,
            soi.unit_list_price_amount
          ) * soi.quantity
        )
        from public.shop_order_items soi
        where soi.order_id = o.id
      ),
      0
    )::numeric as total_amount,
    gc.symbol as currency_symbol,
    o.created_at
  from public.shop_orders o
  join public.shops s on s.id = o.shop_id
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  where o.tenant_id = p_tenant_id
    and o.customer_group_id = v_group_id
    and o.status is distinct from 'draft'
    and (
      p_status_bucket is null
      or (
        p_status_bucket = 'needs_you'
        and o.status in ('priced', 'negotiating', 'countered', 'final_offered')
      )
      or (
        p_status_bucket = 'done'
        and o.status in ('fulfilled', 'delivered', 'payment_received', 'cancelled', 'returned')
      )
      or (
        p_status_bucket = 'in_progress'
        and o.status not in (
          'draft',
          'priced',
          'negotiating',
          'countered',
          'final_offered',
          'fulfilled',
          'delivered',
          'payment_received',
          'cancelled',
          'returned'
        )
      )
    )
  order by o.created_at desc
  limit v_limit
  offset v_offset;
end;
$$;

revoke all on function public.list_customer_shop_orders(bigint, integer, integer, text) from public;
revoke all on function public.list_customer_shop_orders(bigint, integer, integer, text) from anon;
grant execute on function public.list_customer_shop_orders(bigint, integer, integer, text) to authenticated;

-- =========================================================
-- 5. get_customer_shop_order
-- =========================================================
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
        soi.unit_list_price_amount
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
        'unit_list_price_amount', soi.unit_list_price_amount,
        'unit_list_price_currency_id', soi.unit_list_price_currency_id,
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
        'ordered_quantity', soi.ordered_quantity,
        'delivered_quantity', soi.delivered_quantity,
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

  return jsonb_build_object(
    'order', jsonb_build_object(
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
      'total_amount', v_total_amount,
      'cod_collect_amount', v_order.cod_collect_amount,
      'courier_name', v_order.courier_name,
      'courier_awb_number', v_order.courier_awb_number,
      'tracking_url', v_order.tracking_url,
      'payout_settlement_status', v_order.payout_settlement_status
    ),
    'items', v_items
  );
end;
$$;

revoke all on function public.get_customer_shop_order(bigint, bigint) from public;
revoke all on function public.get_customer_shop_order(bigint, bigint) from anon;
grant execute on function public.get_customer_shop_order(bigint, bigint) to authenticated;

-- =========================================================
-- 6. browse_shop_catalog_for_customer — shop by (tenant_id, slug)
-- =========================================================
create or replace function public.browse_shop_catalog_for_customer(
  p_tenant_id bigint,
  p_shop_slug text,
  p_search text default null,
  p_category text default null,
  p_brand text default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_shop_id bigint;
  v_tenant_id bigint;
  v_shop_name text;
  v_shop_type public.shop_type_enum;
  v_vendor_code text;
  v_order_mode public.shop_order_mode_enum;
  v_is_negotiable boolean;
  v_show_stock_quantity boolean;
  v_default_currency_id bigint;
  v_is_active boolean;
  v_buy_currency_id bigint;
  v_sell_currency_id bigint;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_quantity_display_mode text;
  v_vendor_filters jsonb;
  v_can_browse boolean;
  v_see_price boolean;
  v_can_add_to_cart boolean;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_can_view_quantity boolean;
  v_can_set_dropship_price boolean;
  v_limit integer;
  v_offset integer;
  v_result jsonb;
begin
  if p_tenant_id is null then
    raise exception 'tenant required';
  end if;

  if public.current_customer_group_id(p_tenant_id) is null then
    raise exception 'access denied';
  end if;

  select
    id, tenant_id, name, shop_type, vendor_code, order_mode,
    is_negotiable, show_stock_quantity, default_currency_id, is_active,
    buy_currency_id, sell_currency_id, pricing_method, markup_percentage, quantity_display_mode,
    vendor_filters
  into
    v_shop_id, v_tenant_id, v_shop_name, v_shop_type, v_vendor_code, v_order_mode,
    v_is_negotiable, v_show_stock_quantity, v_default_currency_id, v_is_active,
    v_buy_currency_id, v_sell_currency_id, v_pricing_method, v_markup_percentage, v_quantity_display_mode,
    v_vendor_filters
  from public.shops
  where slug = p_shop_slug
    and tenant_id = p_tenant_id
    and deleted_at is null;

  if v_shop_id is null or v_is_active is not true then
    raise exception 'shop not found or inactive';
  end if;

  select
    can_browse, see_price, can_add_to_cart, can_place_order,
    can_negotiate, can_view_quantity, can_set_dropship_price
  into
    v_can_browse, v_see_price, v_can_add_to_cart, v_can_place_order,
    v_can_negotiate, v_can_view_quantity, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(v_shop_id);

  if coalesce(v_can_browse, false) is not true then
    raise exception 'access denied';
  end if;

  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  if v_shop_type = 'vendor_catalog' then
    execute format(
      $sql$
        with filtered as (
          select p.*
          from public.products p
          where p.is_available = true
            and (p.tenant_id = $2 or p.parent_tenant_id = $2)
            and (
              (($9 is null or jsonb_array_length($9) = 0) and p.vendor_code = $1)
              or
              ($9 is not null and jsonb_array_length($9) > 0 and exists (
                select 1
                from jsonb_to_recordset($9) as vf(vendor_code text, brands text[])
                where vf.vendor_code = p.vendor_code
                  and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
              ))
            )
            and ($3 is null or trim($3) = '' or p.name ilike ('%%' || trim($3) || '%%') or p.product_code ilike ('%%' || trim($3) || '%%') or p.barcode ilike ('%%' || trim($3) || '%%'))
            and ($4 is null or trim($4) = '' or lower(coalesce(p.category, '')) = lower(trim($4)))
            and ($5 is null or trim($5) = '' or lower(coalesce(p.brand, '')) = lower(trim($5)))
        ),
        paged as (
          select f.*
          from filtered f
          order by f.name asc, f.id asc
          limit $6
          offset $7
        )
        select jsonb_build_object(
          'data',
          coalesce(
            (
              select jsonb_agg(
                jsonb_build_object(
                  'product_id', p.id,
                  'product_name', p.name,
                  'product_image_url', p.image_url,
                  'product_barcode', p.barcode,
                  'product_code', p.product_code,
                  'product_brand', p.brand,
                  'product_category', p.category,
                  'vendor_code', p.vendor_code,
                  'is_available', p.is_available,
                  'unit_price_amount', case when $8 then p.list_price_amount else null end,
                  'unit_price_currency_id', case when $8 then p.list_price_currency_id else null end,
                  'unit_price_currency_code', case when $8 then (select code from public.global_currencies where id = p.list_price_currency_id) else null end,
                  'unit_price_currency_symbol', case when $8 then (select symbol from public.global_currencies where id = p.list_price_currency_id) else null end,
                  'minimum_sell_price_amount', null,
                  'minimum_sell_price_currency_id', null,
                  'minimum_sell_price_currency_code', null,
                  'minimum_sell_price_currency_symbol', null,
                  'available_units', null,
                  'global_stock_allocation_id', null,
                  'global_stock_id', null,
                  'minimum_order_quantity', p.minimum_order_quantity
                )
              )
              from paged p
            ),
            '[]'::jsonb
          ),
          'meta',
          jsonb_build_object(
            'total', (select count(*) from filtered),
            'page', (($7 / $6) + 1),
            'page_size', $6,
            'total_pages', greatest(1, ceil((select count(*)::numeric from filtered) / $6::numeric))
          )
        )
      $sql$
    )
    into v_result
    using
      v_vendor_code,
      v_tenant_id,
      p_search,
      p_category,
      p_brand,
      v_limit,
      v_offset,
      v_see_price,
      v_vendor_filters;
  else
    execute format(
      $sql$
        with filtered as (
          select
            l.id as listing_id,
            l.global_stock_id,
            case
              when $8 = 'fixed_price' and $11 = 'markup' then
                coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) * (1 + $12 / 100.0)
              when $8 = 'fixed_price' and $11 = 'direct_cost' then
                coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id))
              else
                l.sell_price_amount
            end as computed_sell_price,
            l.sell_price_currency_id,
            l.minimum_sell_price_amount,
            l.minimum_sell_price_currency_id,
            l.show_quantity as listing_show_quantity,
            l.display_quantity_override,
            p.id as product_id,
            p.name as product_name,
            p.image_url as product_image_url,
            p.barcode as product_barcode,
            p.product_code as product_code,
            p.brand as product_brand,
            p.category as product_category,
            p.vendor_code as product_vendor_code,
            p.is_available as product_is_available,
            p.minimum_order_quantity as product_moq,
            greatest(0, floor(public.global_stock_atp_qty(gs.id)))::integer as available_qty
          from public.shop_product_listings l
          join public.products p on p.id = l.product_id
          join public.global_stocks gs on gs.id = l.global_stock_id
          left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
          left join public.global_shipments gship on gship.id = gsi.shipment_id
            and gship.assigned_child_tenant_id = $14
          where l.shop_id = $1
            and l.global_stock_id is not null
            and coalesce(gship.status, 'received') = 'received'
            and l.is_active = true
            and ($2 is null or trim($2) = '' or p.name ilike ('%%' || trim($2) || '%%') or p.product_code ilike ('%%' || trim($2) || '%%') or p.barcode ilike ('%%' || trim($2) || '%%'))
            and ($3 is null or trim($3) = '' or lower(coalesce(p.category, '')) = lower(trim($3)))
            and ($4 is null or trim($4) = '' or lower(coalesce(p.brand, '')) = lower(trim($4)))
        ),
        paged as (
          select f.*
          from filtered f
          order by f.product_name asc, f.listing_id asc
          limit $5
          offset $6
        )
        select jsonb_build_object(
          'data',
          coalesce(
            (
              select jsonb_agg(
                jsonb_build_object(
                  'product_id', p.product_id,
                  'product_name', p.product_name,
                  'product_image_url', p.product_image_url,
                  'product_barcode', p.product_barcode,
                  'product_code', p.product_code,
                  'product_brand', p.product_brand,
                  'product_category', p.product_category,
                  'vendor_code', p.product_vendor_code,
                  'is_available', p.product_is_available,
                  'unit_price_amount', case when $7 then p.computed_sell_price else null end,
                  'unit_price_currency_id', case when $7 then p.sell_price_currency_id else null end,
                  'unit_price_currency_code', case when $7 then (select code from public.global_currencies where id = p.sell_price_currency_id) else null end,
                  'unit_price_currency_symbol', case when $7 then (select symbol from public.global_currencies where id = p.sell_price_currency_id) else null end,
                  'minimum_sell_price_amount', case when $7 and $8 = 'dropship' then p.minimum_sell_price_amount else null end,
                  'minimum_sell_price_currency_id', case when $7 and $8 = 'dropship' then p.minimum_sell_price_currency_id else null end,
                  'minimum_sell_price_currency_code', case when $7 and $8 = 'dropship' then (select code from public.global_currencies where id = p.minimum_sell_price_currency_id) else null end,
                  'minimum_sell_price_currency_symbol', case when $7 and $8 = 'dropship' then (select symbol from public.global_currencies where id = p.minimum_sell_price_currency_id) else null end,
                  'available_units', case
                    when not $9 or not coalesce(p.listing_show_quantity, $10) then null
                    when $13 = 'original' then greatest(0, p.available_qty)
                    when p.display_quantity_override is not null then p.display_quantity_override
                    else greatest(0, p.available_qty)
                  end,
                  'global_stock_allocation_id', p.global_stock_id,
                  'global_stock_id', p.global_stock_id,
                  'minimum_order_quantity', p.product_moq
                )
              )
              from paged p
            ),
            '[]'::jsonb
          ),
          'meta',
          jsonb_build_object(
            'total', (select count(*) from filtered),
            'page', (($6 / $5) + 1),
            'page_size', $5,
            'total_pages', greatest(1, ceil((select count(*)::numeric from filtered) / $5::numeric))
          )
        )
      $sql$
    )
    into v_result
    using
      v_shop_id,
      p_search,
      p_category,
      p_brand,
      v_limit,
      v_offset,
      v_see_price,
      v_shop_type,
      v_can_view_quantity,
      v_show_stock_quantity,
      v_pricing_method,
      v_markup_percentage,
      v_quantity_display_mode,
      v_tenant_id;
  end if;

  v_result := jsonb_set(v_result, '{meta, shop}', jsonb_build_object(
    'id', v_shop_id,
    'name', v_shop_name,
    'slug', p_shop_slug,
    'shop_type', v_shop_type,
    'vendor_code', v_vendor_code,
    'order_mode', v_order_mode,
    'is_negotiable', v_is_negotiable,
    'show_stock_quantity', v_show_stock_quantity,
    'default_currency_id', v_default_currency_id,
    'is_active', v_is_active,
    'buy_currency_id', v_buy_currency_id,
    'sell_currency_id', v_sell_currency_id,
    'pricing_method', v_pricing_method,
    'markup_percentage', v_markup_percentage,
    'quantity_display_mode', v_quantity_display_mode,
    'vendor_filters', v_vendor_filters
  ));

  return v_result;
end;
$$;

revoke all on function public.browse_shop_catalog_for_customer(bigint, text, text, text, text, integer, integer) from public;
revoke all on function public.browse_shop_catalog_for_customer(bigint, text, text, text, text, integer, integer) from anon;
grant execute on function public.browse_shop_catalog_for_customer(bigint, text, text, text, text, integer, integer) to authenticated;
