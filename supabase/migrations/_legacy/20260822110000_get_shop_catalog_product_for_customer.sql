-- Customer product detail for shop storefront (single product by id).

CREATE OR REPLACE FUNCTION public.get_shop_catalog_product_for_customer(
  p_tenant_id bigint,
  p_shop_slug text,
  p_product_id bigint
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $_$
declare
  v_shop_id bigint;
  v_shop_tenant_id bigint;
  v_parent_tenant_id bigint;
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
  v_product jsonb;
begin
  if p_tenant_id is null then
    raise exception 'tenant required';
  end if;
  if p_product_id is null then
    raise exception 'product required';
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
    v_shop_id, v_shop_tenant_id, v_shop_name, v_shop_type, v_vendor_code, v_order_mode,
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

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_shop_tenant_id);

  if v_shop_type = 'vendor_catalog' then
    select jsonb_build_object(
      'product_id', p.id,
      'product_name', p.name,
      'product_image_url', p.image_url,
      'product_barcode', p.barcode,
      'product_code', p.product_code,
      'product_brand', p.brand,
      'product_category', p.category,
      'vendor_code', p.vendor_code,
      'is_available', p.is_available,
      'country_of_origin', p.country_of_origin,
      'expire_date', p.expire_date,
      'unit_price_amount', case when v_see_price then p.list_price_amount else null end,
      'unit_price_currency_id', case when v_see_price then p.list_price_currency_id else null end,
      'unit_price_currency_code', case when v_see_price then (select code from public.global_currencies where id = p.list_price_currency_id) else null end,
      'unit_price_currency_symbol', case when v_see_price then (select symbol from public.global_currencies where id = p.list_price_currency_id) else null end,
      'minimum_sell_price_amount', null,
      'minimum_sell_price_currency_id', null,
      'minimum_sell_price_currency_code', null,
      'minimum_sell_price_currency_symbol', null,
      'available_units', null,
      'global_stock_allocation_id', null,
      'global_stock_id', null,
      'minimum_order_quantity', p.minimum_order_quantity
    )
    into v_product
    from public.products p
    where p.id = p_product_id
      and p.is_available = true
      and p.parent_tenant_id = v_parent_tenant_id
      and (
        ((v_vendor_filters is null or jsonb_array_length(v_vendor_filters) = 0) and p.vendor_code = v_vendor_code)
        or
        (v_vendor_filters is not null and jsonb_array_length(v_vendor_filters) > 0 and exists (
          select 1
          from jsonb_to_recordset(v_vendor_filters) as vf(vendor_code text, brands text[])
          where vf.vendor_code = p.vendor_code
            and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
        ))
      )
    limit 1;
  else
    select jsonb_build_object(
      'product_id', row.product_id,
      'product_name', row.product_name,
      'product_image_url', row.product_image_url,
      'product_barcode', row.product_barcode,
      'product_code', row.product_code,
      'product_brand', row.product_brand,
      'product_category', row.product_category,
      'vendor_code', row.product_vendor_code,
      'is_available', row.product_is_available,
      'country_of_origin', row.country_of_origin,
      'expire_date', row.expire_date,
      'unit_price_amount', case when v_see_price then row.computed_sell_price else null end,
      'unit_price_currency_id', case when v_see_price then row.sell_price_currency_id else null end,
      'unit_price_currency_code', case when v_see_price then (select code from public.global_currencies where id = row.sell_price_currency_id) else null end,
      'unit_price_currency_symbol', case when v_see_price then (select symbol from public.global_currencies where id = row.sell_price_currency_id) else null end,
      'minimum_sell_price_amount', case when v_see_price and v_shop_type = 'dropship' then row.minimum_sell_price_amount else null end,
      'minimum_sell_price_currency_id', case when v_see_price and v_shop_type = 'dropship' then row.minimum_sell_price_currency_id else null end,
      'minimum_sell_price_currency_code', case when v_see_price and v_shop_type = 'dropship' then (select code from public.global_currencies where id = row.minimum_sell_price_currency_id) else null end,
      'minimum_sell_price_currency_symbol', case when v_see_price and v_shop_type = 'dropship' then (select symbol from public.global_currencies where id = row.minimum_sell_price_currency_id) else null end,
      'available_units', case
        when not v_can_view_quantity or not coalesce(row.listing_show_quantity, v_show_stock_quantity) then null
        when v_quantity_display_mode = 'original' then greatest(0, row.available_qty)
        when row.display_quantity_override is not null then row.display_quantity_override
        else greatest(0, row.available_qty)
      end,
      'global_stock_allocation_id', row.global_stock_id,
      'global_stock_id', row.global_stock_id,
      'minimum_order_quantity', row.product_moq
    )
    into v_product
    from (
      select
        l.id as listing_id,
        l.global_stock_id,
        case
          when v_shop_type = 'fixed_price' and v_pricing_method = 'markup' then
            coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) * (1 + v_markup_percentage / 100.0)
          when v_shop_type = 'fixed_price' and v_pricing_method = 'direct_cost' then
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
        p.country_of_origin,
        p.expire_date,
        p.minimum_order_quantity as product_moq,
        greatest(0, floor(public.global_stock_atp_qty(gs.id)))::integer as available_qty
      from public.shop_product_listings l
      join public.products p on p.id = l.product_id
      join public.global_stocks gs on gs.id = l.global_stock_id
      left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      left join public.global_shipments gship on gship.id = gsi.shipment_id
        and gship.assigned_child_tenant_id = v_shop_tenant_id
      where l.shop_id = v_shop_id
        and l.product_id = p_product_id
        and l.global_stock_id is not null
        and coalesce(gship.status, 'received') = 'received'
        and l.is_active = true
      order by l.id asc
      limit 1
    ) row;
  end if;

  if v_product is null then
    raise exception 'product not found';
  end if;

  return jsonb_build_object(
    'data', v_product,
    'meta', jsonb_build_object(
      'shop', jsonb_build_object(
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
      ),
      'permissions', jsonb_build_object(
        'can_browse', v_can_browse,
        'see_price', v_see_price,
        'can_add_to_cart', v_can_add_to_cart,
        'can_place_order', v_can_place_order,
        'can_negotiate', v_can_negotiate,
        'can_view_quantity', v_can_view_quantity,
        'can_set_dropship_price', v_can_set_dropship_price
      )
    )
  );
end;
$_$;

REVOKE ALL ON FUNCTION public.get_shop_catalog_product_for_customer(bigint, text, bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.get_shop_catalog_product_for_customer(bigint, text, bigint) TO authenticated;
