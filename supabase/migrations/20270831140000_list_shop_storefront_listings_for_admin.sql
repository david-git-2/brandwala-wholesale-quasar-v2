-- Admin storefront tab: list shop listings as customer-style catalog cards (with grade + qty breakdown).

create or replace function public.list_shop_storefront_listings_for_admin(
  p_shop_id bigint,
  p_search text default null,
  p_limit integer default 200,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
  v_shop_name text;
  v_shop_slug text;
  v_shop_type public.shop_type_enum;
  v_buy_currency_id bigint;
  v_sell_currency_id bigint;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_quantity_display_mode text;
  v_limit integer;
  v_offset integer;
  v_result jsonb;
begin
  select
    s.tenant_id,
    s.name,
    s.slug,
    s.shop_type,
    s.buy_currency_id,
    s.sell_currency_id,
    s.pricing_method,
    s.markup_percentage,
    s.quantity_display_mode
  into
    v_tenant_id,
    v_shop_name,
    v_shop_slug,
    v_shop_type,
    v_buy_currency_id,
    v_sell_currency_id,
    v_pricing_method,
    v_markup_percentage,
    v_quantity_display_mode
  from public.shops s
  where s.id = p_shop_id
    and s.deleted_at is null;

  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.has_active_tenant_membership(v_tenant_id)
     and not public.has_active_tenant_membership(public.resolve_parent_tenant_id(v_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not allowed';
  end if;

  if v_shop_type = 'vendor_catalog' then
    return jsonb_build_object(
      'data',
      '[]'::jsonb,
      'meta',
      jsonb_build_object(
        'total',
        0,
        'page',
        1,
        'page_size',
        0,
        'total_pages',
        1,
        'shop',
        jsonb_build_object(
          'id',
          p_shop_id,
          'name',
          v_shop_name,
          'slug',
          v_shop_slug,
          'shop_type',
          v_shop_type
        )
      )
    );
  end if;

  v_limit := greatest(1, least(coalesce(p_limit, 200), 500));
  v_offset := greatest(0, coalesce(p_offset, 0));

  with filtered as (
    select
      l.id as listing_id,
      l.product_id,
      l.global_stock_id,
      l.global_stock_allocation_id,
      l.sell_price_amount as listing_sell_price_amount,
      l.sell_price_currency_id as listing_sell_price_currency_id,
      l.minimum_sell_price_amount,
      l.minimum_sell_price_currency_id,
      l.show_quantity,
      l.display_quantity_override,
      l.is_active,
      coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id), 0)::numeric as unit_cost_amount,
      case
        when v_shop_type = 'fixed_price'::public.shop_type_enum
          and v_pricing_method = 'markup' then
          coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id), 0)
          * (1 + coalesce(v_markup_percentage, 0) / 100.0)
        when v_shop_type = 'fixed_price'::public.shop_type_enum
          and v_pricing_method = 'direct_cost' then
          coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id), 0)
        else
          l.sell_price_amount
      end as computed_sell_price,
      p.name as product_name,
      p.image_url as product_image_url,
      p.barcode as product_barcode,
      p.product_code as product_code,
      p.brand as product_brand,
      p.category as product_category,
      p.vendor_code as vendor_code,
      p.is_available as product_is_available,
      p.minimum_order_quantity as product_moq,
      greatest(0, floor(public.global_stock_atp_qty(gs.id)))::integer as real_available_units,
      tg.slug as grade_slug,
      tg.name as grade_label,
      tg.color as grade_color
    from public.shop_product_listings l
    join public.products p on p.id = l.product_id
    join public.global_stocks gs on gs.id = l.global_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments gship on gship.id = gsi.shipment_id
    left join public.tags tg on tg.id = gs.grade_tag_id
    where l.shop_id = p_shop_id
      and l.global_stock_id is not null
      and (
        p_search is null
        or trim(p_search) = ''
        or p.name ilike ('%' || trim(p_search) || '%')
        or p.product_code ilike ('%' || trim(p_search) || '%')
        or p.barcode ilike ('%' || trim(p_search) || '%')
        or p.brand ilike ('%' || trim(p_search) || '%')
        or p.category ilike ('%' || trim(p_search) || '%')
        or tg.name ilike ('%' || trim(p_search) || '%')
        or tg.slug ilike ('%' || trim(p_search) || '%')
      )
  ),
  paged as (
    select
      f.*
    from filtered f
    order by f.product_name asc, f.grade_slug asc nulls last, f.listing_id asc
    limit v_limit
    offset v_offset
  )
  select
    jsonb_build_object(
      'data',
      coalesce(
        (
          select
            jsonb_agg(
              jsonb_build_object(
                'listing_id',
                p.listing_id,
                'product_id',
                p.product_id,
                'product_name',
                p.product_name,
                'product_image_url',
                p.product_image_url,
                'product_barcode',
                p.product_barcode,
                'product_code',
                p.product_code,
                'product_brand',
                p.product_brand,
                'product_category',
                p.product_category,
                'vendor_code',
                p.vendor_code,
                'is_available',
                p.product_is_available,
                'minimum_order_quantity',
                p.product_moq,
                'global_stock_id',
                p.global_stock_id,
                'global_stock_allocation_id',
                p.global_stock_allocation_id,
                'real_available_units',
                p.real_available_units,
                'display_quantity_override',
                p.display_quantity_override,
                'available_units',
                case
                  when p.display_quantity_override is not null then p.display_quantity_override
                  else p.real_available_units
                end,
                'listing_status',
                case
                  when p.is_active then 'active'
                  else 'inactive'
                end,
                'stock_grade',
                case
                  when p.grade_slug is not null then jsonb_build_object(
                    'slug',
                    p.grade_slug,
                    'label',
                    p.grade_label,
                    'color',
                    p.grade_color
                  )
                  else null
                end,
                'unit_price',
                case
                  when v_shop_type = 'dropship'::public.shop_type_enum then jsonb_build_object(
                    'amount',
                    round(p.unit_cost_amount, 4),
                    'currency_id',
                    v_buy_currency_id,
                    'code',
                    (
                      select gc.code
                      from public.global_currencies gc
                      where gc.id = v_buy_currency_id
                    ),
                    'symbol',
                    (
                      select gc.symbol
                      from public.global_currencies gc
                      where gc.id = v_buy_currency_id
                    )
                  )
                  else null
                end,
                'sell_price',
                jsonb_build_object(
                  'amount',
                  round(p.computed_sell_price, 4),
                  'currency_id',
                  p.listing_sell_price_currency_id,
                  'code',
                  (
                    select gc.code
                    from public.global_currencies gc
                    where gc.id = p.listing_sell_price_currency_id
                  ),
                  'symbol',
                  (
                    select gc.symbol
                    from public.global_currencies gc
                    where gc.id = p.listing_sell_price_currency_id
                  )
                ),
                'resell_minimum_price',
                case
                  when v_shop_type = 'dropship'::public.shop_type_enum
                    and p.minimum_sell_price_amount is not null then jsonb_build_object(
                    'amount',
                    round(p.minimum_sell_price_amount, 4),
                    'currency_id',
                    p.minimum_sell_price_currency_id,
                    'code',
                    (
                      select gc.code
                      from public.global_currencies gc
                      where gc.id = p.minimum_sell_price_currency_id
                    ),
                    'symbol',
                    (
                      select gc.symbol
                      from public.global_currencies gc
                      where gc.id = p.minimum_sell_price_currency_id
                    )
                  )
                  else null
                end,
                'avg_cost',
                jsonb_build_object(
                  'amount',
                  round(p.unit_cost_amount, 4),
                  'currency_id',
                  case
                    when v_shop_type = 'dropship'::public.shop_type_enum then v_buy_currency_id
                    else v_sell_currency_id
                  end,
                  'code',
                  (
                    select gc.code
                    from public.global_currencies gc
                    where gc.id = case
                      when v_shop_type = 'dropship'::public.shop_type_enum then v_buy_currency_id
                      else v_sell_currency_id
                    end
                  ),
                  'symbol',
                  (
                    select gc.symbol
                    from public.global_currencies gc
                    where gc.id = case
                      when v_shop_type = 'dropship'::public.shop_type_enum then v_buy_currency_id
                      else v_sell_currency_id
                    end
                  )
                ),
                'show_quantity',
                p.show_quantity,
                'sell_price_amount',
                p.listing_sell_price_amount,
                'sell_price_currency_id',
                p.listing_sell_price_currency_id,
                'minimum_sell_price_amount',
                p.minimum_sell_price_amount,
                'minimum_sell_price_currency_id',
                p.minimum_sell_price_currency_id
              )
              order by
                p.product_name asc,
                p.grade_slug asc nulls last,
                p.listing_id asc
            )
          from
            paged p
        ),
        '[]'::jsonb
      ),
      'meta',
      jsonb_build_object(
        'total',
        (
          select
            count(*)
          from
            filtered
        ),
        'page',
        (v_offset / v_limit) + 1,
        'page_size',
        v_limit,
        'total_pages',
        greatest(
          1,
          ceil(
            (
              select
                count(*)::numeric
              from
                filtered
            ) / v_limit::numeric
          )
        ),
        'shop',
        jsonb_build_object(
          'id',
          p_shop_id,
          'name',
          v_shop_name,
          'slug',
          v_shop_slug,
          'shop_type',
          v_shop_type,
          'sell_currency_id',
          v_sell_currency_id,
          'buy_currency_id',
          v_buy_currency_id,
          'pricing_method',
          v_pricing_method,
          'markup_percentage',
          v_markup_percentage,
          'quantity_display_mode',
          v_quantity_display_mode
        )
      )
    )
  into v_result;

  return v_result;
