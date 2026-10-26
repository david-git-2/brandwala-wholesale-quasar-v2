-- Storefront add-product: allow listings without allocated stock (inactive until stock is linked).

alter table public.shop_product_listings
  alter column global_stock_id drop not null;

create unique index if not exists shop_product_listings_shop_product_draft_unique
  on public.shop_product_listings (shop_id, product_id)
  where global_stock_id is null;

create or replace function public.upsert_shop_product_listing(
  p_tenant_id bigint,
  p_shop_id bigint,
  p_global_stock_allocation_id bigint default null,
  p_sell_price_amount numeric default null,
  p_sell_price_currency_id bigint default null,
  p_minimum_sell_price_amount numeric default null,
  p_minimum_sell_price_currency_id bigint default null,
  p_show_quantity boolean default null,
  p_display_quantity_override integer default null,
  p_is_active boolean default null,
  p_id bigint default null,
  p_is_price_locked boolean default null,
  p_is_quantity_locked boolean default null,
  p_quantity_override_type text default null,
  p_global_stock_id bigint default null,
  p_product_id bigint default null
)
returns setof public.shop_product_listings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product_id bigint;
  v_target_stock_id bigint;
  v_existing record;
  v_price_locked boolean;
  v_qty_locked boolean;
  v_override_type text;
  v_default_sell_amount numeric;
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id)
     and not public.user_can_manage_shop_tenant(public.resolve_parent_tenant_id(p_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not allowed';
  end if;

  if p_id is not null then
    select * into v_existing from public.shop_product_listings where id = p_id;

    if v_existing.id is null then
      raise exception 'listing not found';
    end if;

    if v_existing.global_stock_id is null then
      v_price_locked := coalesce(p_is_price_locked, v_existing.is_price_locked, false);
      v_qty_locked := coalesce(p_is_quantity_locked, v_existing.is_quantity_locked, false);
      v_override_type := coalesce(p_quantity_override_type, v_existing.quantity_override_type, 'absolute');

      return query
      update public.shop_product_listings
      set
        sell_price_amount = coalesce(p_sell_price_amount, sell_price_amount),
        sell_price_currency_id = coalesce(p_sell_price_currency_id, sell_price_currency_id),
        minimum_sell_price_amount = p_minimum_sell_price_amount,
        minimum_sell_price_currency_id = p_minimum_sell_price_currency_id,
        show_quantity = coalesce(p_show_quantity, show_quantity),
        display_quantity_override = p_display_quantity_override,
        is_active = coalesce(p_is_active, is_active),
        is_price_locked = v_price_locked,
        is_quantity_locked = v_qty_locked,
        quantity_override_type = v_override_type,
        updated_at = now()
      where id = v_existing.id
      returning *;
    end if;
  end if;

  v_target_stock_id := coalesce(p_global_stock_id, p_global_stock_allocation_id);

  if v_target_stock_id is null then
    if p_product_id is null then
      raise exception 'product or stock required';
    end if;

    select p.id,
      coalesce(p.list_price_amount, p.reference_cost_amount, 0)::numeric
    into v_product_id, v_default_sell_amount
    from public.products p
    where p.id = p_product_id;

    if v_product_id is null then
      raise exception 'product not found';
    end if;

    if p_id is not null then
      select * into v_existing from public.shop_product_listings where id = p_id;
    else
      select * into v_existing
      from public.shop_product_listings
      where shop_id = p_shop_id
        and product_id = p_product_id
        and global_stock_id is null;
    end if;

    v_price_locked := coalesce(p_is_price_locked, v_existing.is_price_locked, false);
    v_qty_locked := coalesce(p_is_quantity_locked, v_existing.is_quantity_locked, false);
    v_override_type := coalesce(p_quantity_override_type, v_existing.quantity_override_type, 'absolute');

    if v_existing.id is not null then
      return query
      update public.shop_product_listings
      set
        sell_price_amount = coalesce(p_sell_price_amount, sell_price_amount),
        sell_price_currency_id = coalesce(p_sell_price_currency_id, sell_price_currency_id),
        minimum_sell_price_amount = p_minimum_sell_price_amount,
        minimum_sell_price_currency_id = p_minimum_sell_price_currency_id,
        show_quantity = coalesce(p_show_quantity, show_quantity),
        display_quantity_override = p_display_quantity_override,
        is_active = coalesce(p_is_active, is_active),
        is_price_locked = v_price_locked,
        is_quantity_locked = v_qty_locked,
        quantity_override_type = v_override_type,
        updated_at = now()
      where id = v_existing.id
      returning *;
      return;
    end if;

    return query
    insert into public.shop_product_listings (
      tenant_id,
      shop_id,
      global_stock_allocation_id,
      global_stock_id,
      product_id,
      sell_price_amount,
      sell_price_currency_id,
      minimum_sell_price_amount,
      minimum_sell_price_currency_id,
      show_quantity,
      display_quantity_override,
      is_active,
      is_price_locked,
      is_quantity_locked,
      quantity_override_type
    ) values (
      p_tenant_id,
      p_shop_id,
      null,
      null,
      v_product_id,
      coalesce(p_sell_price_amount, v_default_sell_amount, 0),
      p_sell_price_currency_id,
      p_minimum_sell_price_amount,
      p_minimum_sell_price_currency_id,
      coalesce(p_show_quantity, true),
      p_display_quantity_override,
      coalesce(p_is_active, false),
      v_price_locked,
      v_qty_locked,
      v_override_type
    )
    returning *;
    return;
  end if;

  select gsi.product_id into v_product_id
  from public.global_stocks gs
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  where gs.id = v_target_stock_id;

  if v_product_id is null then
    raise exception 'global stock not found';
  end if;

  if p_id is not null then
    select * into v_existing from public.shop_product_listings where id = p_id;
  else
    select * into v_existing from public.shop_product_listings
    where shop_id = p_shop_id and global_stock_id = v_target_stock_id;
  end if;

  v_price_locked := coalesce(p_is_price_locked, v_existing.is_price_locked, false);
  v_qty_locked := coalesce(p_is_quantity_locked, v_existing.is_quantity_locked, false);
  v_override_type := coalesce(p_quantity_override_type, v_existing.quantity_override_type, 'absolute');

  if v_existing.id is not null then
    return query
    update public.shop_product_listings
    set
      sell_price_amount = p_sell_price_amount,
      sell_price_currency_id = p_sell_price_currency_id,
      minimum_sell_price_amount = p_minimum_sell_price_amount,
      minimum_sell_price_currency_id = p_minimum_sell_price_currency_id,
      show_quantity = coalesce(p_show_quantity, show_quantity),
      display_quantity_override = p_display_quantity_override,
      is_active = coalesce(p_is_active, true),
      is_price_locked = v_price_locked,
      is_quantity_locked = v_qty_locked,
      quantity_override_type = v_override_type,
      global_stock_allocation_id = null,
      updated_at = now()
    where id = v_existing.id
    returning *;
    return;
  end if;

  return query
  insert into public.shop_product_listings (
    tenant_id,
    shop_id,
    global_stock_allocation_id,
    global_stock_id,
    product_id,
    sell_price_amount,
    sell_price_currency_id,
    minimum_sell_price_amount,
    minimum_sell_price_currency_id,
    show_quantity,
    display_quantity_override,
    is_active,
    is_price_locked,
    is_quantity_locked,
    quantity_override_type
  ) values (
    p_tenant_id,
    p_shop_id,
    null,
    v_target_stock_id,
    v_product_id,
    p_sell_price_amount,
    p_sell_price_currency_id,
    p_minimum_sell_price_amount,
    p_minimum_sell_price_currency_id,
    p_show_quantity,
    p_display_quantity_override,
    coalesce(p_is_active, true),
    v_price_locked,
    v_qty_locked,
    v_override_type
  )
  returning *;
end;
$$;

grant execute on function public.upsert_shop_product_listing(
  bigint, bigint, bigint, numeric, bigint, numeric, bigint, boolean, integer, boolean, bigint, boolean, boolean, text, bigint, bigint
) to authenticated;

-- Include product-only (no stock) listings in admin storefront grid.
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
      coalesce(
        gsi.landed_cost_bdt,
        public.calculate_landed_unit_cost(gsi.id),
        p.reference_cost_amount,
        0
      )::numeric as unit_cost_amount,
      case
        when l.global_stock_id is null then coalesce(l.sell_price_amount, p.list_price_amount, 0)
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
      case
        when gs.id is null then 0
        else greatest(0, floor(public.global_stock_atp_qty(gs.id)))::integer
      end as real_available_units,
      tg.slug as grade_slug,
      tg.name as grade_label,
      tg.color as grade_color
    from public.shop_product_listings l
    join public.products p on p.id = l.product_id
    left join public.global_stocks gs on gs.id = l.global_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments gship on gship.id = gsi.shipment_id
    left join public.tags tg on tg.id = gs.grade_tag_id
    where l.shop_id = p_shop_id
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
