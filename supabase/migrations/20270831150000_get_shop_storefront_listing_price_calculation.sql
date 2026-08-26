-- Calculate sell price drawer: shipment cost breakdown + weighted avg cost for a storefront listing.

create or replace function public.get_shop_storefront_listing_price_calculation(
  p_shop_id bigint,
  p_listing_id bigint
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_buy_currency_id bigint;
  v_sell_currency_id bigint;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_listing record;
  v_product_id bigint;
  v_grade_tag_id bigint;
  v_cost_currency_id bigint;
  v_result jsonb;
begin
  select
    s.tenant_id,
    s.shop_type,
    s.buy_currency_id,
    s.sell_currency_id,
    s.pricing_method,
    s.markup_percentage
  into
    v_tenant_id,
    v_shop_type,
    v_buy_currency_id,
    v_sell_currency_id,
    v_pricing_method,
    v_markup_percentage
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

  select
    l.id,
    l.shop_id,
    l.product_id,
    l.global_stock_id,
    l.sell_price_amount,
    l.sell_price_currency_id,
    l.minimum_sell_price_amount,
    l.minimum_sell_price_currency_id,
    l.display_quantity_override,
    l.is_active,
    l.is_price_locked,
    l.show_quantity,
    p.name as product_name,
    p.product_code,
    p.image_url as product_image_url,
    tg.slug as grade_slug,
    tg.name as grade_label,
    tg.color as grade_color,
    gs.grade_tag_id
  into v_listing
  from public.shop_product_listings l
  join public.products p on p.id = l.product_id
  join public.global_stocks gs on gs.id = l.global_stock_id
  left join public.tags tg on tg.id = gs.grade_tag_id
  where l.id = p_listing_id
    and l.shop_id = p_shop_id;

  if v_listing.id is null then
    raise exception 'listing not found';
  end if;

  v_product_id := v_listing.product_id;
  v_grade_tag_id := coalesce(v_listing.grade_tag_id, public.default_stock_grade_tag_id());
  v_cost_currency_id := case
    when v_shop_type = 'dropship'::public.shop_type_enum then v_buy_currency_id
    else v_sell_currency_id
  end;

  with stock_lines as (
    select
      gship.id as shipment_id,
      gship.name as shipment_name,
      greatest(0, floor(public.global_stock_atp_qty(gs.id)))::integer as quantity,
      coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id), 0)::numeric as unit_cost_amount
    from public.global_stocks gs
    join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    join public.global_shipments gship on gship.id = gsi.shipment_id
    left join public.stock_locations sl on sl.id = gs.location_id
    where gsi.product_id = v_product_id
      and coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id
      and gship.assigned_child_tenant_id = v_tenant_id
      and gship.status = 'received'
      and gs.availability = 'sellable'::public.stock_availability
      and (gs.location_id is null or sl.is_pickable = true)
      and public.global_stock_atp_qty(gs.id) > 0
  ),
  shipment_agg as (
    select
      sl.shipment_id,
      sl.shipment_name,
      sum(sl.quantity)::integer as quantity,
      case
        when sum(sl.quantity) > 0 then round(sum(sl.quantity * sl.unit_cost_amount) / sum(sl.quantity), 4)
        else 0::numeric
      end as unit_cost_amount
    from stock_lines sl
    group by sl.shipment_id, sl.shipment_name
  ),
  totals as (
    select
      coalesce(sum(sa.quantity), 0)::integer as total_quantity,
      case
        when coalesce(sum(sa.quantity), 0) > 0 then round(
          (
            select sum(sl.quantity * sl.unit_cost_amount)
            from stock_lines sl
          ) / sum(sa.quantity),
          4
        )
        else 0::numeric
      end as weighted_avg_cost
    from shipment_agg sa
  )
  select
    jsonb_build_object(
      'listing',
      jsonb_build_object(
        'listing_id', v_listing.id,
        'shop_id', v_listing.shop_id,
        'product_id', v_product_id,
        'product_name', v_listing.product_name,
        'product_code', v_listing.product_code,
        'product_image_url', v_listing.product_image_url,
        'global_stock_id', v_listing.global_stock_id,
        'grade_tag_id', v_grade_tag_id,
        'stock_grade',
        case
          when v_listing.grade_slug is not null then jsonb_build_object(
            'slug', v_listing.grade_slug,
            'label', v_listing.grade_label,
            'color', v_listing.grade_color
          )
          else null
        end,
        'is_active', v_listing.is_active,
        'is_price_locked', v_listing.is_price_locked
      ),
      'shipment_costs',
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'shipment_id', sa.shipment_id,
              'shipment_no', 'SHP-' || sa.shipment_id::text,
              'shipment_name', sa.shipment_name,
              'quantity', sa.quantity,
              'unit_cost_amount', sa.unit_cost_amount
            )
            order by sa.shipment_name asc, sa.shipment_id asc
          )
          from shipment_agg sa
        ),
        '[]'::jsonb
      ),
      'totals',
      (
        select jsonb_build_object(
          'total_quantity', t.total_quantity,
          'real_available_units', t.total_quantity,
          'weighted_avg_cost',
          jsonb_build_object(
            'amount', t.weighted_avg_cost,
            'currency_id', v_cost_currency_id,
            'code', (select gc.code from public.global_currencies gc where gc.id = v_cost_currency_id),
            'symbol', (select gc.symbol from public.global_currencies gc where gc.id = v_cost_currency_id)
          )
        )
        from totals t
      ),
      'pricing',
      jsonb_build_object(
        'display_quantity_override', v_listing.display_quantity_override,
        'suggested_display_quantity', coalesce(
          (
            select t.total_quantity
            from totals t
          ),
          0
        ),
        'sell_price',
        jsonb_build_object(
          'amount', v_listing.sell_price_amount,
          'currency_id', v_listing.sell_price_currency_id,
          'code', (
            select gc.code
            from public.global_currencies gc
            where gc.id = v_listing.sell_price_currency_id
          ),
          'symbol', (
            select gc.symbol
            from public.global_currencies gc
            where gc.id = v_listing.sell_price_currency_id
          )
        ),
        'suggested_sell_price',
        case
          when v_shop_type = 'fixed_price'::public.shop_type_enum
            and v_pricing_method = 'markup'
            and (
              select t.weighted_avg_cost
              from totals t
            ) is not null then jsonb_build_object(
            'amount',
            round(
              (
                select t.weighted_avg_cost
                from totals t
              ) * (1 + coalesce(v_markup_percentage, 0) / 100.0),
              4
            ),
            'currency_id', v_listing.sell_price_currency_id,
            'code', (
              select gc.code
              from public.global_currencies gc
              where gc.id = v_listing.sell_price_currency_id
            ),
            'symbol', (
              select gc.symbol
              from public.global_currencies gc
              where gc.id = v_listing.sell_price_currency_id
            )
          )
          else null
        end,
        'resell_minimum_price',
        case
          when v_shop_type = 'dropship'::public.shop_type_enum
            and v_listing.minimum_sell_price_amount is not null then jsonb_build_object(
            'amount', v_listing.minimum_sell_price_amount,
            'currency_id', v_listing.minimum_sell_price_currency_id,
            'code', (
              select gc.code
              from public.global_currencies gc
              where gc.id = v_listing.minimum_sell_price_currency_id
            ),
            'symbol', (
              select gc.symbol
              from public.global_currencies gc
              where gc.id = v_listing.minimum_sell_price_currency_id
            )
          )
          else null
        end
      ),
      'shop',
      jsonb_build_object(
        'id', p_shop_id,
        'shop_type', v_shop_type,
        'pricing_method', v_pricing_method,
        'markup_percentage', v_markup_percentage,
        'sell_currency_id', v_sell_currency_id,
        'buy_currency_id', v_buy_currency_id
      )
    )
  into v_result;

  return v_result;
end;
$$;

grant execute on function public.get_shop_storefront_listing_price_calculation(bigint, bigint) to authenticated;