end;
$$;

grant execute on function public.list_shop_storefront_listings_for_admin(bigint, text, integer, integer) to authenticated;

-- Expose stock grade on listable stock rows (storefront copy-grade + add product flows).
create or replace function public.list_listable_stock_for_shop(
  p_shop_id bigint,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_shop_tenant_id bigint;
  v_total_count bigint;
  v_data jsonb;
begin
  select s.tenant_id into v_shop_tenant_id
  from public.shops s
  where s.id = p_shop_id
    and s.deleted_at is null;

  if v_shop_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.has_active_tenant_membership(v_shop_tenant_id)
     and not public.has_active_tenant_membership(public.resolve_parent_tenant_id(v_shop_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  select count(distinct gs.id)
  into v_total_count
  from public.global_stocks gs
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  join public.global_shipments gship on gship.id = gsi.shipment_id
  left join public.stock_locations sl on sl.id = gs.location_id
  where gship.assigned_child_tenant_id = v_shop_tenant_id
    and gship.status = 'received'
    and gs.availability = 'sellable'::public.stock_availability
    and (gs.location_id is null or sl.is_pickable = true)
    and public.global_stock_atp_qty(gs.id) > 0
    and not exists (
      select 1
      from public.shop_product_listings spl
      where spl.shop_id = p_shop_id
        and spl.global_stock_id = gs.id
    )
    and (
      p_search is null
      or p_search = ''
      or (
        gsi.name ilike '%' || p_search || '%'
        or gsi.product_code ilike '%' || p_search || '%'
        or gsi.barcode ilike '%' || p_search || '%'
        or gship.name ilike '%' || p_search || '%'
      )
    );

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      gs.id as sort_id,
      jsonb_build_object(
        'global_stock_id', gs.id,
        'shipment_item_id', gsi.id,
        'shipment_id', gship.id,
        'shipment_name', gship.name,
        'item_name', gsi.name,
        'product_id', gsi.product_id,
        'product_code', gsi.product_code,
        'barcode', gsi.barcode,
        'image_url', gsi.image_url,
        'available_atp', public.global_stock_atp_qty(gs.id),
        'total_stock_qty', gs.quantity,
        'unit_cost_amount', coalesce(public.calculate_landed_unit_cost(gsi.id), 0.00),
        'stock_grade', case
          when tg.slug is not null then jsonb_build_object(
            'slug', tg.slug,
            'label', tg.name,
            'color', tg.color
          )
          else null
        end
      ) as row_json
    from public.global_stocks gs
    join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    join public.global_shipments gship on gship.id = gsi.shipment_id
    left join public.stock_locations sl on sl.id = gs.location_id
    left join public.tags tg on tg.id = gs.grade_tag_id
    where gship.assigned_child_tenant_id = v_shop_tenant_id
      and gship.status = 'received'
      and gs.availability = 'sellable'::public.stock_availability
      and (gs.location_id is null or sl.is_pickable = true)
      and public.global_stock_atp_qty(gs.id) > 0
      and not exists (
        select 1
        from public.shop_product_listings spl
        where spl.shop_id = p_shop_id
          and spl.global_stock_id = gs.id
      )
      and (
        p_search is null
        or p_search = ''
        or (
          gsi.name ilike '%' || p_search || '%'
          or gsi.product_code ilike '%' || p_search || '%'
          or gsi.barcode ilike '%' || p_search || '%'
          or gship.name ilike '%' || p_search || '%'
        )
      )
    order by gs.id desc
    limit p_limit
    offset p_offset
  ) q;

  return jsonb_build_object(
    'data', v_data,
    'total', v_total_count
  );
end;
$$;

grant execute on function public.list_listable_stock_for_shop(bigint, text, integer, integer) to authenticated;
